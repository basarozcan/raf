import AppKit
import SwiftUI

/// Raf has no app menu, so it opens its Settings window itself instead of
/// relying on SwiftUI's Settings scene.
@MainActor
final class SettingsWindowController {
    static let shared = SettingsWindowController()

    private var window: NSWindow?

    private init() {}

    func show() {
        if window == nil {
            let controller = NSHostingController(
                rootView: SettingsView().environmentObject(AppSettings.shared)
            )
            let window = NSWindow(contentViewController: controller)
            window.title = "Raf Settings"
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            window.center()
            self.window = window
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}
