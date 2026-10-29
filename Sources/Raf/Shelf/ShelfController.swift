import AppKit
import Combine
import SwiftUI

/// Owns the shelf panel: where it sits, when it opens, and when it closes.
///
/// It behaves like Dropzone's grid: it drops down under the menu bar icon,
/// closes when you click elsewhere, and closes by itself after a drag that
/// opened it is finished (unless it is pinned or showing an error).
@MainActor
final class ShelfController {
    static let shared = ShelfController()

    /// Screen frame of the menu bar icon; set by the app delegate.
    var anchorProvider: @MainActor () -> NSRect? = { nil }

    private let hostingController: NSHostingController<AnyView>
    private lazy var panel = ShelfPanel(contentView: ShelfDropView(hostingView: hostingController.view))

    private var openedByDrag = false
    private var externalDragActive = false
    private var hiddenByClickAt: Date?
    private var hideWorkItem: DispatchWorkItem?
    private var outsideClickMonitor: Any?
    private var cancellables = Set<AnyCancellable>()

    var isVisible: Bool { panel.isVisible }

    private init() {
        hostingController = NSHostingController(
            rootView: AnyView(
                ShelfView()
                    .environmentObject(ShelfStore.shared)
                    .environmentObject(AppSettings.shared)
            )
        )
        hostingController.sizingOptions = []

        // Resize the panel whenever its content changes size.
        let store = ShelfStore.shared
        Publishers.Merge4(
            store.$items.map { _ in () },
            store.$status.map { _ in () },
            store.$isPinned.map { _ in () },
            AppSettings.shared.$folders.map { _ in () }
        )
        .sink { [weak self] _ in
            // @Published fires before the value changes; resize on the next turn.
            Task { @MainActor in self?.resizeToFit() }
        }
        .store(in: &cancellables)
    }

    // MARK: Showing and hiding

    func toggle() {
        isVisible ? hide() : show()
    }

    func show(openedByDrag: Bool = false) {
        cancelAutoHide()
        if isVisible {
            // A click-opened shelf stays put even if a drag passes through it.
            if !openedByDrag { self.openedByDrag = false }
            return
        }
        self.openedByDrag = openedByDrag
        resizeToFit()
        position()
        panel.orderFrontRegardless()
        installOutsideClickMonitor()
    }

    func hide() {
        cancelAutoHide()
        removeOutsideClickMonitor()
        ShelfStore.shared.hoveredTarget = nil
        panel.orderOut(nil)
    }

    // MARK: Drag events

    /// A file or link drag started anywhere on screen.
    func dragDidStart() {
        externalDragActive = true
        // Reopen if a click outside just closed the shelf (that click was the
        // start of this drag), or always if the user enabled it in Settings.
        let justClosed = hiddenByClickAt.map { Date().timeIntervalSince($0) < 1.5 } ?? false
        if AppSettings.shared.showOnDrag || justClosed {
            show(openedByDrag: true)
        }
    }

    /// The drag ended, whether it was dropped somewhere or cancelled.
    func dragDidEnd() {
        externalDragActive = false
        if openedByDrag {
            scheduleAutoHide()
        }
    }

    func dragEnteredShelf() {
        cancelAutoHide()
    }

    /// Called when an action finishes, so a drag-opened shelf can close.
    func actionDidFinish() {
        if openedByDrag && !externalDragActive {
            scheduleAutoHide()
        }
    }

    private func scheduleAutoHide() {
        cancelAutoHide()
        let item = DispatchWorkItem { [weak self] in
            Task { @MainActor in self?.autoHideIfIdle() }
        }
        hideWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2, execute: item)
    }

    private func autoHideIfIdle() {
        let store = ShelfStore.shared
        guard isVisible, !store.isPinned, !externalDragActive else { return }
        if store.isBusy {
            scheduleAutoHide()
            return
        }
        // Leave errors on screen until the user clicks away.
        guard store.status?.isError != true else { return }
        hide()
    }

    private func cancelAutoHide() {
        hideWorkItem?.cancel()
        hideWorkItem = nil
    }

    private func installOutsideClickMonitor() {
        guard outsideClickMonitor == nil else { return }
        // Global monitors only see clicks in other apps, so clicks on the
        // shelf itself and on the menu bar icon never close it here.
        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.isVisible, !ShelfStore.shared.isPinned else { return }
                self.hiddenByClickAt = Date()
                self.hide()
            }
        }
    }

    private func removeOutsideClickMonitor() {
        if let outsideClickMonitor {
            NSEvent.removeMonitor(outsideClickMonitor)
        }
        outsideClickMonitor = nil
    }

    // MARK: Layout

    /// Sizes the panel to its SwiftUI content, keeping its top edge in place.
    private func resizeToFit() {
        let size = hostingController.sizeThatFits(in: CGSize(width: 300, height: 10_000))
        guard size.width > 0, size.height > 0 else { return }

        var frame = panel.frame
        let top = frame.maxY
        frame.size = size
        if panel.isVisible {
            frame.origin.y = top - size.height
        }
        panel.setFrame(frame, display: true)
    }

    /// Drops the shelf down under the menu bar icon, kept on screen.
    private func position() {
        let size = panel.frame.size
        var origin: NSPoint
        var screen: NSScreen?

        if let anchor = anchorProvider() {
            screen = NSScreen.screens.first { $0.frame.intersects(anchor) }
            origin = NSPoint(x: anchor.midX - size.width / 2, y: anchor.minY - size.height - 6)
        } else {
            screen = NSScreen.main
            let visible = screen?.visibleFrame ?? .zero
            origin = NSPoint(x: visible.maxX - size.width - 16, y: visible.maxY - size.height - 8)
        }

        if let visible = (screen ?? NSScreen.main)?.visibleFrame {
            origin.x = min(max(origin.x, visible.minX + 8), visible.maxX - size.width - 8)
            origin.y = max(origin.y, visible.minY + 8)
        }
        panel.setFrameOrigin(origin)
    }
}
