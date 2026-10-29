import AppKit
import SwiftUI

/// Owns the floating shelf panel and decides when it shows and hides.
@MainActor
final class ShelfController {
    static let shared = ShelfController()

    private lazy var panel = ShelfPanel(
        rootView: ShelfView()
            .environmentObject(ShelfStore.shared)
            .environmentObject(AppSettings.shared)
    )
    private var hideWorkItem: DispatchWorkItem?

    private init() {}

    func dragDidStart() {
        guard AppSettings.shared.showOnDrag else { return }
        show()
    }

    func dragDidEnd() {
        scheduleAutoHide()
    }

    func toggle() {
        panel.isVisible ? hide() : show()
    }

    func show() {
        hideWorkItem?.cancel()
        hideWorkItem = nil
        guard !panel.isVisible else { return }
        position()
        panel.orderFrontRegardless()
    }

    func hide() {
        hideWorkItem?.cancel()
        hideWorkItem = nil
        panel.orderOut(nil)
    }

    /// Hides the shelf after a drag ends, unless it is holding something,
    /// still working on a drop, or the pointer is over it.
    private func scheduleAutoHide() {
        hideWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                let store = ShelfStore.shared
                let pointerInside = self.panel.frame.contains(NSEvent.mouseLocation)
                guard store.items.isEmpty, !store.isBusy, !pointerInside else { return }
                self.hide()
            }
        }
        hideWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: item)
    }

    /// Places the shelf at the right edge of the screen the pointer is on,
    /// so it never covers the spot the user is dragging from.
    private func position() {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(mouse) } ?? NSScreen.main
        guard let visible = screen?.visibleFrame else { return }

        let size = panel.frame.size
        let origin = NSPoint(
            x: visible.maxX - size.width - 16,
            y: visible.midY - size.height / 2
        )
        panel.setFrameOrigin(origin)
    }
}
