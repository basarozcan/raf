import AppKit

enum FolderPicker {
    /// Asks the user to choose one or more folders to use as drop targets.
    @MainActor
    static func chooseFolders() -> [URL] {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = true
        panel.prompt = "Add"
        panel.message = "Choose folders to show on the Raf shelf"
        // Raf is a menu bar app, so bring it forward or the panel opens behind.
        NSApp.activate(ignoringOtherApps: true)
        return panel.runModal() == .OK ? panel.urls : []
    }
}
