import AppKit
import SwiftUI

/// Makes the SwiftUI view it overlays draggable out of the shelf as real
/// files, so Finder (or any app) can copy or move them. Also handles
/// double-click to open and the right-click menu.
struct DragSource: NSViewRepresentable {
    let urls: [URL]

    func makeNSView(context: Context) -> DragSourceView {
        DragSourceView()
    }

    func updateNSView(_ view: DragSourceView, context: Context) {
        view.urls = urls
    }
}

final class DragSourceView: NSView, NSDraggingSource {
    var urls: [URL] = []
    private var mouseDownEvent: NSEvent?

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override var mouseDownCanMoveWindow: Bool { false }

    override func mouseDown(with event: NSEvent) {
        mouseDownEvent = event
        if event.clickCount == 2 {
            urls.forEach { NSWorkspace.shared.open($0) }
        }
    }

    override func mouseUp(with event: NSEvent) {
        mouseDownEvent = nil
    }

    override func mouseDragged(with event: NSEvent) {
        guard let downEvent = mouseDownEvent, !urls.isEmpty else { return }
        mouseDownEvent = nil

        let start = convert(downEvent.locationInWindow, from: nil)
        let items = urls.enumerated().map { index, url -> NSDraggingItem in
            let item = NSDraggingItem(pasteboardWriter: url as NSURL)
            let offset = CGFloat(min(index, 4)) * 4
            item.setDraggingFrame(
                NSRect(x: start.x - 16 + offset, y: start.y - 16 - offset, width: 32, height: 32),
                contents: Self.icon(for: url)
            )
            return item
        }
        beginDraggingSession(with: items, event: downEvent, source: self)
    }

    override func menu(for event: NSEvent) -> NSMenu? {
        guard !urls.isEmpty else { return nil }
        let menu = NSMenu()
        menu.addItem(withTitle: "Open", action: #selector(openItems), keyEquivalent: "").target = self
        if urls.contains(where: \.isFileURL) {
            menu.addItem(withTitle: "Show in Finder", action: #selector(revealItems), keyEquivalent: "").target = self
        }
        menu.addItem(.separator())
        menu.addItem(withTitle: "Remove from Drop Bar", action: #selector(removeItems), keyEquivalent: "").target = self
        return menu
    }

    // MARK: NSDraggingSource

    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        // Outside Raf, let the destination decide: Finder moves on the same
        // disk and copies across disks, just like dragging from a Finder window.
        context == .outsideApplication ? [.copy, .move, .generic, .link] : [.copy, .generic]
    }

    func draggingSession(_ session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation) {
        guard operation != [] else { return }
        ShelfStore.shared.dragOutEnded(urls)
    }

    // MARK: Menu actions

    @objc private func openItems() {
        urls.forEach { NSWorkspace.shared.open($0) }
    }

    @objc private func revealItems() {
        NSWorkspace.shared.activateFileViewerSelecting(urls.filter(\.isFileURL))
    }

    @objc private func removeItems() {
        ShelfStore.shared.remove(urls: urls)
    }

    private static func icon(for url: URL) -> NSImage {
        if url.isFileURL {
            return NSWorkspace.shared.icon(forFile: url.path)
        }
        return NSImage(systemSymbolName: "link", accessibilityDescription: nil) ?? NSImage()
    }
}
