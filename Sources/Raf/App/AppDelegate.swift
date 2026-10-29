import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: StatusItemController?
    private var dragMonitor: DragMonitor?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Menu bar only: no Dock icon, no app menu.
        NSApp.setActivationPolicy(.accessory)
        Notifier.requestAuthorization()

        let statusItem = StatusItemController()
        ShelfController.shared.anchorProvider = { [weak statusItem] in statusItem?.screenFrame }
        self.statusItem = statusItem

        let monitor = DragMonitor(
            onDragStart: { ShelfController.shared.dragDidStart() },
            onDragEnd: { ShelfController.shared.dragDidEnd() }
        )
        monitor.start()
        dragMonitor = monitor
    }

    func applicationWillTerminate(_ notification: Notification) {
        dragMonitor?.stop()
    }
}
