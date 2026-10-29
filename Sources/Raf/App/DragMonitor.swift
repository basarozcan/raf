import AppKit

/// Detects when the user starts dragging a file or link anywhere on screen.
///
/// macOS has no public "a drag started" notification, so we watch global
/// mouse-drag events and check whether the system drag pasteboard changed.
/// A new drag session always writes to that pasteboard, which bumps its
/// change count. The end of the drag is detected by polling the mouse button,
/// because the drag session swallows the final mouse-up event.
@MainActor
final class DragMonitor {
    private let onDragStart: @MainActor () -> Void
    private let onDragEnd: @MainActor () -> Void

    private var eventMonitor: Any?
    private var endTimer: Timer?
    private var lastChangeCount = NSPasteboard(name: .drag).changeCount
    private var isDragging = false

    init(onDragStart: @escaping @MainActor () -> Void, onDragEnd: @escaping @MainActor () -> Void) {
        self.onDragStart = onDragStart
        self.onDragEnd = onDragEnd
    }

    func start() {
        guard eventMonitor == nil else { return }
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDragged) { [weak self] _ in
            Task { @MainActor in self?.handleMouseDragged() }
        }
    }

    func stop() {
        if let eventMonitor {
            NSEvent.removeMonitor(eventMonitor)
        }
        eventMonitor = nil
        endTimer?.invalidate()
        endTimer = nil
    }

    private func handleMouseDragged() {
        guard !isDragging else { return }

        let pasteboard = NSPasteboard(name: .drag)
        guard pasteboard.changeCount != lastChangeCount else { return }
        lastChangeCount = pasteboard.changeCount

        let types = pasteboard.types ?? []
        guard types.contains(.fileURL) || types.contains(.URL) else { return }

        isDragging = true
        onDragStart()

        endTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.checkDragEnded() }
        }
    }

    private func checkDragEnded() {
        guard isDragging, NSEvent.pressedMouseButtons & 1 == 0 else { return }
        endTimer?.invalidate()
        endTimer = nil
        isDragging = false
        onDragEnd()
    }
}
