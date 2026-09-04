import SwiftUI
import ServiceManagement

/// Persists user preferences and system settings across sessions.
@MainActor
public final class SettingsStore: ObservableObject {
    public static let shared = SettingsStore()

    // MARK: - General Settings
    @AppStorage("enableNotch") public var enableNotch: Bool = true
    @AppStorage("hoverDelay") public var hoverDelay: Double = 0.28
    @AppStorage("collapseDelay") public var collapseDelay: Double = 0.35
    @AppStorage("launchAtLogin") public var launchAtLogin: Bool = false {
        didSet {
            updateLaunchAtLogin(launchAtLogin)
        }
    }

    // MARK: - Clipboard Settings
    @AppStorage("clipboardRetention") public var clipboardRetention: Int = 100
    @AppStorage("clipboardAutoDelete") public var clipboardAutoDelete: String = AutoDeletePeriod.never.rawValue
    @AppStorage("filterSensitive") public var filterSensitive: Bool = true
    @AppStorage("duplicatePolicy") public var duplicatePolicy: String = ClipboardDuplicatePolicy.moveToTop.rawValue

    // MARK: - Weather Settings
    @AppStorage("selectedLocationId") public var selectedLocationId: String = "ktm"
    @AppStorage("tempUnit") public var tempUnit: String = TemperatureUnit.celsius.rawValue

    // MARK: - Appearance Settings
    @AppStorage("appAppearance") public var appAppearance: String = "System"

    public init() {
        // Sync launch at login status with SMAppService if available
        if #available(macOS 13.0, *) {
            self.launchAtLogin = (SMAppService.mainApp.status == .enabled)
        }
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
        hoverDelay = 0.28
        collapseDelay = 0.35
        launchAtLogin = false
        clipboardRetention = 100
        clipboardAutoDelete = AutoDeletePeriod.never.rawValue
        filterSensitive = true
        duplicatePolicy = ClipboardDuplicatePolicy.moveToTop.rawValue
        selectedLocationId = "ktm"
        tempUnit = TemperatureUnit.celsius.rawValue
        appAppearance = "System"
    }
}
