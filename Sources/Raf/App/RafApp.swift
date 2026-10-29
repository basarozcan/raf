import SwiftUI

@main
struct RafApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra("Raf", systemImage: "tray.and.arrow.down") {
            MenuContent()
        }

        Settings {
            SettingsView()
                .environmentObject(AppSettings.shared)
        }
    }
}

private struct MenuContent: View {
    var body: some View {
        Button("Show Shelf") {
            ShelfController.shared.toggle()
        }
        .keyboardShortcut("s")

        Divider()

        if #available(macOS 14, *) {
            SettingsLink {
                Text("Settings…")
            }
            .keyboardShortcut(",")
        } else {
            Button("Settings…") {
                NSApp.activate(ignoringOtherApps: true)
                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
            }
            .keyboardShortcut(",")
        }

        Divider()

        Button("Quit Raf") {
            NSApp.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}
