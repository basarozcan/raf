import AppKit
import Combine

/// The menu bar icon. Click opens the shelf under it, right-click (or
/// control-click) shows the menu, and dragging something onto the icon
/// opens the shelf so you can carry on to a drop target, like Dropzone.
@MainActor
final class StatusItemController: NSObject {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private var cancellables = Set<AnyCancellable>()

    override init() {
        super.init()
        guard let button = statusItem.button else { return }

        let image = NSImage(systemSymbolName: "tray.and.arrow.down.fill", accessibilityDescription: "Raf")
        image?.isTemplate = true
        button.image = image
        button.imagePosition = .imageLeading
        button.font = .monospacedDigitSystemFont(ofSize: NSFont.smallSystemFontSize, weight: .medium)
        button.target = self
        button.action = #selector(handleClick(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])

        // NSWindow forwards drag-and-drop calls to its delegate, which is how
        // a status item becomes a drop target.
        button.window?.registerForDraggedTypes(DroppedContent.pasteboardTypes)
        button.window?.delegate = self

        ShelfStore.shared.$items
            .map(\.count)
            .removeDuplicates()
            .sink { [weak self] count in self?.updateBadge(count) }
            .store(in: &cancellables)
    }

    /// The icon's frame in screen coordinates, used to place the shelf under it.
    var screenFrame: NSRect? {
        guard let button = statusItem.button, let window = button.window else { return nil }
        return window.convertToScreen(button.convert(button.bounds, to: nil))
    }

    @objc private func handleClick(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent
        if event?.type == .rightMouseUp || event?.modifierFlags.contains(.control) == true {
            showMenu()
        } else {
            ShelfController.shared.toggle()
        }
    }

    private func showMenu() {
        guard let button = statusItem.button else { return }
        ShelfController.shared.hide()

        let menu = NSMenu()
        menu.addItem(withTitle: "Show Shelf", action: #selector(showShelf), keyEquivalent: "").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Settings…", action: #selector(openSettings), keyEquivalent: ",").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Raf", action: #selector(quit), keyEquivalent: "q").target = self
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height + 5), in: button)
    }

    private func updateBadge(_ count: Int) {
        statusItem.button?.title = count > 0 ? "\(count)" : ""
    }

    @objc private func showShelf() { ShelfController.shared.show() }
    @objc private func openSettings() { SettingsWindowController.shared.show() }
    @objc private func quit() { NSApp.terminate(nil) }
}

// MARK: Dropping onto the menu bar icon

extension StatusItemController: NSWindowDelegate {
    @objc func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        let content = DroppedContent.read(from: sender.draggingPasteboard)
        guard !content.isEmpty else { return [] }
        ShelfController.shared.show(openedByDrag: true)
        return DroppedContent.operation(for: sender)
    }

    @objc func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        DroppedContent.read(from: sender.draggingPasteboard).isEmpty ? [] : DroppedContent.operation(for: sender)
    }

    /// Dropping right on the icon puts things on the Drop Bar.
    @objc func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let content = DroppedContent.read(from: sender.draggingPasteboard)
        guard !content.isEmpty else { return false }
        ShelfStore.shared.add(content.all)
        return true
    }
}
