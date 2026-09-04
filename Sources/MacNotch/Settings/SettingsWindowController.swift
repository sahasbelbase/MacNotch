import AppKit
import SwiftUI

/// Centralized controller to manage and present the MacNotch Settings window.
@MainActor
public final class SettingsWindowController: NSObject, NSWindowDelegate {
    public static let shared = SettingsWindowController()

    private var windowController: NSWindowController?
    private var currentScreenManager: ScreenManager?
    private var currentClipboardManager: ClipboardManager?

    private override init() {
        super.init()
    }

    /// Configures core dependencies needed by the settings view.
    public func configure(screenManager: ScreenManager, clipboardManager: ClipboardManager) {
        self.currentScreenManager = screenManager
        self.currentClipboardManager = clipboardManager
    }

    /// Presents the settings window, creating it if needed and activating the application.
    public func showSettings(screenManager: ScreenManager? = nil, clipboardManager: ClipboardManager? = nil) {
        if let sm = screenManager { self.currentScreenManager = sm }
        if let cm = clipboardManager { self.currentClipboardManager = cm }

        if let controller = windowController, let window = controller.window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let sm = currentScreenManager ?? ScreenManager()
        let cm = currentClipboardManager ?? ClipboardManager()

        let settingsView = SettingsView(
            screenManager: sm,
            clipboardManager: cm
        )

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 420),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.title = "MacNotch Settings"
        window.contentView = NSHostingView(rootView: settingsView)
        window.isReleasedWhenClosed = false
        window.delegate = self

        let controller = NSWindowController(window: window)
        self.windowController = controller
        controller.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    public func windowWillClose(_ notification: Notification) {
        // Keep controller reference ready for next display
    }
}
