import AppKit

enum AirDropAction {
    /// Opens the system AirDrop picker for the given files or links.
    /// Returns false when AirDrop can't handle them (for example, it is off).
    @MainActor
    static func send(_ items: [URL]) -> Bool {
        guard let service = NSSharingService(named: .sendViaAirDrop),
              service.canPerform(withItems: items)
        else { return false }

        // The picker needs Raf in front, otherwise it can open behind other apps.
        NSApp.activate(ignoringOtherApps: true)
        service.perform(withItems: items)
        return true
    }
}
