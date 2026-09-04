import SwiftUI
import ServiceManagement

/// Persists user preferences and system settings across sessions.
@MainActor
public final class SettingsStore: ObservableObject {
    public static let shared = SettingsStore()

    // MARK: - General Settings
    @AppStorage("enableNotch") public var enableNotch: Bool = true
    @AppStorage("hoverDelay") public var hoverDelay: Double = 0.12
    @AppStorage("collapseDelay") public var collapseDelay: Double = 0.35
    @AppStorage("launchAtLogin") public var launchAtLogin: Bool = false {
        didSet {
            updateLaunchAtLogin(launchAtLogin)
        }
    }

    // MARK: - Clipboard Settings
    @AppStorage("clipboardRetention") public var clipboardRetention: Int = 80
    @AppStorage("clipboardAutoDelete") public var clipboardAutoDelete: String = AutoDeletePeriod.never.rawValue
    @AppStorage("filterSensitive") public var filterSensitive: Bool = true
    @AppStorage("duplicatePolicy") public var duplicatePolicy: String = ClipboardDuplicatePolicy.moveToTop.rawValue

    // MARK: - Music & Layout Customization Settings
    @AppStorage("musicSource") public var musicSource: String = "Auto"
    @AppStorage("showOverviewMusic") public var showOverviewMusic: Bool = true
    @AppStorage("showOverviewClipboard") public var showOverviewClipboard: Bool = true
    @AppStorage("defaultTab") public var defaultTab: String = "Overview"

    // MARK: - Weather Settings
    @AppStorage("selectedLocationId") public var selectedLocationId: String = "ktm"
    @AppStorage("tempUnit") public var tempUnit: String = TemperatureUnit.celsius.rawValue

    // MARK: - Appearance & Diagnostic Settings
    @AppStorage("appAppearance") public var appAppearance: String = "System"
    @AppStorage("showGeometryOverlay") public var showGeometryOverlay: Bool = false

    public init() {
        // Sync launch at login status with SMAppService if available
        if #available(macOS 13.0, *) {
            let isServiceEnabled = (SMAppService.mainApp.status == .enabled)
            if launchAtLogin && !isServiceEnabled {
                updateLaunchAtLogin(true)
            } else if !launchAtLogin && isServiceEnabled {
                self.launchAtLogin = true
            }
        }
    }

    /// Explicitly updates launch at login with system ServiceManagement registration.
    public func setLaunchAtLogin(_ enabled: Bool) {
        launchAtLogin = enabled
        updateLaunchAtLogin(enabled)
    }

    public var isLaunchAtLoginActive: Bool {
        if #available(macOS 13.0, *) {
            return SMAppService.mainApp.status == .enabled
        }
        return launchAtLogin
    }

    private func updateLaunchAtLogin(_ enabled: Bool) {
        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    if SMAppService.mainApp.status != .enabled {
                        try SMAppService.mainApp.register()
                    }
                } else {
                    if SMAppService.mainApp.status == .enabled {
                        try SMAppService.mainApp.unregister()
                    }
                }
            } catch {
                print("Failed to update launch at login: \(error)")
            }
        }
    }

    /// Resets all settings to default values.
    public func resetToDefaults() {
        enableNotch = true
        hoverDelay = 0.12
        collapseDelay = 0.35
        setLaunchAtLogin(false)
        clipboardRetention = 80
        clipboardAutoDelete = AutoDeletePeriod.never.rawValue
        filterSensitive = true
        duplicatePolicy = ClipboardDuplicatePolicy.moveToTop.rawValue
        musicSource = "Auto"
        showOverviewMusic = true
        showOverviewClipboard = true
        defaultTab = "Overview"
        selectedLocationId = "ktm"
        tempUnit = TemperatureUnit.celsius.rawValue
        appAppearance = "System"
    }
}
