import SwiftUI

@main
struct RafApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // The menu bar icon and shelf are plain AppKit (see StatusItemController),
        // and Settings has its own window. SwiftUI still needs one scene.
        Settings {
            EmptyView()
        }
    }
}
