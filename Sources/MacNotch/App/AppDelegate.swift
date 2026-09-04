import AppKit
import SwiftUI

/// Main application delegate coordinating lifecycle, managers, and system events.
@MainActor
public final class AppDelegate: NSObject, NSApplicationDelegate {
    public private(set) var appState: AppState!
    public private(set) var screenManager: ScreenManager!
    public private(set) var windowManager: WindowManager!
    public private(set) var mouseTracker: MouseTracker!
    public private(set) var clipboardManager: ClipboardManager!
    public private(set) var timeService: TimeService!
    public private(set) var weatherService: WeatherService!
    public private(set) var nowPlayingService: SystemNowPlayingService!
    public private(set) var menuBarManager: MenuBarManager!

    private var sleepObserver: NSObjectProtocol?
    private var wakeObserver: NSObjectProtocol?

    public func applicationDidFinishLaunching(_ notification: Notification) {
        // Run as accessory app (no dock icon, menu bar + floating panel)
        NSApp.setActivationPolicy(.accessory)

        // Initialize core dependencies
        self.appState = AppState()
        self.screenManager = ScreenManager()
        self.clipboardManager = ClipboardManager()
        self.timeService = TimeService()
        self.weatherService = WeatherService()
        self.nowPlayingService = SystemNowPlayingService()

        // Sync settings with AppState
        let settings = SettingsStore.shared
        self.appState.isEnabled = settings.enableNotch
        self.appState.hoverActivationDelay = settings.hoverDelay
        self.appState.collapseDelay = settings.collapseDelay
        if let tab = NotchTab(rawValue: settings.defaultTab) {
            self.appState.selectedTab = tab
        }
        self.clipboardManager.filterSensitiveData = settings.filterSensitive
        if let policy = ClipboardDuplicatePolicy(rawValue: settings.duplicatePolicy) {
            self.clipboardManager.duplicatePolicy = policy
        }
        self.clipboardManager.retentionLimit = RetentionLimit(rawValue: settings.clipboardRetention) ?? .eighty

        // Ensure Launch at Login is synchronized with system Login Items
        if settings.launchAtLogin {
            settings.setLaunchAtLogin(true)
        }

        // Apply saved theme
        if settings.appAppearance == "Dark" {
            NSApp.appearance = NSAppearance(named: .darkAqua)
        } else if settings.appAppearance == "Light" {
            NSApp.appearance = NSAppearance(named: .aqua)
        }

        // Initialize window and mouse tracking
        self.windowManager = WindowManager(appState: appState, screenManager: screenManager)
        self.mouseTracker = MouseTracker(appState: appState, screenManager: screenManager)

        // Configure shared Settings controller
        SettingsWindowController.shared.configure(
            screenManager: screenManager,
            clipboardManager: clipboardManager
        )

        // Embed root SwiftUI view into the floating panel
        let rootView = NotchView(
            appState: appState,
            screenManager: screenManager,
            clipboardManager: clipboardManager,
            timeService: timeService,
            weatherService: weatherService,
            nowPlayingService: nowPlayingService
        )
        self.windowManager.setContent(rootView)

        // Setup menu bar companion
        self.menuBarManager = MenuBarManager(appState: appState, clipboardManager: clipboardManager)

        setupPowerObservers()
    }

    private func setupPowerObservers() {
        // Sleep notification
        sleepObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.willSleepNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.appState.transition(to: .hidden)
                self?.mouseTracker.stopTracking()
            }
        }

        // Wake notification
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.screenManager.recalculateDisplayGeometry()
                self?.mouseTracker.setupTracking()
                if self?.appState.isEnabled == true {
                    self?.appState.transition(to: .collapsed)
                }
            }
        }
    }

    public func applicationWillTerminate(_ notification: Notification) {
        if let s = sleepObserver { NSWorkspace.shared.notificationCenter.removeObserver(s) }
        if let w = wakeObserver { NSWorkspace.shared.notificationCenter.removeObserver(w) }
    }
}
