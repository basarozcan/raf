import AppKit
import SwiftUI

/// A borderless floating panel that stays above other windows, appears on
/// every Space (including full-screen apps), and never steals focus.
final class ShelfPanel: NSPanel {
    init(contentView: NSView) {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 400),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isFloatingPanel = true
        level = .popUpMenu
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        hidesOnDeactivate = false
        isMovableByWindowBackground = false
        backgroundColor = .clear
        isOpaque = false
        hasShadow = true
        self.contentView = contentView
    }

    // Lets buttons inside the shelf respond to the first click.
    override var canBecomeKey: Bool { true }
}

/// The shelf's content view. It is the single drop destination for the whole
/// panel: SwiftUI reports where each target sits (see `dropTarget(_:)`) and
/// this view works out which one is under the pointer.
final class ShelfDropView: NSView {
    private let hostingView: NSView
    private var cachedSequence: Int?
    private var cachedContent = DroppedContent.Result()

    init(hostingView: NSView) {
        self.hostingView = hostingView
        super.init(frame: .zero)
        addSubview(hostingView)
        registerForDraggedTypes(DroppedContent.pasteboardTypes)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    // Keep the SwiftUI content filling this view whenever the panel resizes.
    override func resizeSubviews(withOldSize oldSize: NSSize) {
        hostingView.frame = bounds
    }

    override func layout() {
        super.layout()
        hostingView.frame = bounds
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        ShelfController.shared.dragEnteredShelf()
        return update(sender)
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        update(sender)
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        ShelfStore.shared.hoveredTarget = nil
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let store = ShelfStore.shared
        defer { store.hoveredTarget = nil }

        guard let target = target(at: sender) else { return false }
        let content = content(of: sender)
        guard store.accepts(content, on: target, fromShelf: sender.draggingSource is DragSourceView) else {
            return false
        }
        store.handleDrop(content, on: target)
        return true
    }

    private func update(_ sender: NSDraggingInfo) -> NSDragOperation {
        let store = ShelfStore.shared
        guard let target = target(at: sender),
              store.accepts(content(of: sender), on: target, fromShelf: sender.draggingSource is DragSourceView)
        else {
            store.hoveredTarget = nil
            return []
        }
        if store.hoveredTarget != target {
            store.hoveredTarget = target
        }
        return DroppedContent.operation(for: sender)
    }

    /// Reads the pasteboard once per drag instead of on every mouse move.
    private func content(of sender: NSDraggingInfo) -> DroppedContent.Result {
        if cachedSequence != sender.draggingSequenceNumber {
            cachedSequence = sender.draggingSequenceNumber
            cachedContent = DroppedContent.read(from: sender.draggingPasteboard)
        }
        return cachedContent
    }

    private func target(at sender: NSDraggingInfo) -> DropTargetID? {
        var point = hostingView.convert(sender.draggingLocation, from: nil)
        if !hostingView.isFlipped {
            point.y = hostingView.bounds.height - point.y
        }
        return ShelfStore.shared.targetFrames.first { $0.value.contains(point) }?.key
    }
}
