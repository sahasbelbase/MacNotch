import AppKit
import Combine
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
    public private(set) var batteryService: BatteryService!
    public private(set) var systemHUDService: SystemHUDService!
    public private(set) var fileShelfManager: FileShelfManager!
    public private(set) var jotterManager: JotterManager!
    public private(set) var timerService: TimerService!
    public private(set) var calendarSyncService: CalendarSyncService!
    public private(set) var bluetoothAccessoryService: BluetoothAccessoryService!
    public private(set) var menuBarManager: MenuBarManager!

    private var sleepObserver: NSObjectProtocol?
    private var wakeObserver: NSObjectProtocol?
    private var cancellables = Set<AnyCancellable>()

    public func applicationDidFinishLaunching(_ notification: Notification) {
        // Run as accessory app (no dock icon, menu bar + floating panel)
        NSApp.setActivationPolicy(.accessory)

        // Initialize core dependencies
        self.appState = AppState()
        self.screenManager = ScreenManager()
        self.clipboardManager = ClipboardManager()
        self.timeService = TimeService()
        self.weatherService = WeatherService.shared
        self.nowPlayingService = SystemNowPlayingService()
        self.batteryService = BatteryService()
        self.systemHUDService = SystemHUDService()
        self.fileShelfManager = FileShelfManager()
        self.jotterManager = JotterManager()
        self.timerService = TimerService()
        self.calendarSyncService = CalendarSyncService()
        self.bluetoothAccessoryService = BluetoothAccessoryService()

        // Wire Battery / MagSafe Power Events to Notch Dynamic Island HUD
        self.batteryService.onPowerEvent = { [weak self] snapshot, _ in
            guard let self = self else { return }
            let timeText: String? = {
                if snapshot.isCharging, let minutes = snapshot.timeToFullMinutes {
                    let hrs = minutes / 60
                    let mins = minutes % 60
                    return hrs > 0 ? "\(hrs)h \(mins)m to full" : "\(mins)m to full"
                }
                return nil
            }()
            self.appState.showHUD(
                .battery(
                    percentage: snapshot.percentage,
                    isCharging: snapshot.isCharging,
                    timeRemaining: timeText
                ),
                duration: 3.0
            )
        }

        // Wire Caps Lock Events to Notch Dynamic Island HUD
        self.systemHUDService.onCapsLockChange = { [weak self] isCaps in
            self?.appState.showHUD(.capsLock(isOn: isCaps), duration: 2.0)
        }

        // Wire Bluetooth Audio / AirPods Accessory Connection Events
        self.bluetoothAccessoryService.onAccessoryConnected = { [weak self] event in
            self?.appState.showHUD(
                .accessory(name: event.name, icon: event.icon, batteryPercentage: event.batteryPercentage),
                duration: 3.5
            )
        }

        // Wire Focus Timer alerts to Notch Notification HUD
        self.timerService.onTimerCompleted = { [weak self] mode in
            self?.appState.showHUD(
                .notification(title: "\(mode.title) Finished!", subtitle: "Focus session concluded", icon: "timer"),
                duration: 4.0
            )
        }

        // Wire Now Playing playback start and track change to a 2-second glimpse in Notch
        var lastNotifiedTrackKey: String? = nil

        let triggerMusicGlimpse: (Track) -> Void = { [weak self] track in
            guard let self = self else { return }
            guard self.nowPlayingService.isPlaying, !track.title.isEmpty else { return }

            let cleanTitle = track.title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let cleanArtist = track.artist.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let trackKey = "\(cleanTitle)::\(cleanArtist)"

            // Guard against repeated triggers for the currently playing track
            guard trackKey != lastNotifiedTrackKey else { return }
            lastNotifiedTrackKey = trackKey

            self.appState.showHUD(
                .music(
                    title: track.title,
                    artist: track.artist.isEmpty ? (self.nowPlayingService.activePlayerName ?? "Now Playing") : track.artist
                ),
                duration: 2.0
            )
        }

        self.nowPlayingService.$isPlaying
            .removeDuplicates()
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] isPlaying in
                guard let self = self else { return }
                if isPlaying {
                    if let track = self.nowPlayingService.currentTrack, !track.title.isEmpty {
                        triggerMusicGlimpse(track)
                    }
                } else {
                    if case .music = self.appState.activeHUD {
                        self.appState.dismissHUD()
                    }
                }
            }
            .store(in: &cancellables)

        self.nowPlayingService.$currentTrack
            .removeDuplicates()
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] track in
                guard let self = self,
                      self.nowPlayingService.isPlaying,
                      let track = track,
                      !track.title.isEmpty else { return }
                triggerMusicGlimpse(track)
            }
            .store(in: &cancellables)

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
        self.windowManager = WindowManager(
            appState: appState,
            screenManager: screenManager,
            nowPlayingService: nowPlayingService,
            timerService: timerService
        )
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
            nowPlayingService: nowPlayingService,
            fileShelfManager: fileShelfManager,
            jotterManager: jotterManager,
            timerService: timerService,
            calendarSyncService: calendarSyncService
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
