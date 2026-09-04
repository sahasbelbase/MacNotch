import SwiftUI

@main
public struct MacNotchApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    public init() {}

    public var body: some Scene {
        Settings {
            SettingsView(
                screenManager: appDelegate.screenManager ?? ScreenManager(),
                clipboardManager: appDelegate.clipboardManager ?? ClipboardManager()
            )
        }
    }
}
