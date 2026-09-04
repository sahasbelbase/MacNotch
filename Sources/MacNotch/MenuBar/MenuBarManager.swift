import AppKit
import SwiftUI

/// Manages the macOS menu bar status item and context menu.
@MainActor
public final class MenuBarManager: NSObject {
    private var statusItem: NSStatusItem?
    private let appState: AppState
    private let clipboardManager: ClipboardManager
    private let settingsStore: SettingsStore = .shared
    private var settingsWindowController: NSWindowController?

    public init(appState: AppState, clipboardManager: ClipboardManager) {
        self.appState = appState
        self.clipboardManager = clipboardManager
        super.init()
        setupStatusItem()
    }

    public func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "inset.filled.topthird.rectangle", accessibilityDescription: "MacNotch")
            button.toolTip = "MacNotch"
        }
        rebuildMenu()
    }

    public func rebuildMenu() {
        let menu = NSMenu(title: "MacNotch")

        // Title item
        let titleItem = NSMenuItem(title: "MacNotch", action: nil, keyEquivalent: "")
        titleItem.attributedTitle = NSAttributedString(
            string: "MacNotch",
            attributes: [.font: NSFont.boldSystemFont(ofSize: 13)]
        )
        menu.addItem(titleItem)

        // Enable toggle
        let enableItem = NSMenuItem(
            title: "Enable MacNotch",
            action: #selector(toggleEnable),
            keyEquivalent: ""
        )
        enableItem.target = self
        enableItem.state = appState.isEnabled ? .on : .off
        menu.addItem(enableItem)

        menu.addItem(NSMenuItem.separator())

        // Clipboard submenu
        let clipboardMenu = NSMenu(title: "Clipboard")
        let openClipItem = NSMenuItem(title: "Open Clipboard", action: #selector(openClipboard), keyEquivalent: "c")
        openClipItem.keyEquivalentModifierMask = [.command, .shift]
        openClipItem.target = self
        clipboardMenu.addItem(openClipItem)

        let pauseClipItem = NSMenuItem(title: "Pause History", action: #selector(togglePauseClipboard), keyEquivalent: "")
        pauseClipItem.target = self
        pauseClipItem.state = clipboardManager.isPaused ? .on : .off
        clipboardMenu.addItem(pauseClipItem)

        let clearClipItem = NSMenuItem(title: "Clear History", action: #selector(clearClipboard), keyEquivalent: "")
        clearClipItem.target = self
        clipboardMenu.addItem(clearClipItem)

        let clipboardParentItem = NSMenuItem(title: "Clipboard", action: nil, keyEquivalent: "")
        clipboardParentItem.submenu = clipboardMenu
        menu.addItem(clipboardParentItem)

        // Appearance submenu
        let appearanceMenu = NSMenu(title: "Appearance")
        let autoAppItem = NSMenuItem(title: "Automatic", action: #selector(setAppearanceAuto), keyEquivalent: "")
        autoAppItem.target = self
        autoAppItem.state = (settingsStore.appAppearance == "System") ? .on : .off
        appearanceMenu.addItem(autoAppItem)

        let lightAppItem = NSMenuItem(title: "Light", action: #selector(setAppearanceLight), keyEquivalent: "")
        lightAppItem.target = self
        lightAppItem.state = (settingsStore.appAppearance == "Light") ? .on : .off
        appearanceMenu.addItem(lightAppItem)

        let darkAppItem = NSMenuItem(title: "Dark", action: #selector(setAppearanceDark), keyEquivalent: "")
        darkAppItem.target = self
        darkAppItem.state = (settingsStore.appAppearance == "Dark") ? .on : .off
        appearanceMenu.addItem(darkAppItem)

        let appearanceParentItem = NSMenuItem(title: "Appearance", action: nil, keyEquivalent: "")
        appearanceParentItem.submenu = appearanceMenu
        menu.addItem(appearanceParentItem)

        menu.addItem(NSMenuItem.separator())

        // Settings...
        let settingsItem = NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        // Launch at login
        let loginItem = NSMenuItem(title: "Launch at Login", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        loginItem.target = self
        loginItem.state = settingsStore.launchAtLogin ? .on : .off
        menu.addItem(loginItem)

        // About
        let aboutItem = NSMenuItem(title: "About MacNotch", action: #selector(openAbout), keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)

        menu.addItem(NSMenuItem.separator())

        // Quit
        let quitItem = NSMenuItem(title: "Quit MacNotch", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem?.menu = menu
    }

    // MARK: - Actions

    @objc private func toggleEnable() {
        appState.isEnabled.toggle()
        settingsStore.enableNotch = appState.isEnabled
        rebuildMenu()
    }

    @objc private func openClipboard() {
        appState.selectedTab = .clipboard
        appState.transition(to: .expanded)
    }

    @objc private func togglePauseClipboard() {
        clipboardManager.isPaused.toggle()
        rebuildMenu()
    }

    @objc private func clearClipboard() {
        clipboardManager.clearHistory()
    }

    @objc private func setAppearanceAuto() {
        settingsStore.appAppearance = "System"
        NSApp.appearance = nil
        rebuildMenu()
    }

    @objc private func setAppearanceLight() {
        settingsStore.appAppearance = "Light"
        NSApp.appearance = NSAppearance(named: .aqua)
        rebuildMenu()
    }

    @objc private func setAppearanceDark() {
        settingsStore.appAppearance = "Dark"
        NSApp.appearance = NSAppearance(named: .darkAqua)
        rebuildMenu()
    }

    @objc public func openSettings() {
        SettingsWindowController.shared.showSettings(clipboardManager: clipboardManager)
    }

    @objc private func toggleLaunchAtLogin() {
        settingsStore.setLaunchAtLogin(!settingsStore.launchAtLogin)
        rebuildMenu()
    }

    @objc private func openAbout() {
        NSApp.orderFrontStandardAboutPanel(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}
