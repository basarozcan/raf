import AppKit
import SwiftUI

/// A borderless floating panel that stays above other windows, appears on
/// every Space (including full-screen apps), and never steals focus.
final class ShelfPanel: NSPanel {
    init<Content: View>(rootView: Content) {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 280, height: 440),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isFloatingPanel = true
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        hidesOnDeactivate = false
        isMovableByWindowBackground = true
        backgroundColor = .clear
        isOpaque = false
        hasShadow = true
        contentView = NSHostingView(rootView: rootView)
    }

    // Lets text fields and buttons inside the shelf respond to clicks.
    override var canBecomeKey: Bool { true }
}
