import SwiftUI

/// Native macOS Settings window interface.
public struct SettingsView: View {
    @ObservedObject var settings: SettingsStore = .shared
    @ObservedObject var screenManager: ScreenManager
    @ObservedObject var clipboardManager: ClipboardManager

    public init(screenManager: ScreenManager, clipboardManager: ClipboardManager) {
        self.screenManager = screenManager
        self.clipboardManager = clipboardManager
    }

    public var body: some View {
        TabView {
            generalTab
                .tabItem {
                    Label("General", systemImage: "gear")
                }

            clipboardTab
                .tabItem {
                    Label("Clipboard", systemImage: "doc.on.clipboard")
                }

            weatherTab
                .tabItem {
                    Label("Weather", systemImage: "cloud.sun")
                }

            appearanceTab
                .tabItem {
                    Label("Appearance", systemImage: "paintpalette")
                }

            advancedTab
                .tabItem {
                    Label("Advanced", systemImage: "slider.horizontal.3")
                }
        }
        .padding(20)
        .frame(width: 480, height: 340)
    }

    // MARK: - General Tab

    private var generalTab: some View {
        Form {
            Section {
                Toggle("Enable MacNotch Interaction", isOn: $settings.enableNotch)

                Toggle("Launch at Login", isOn: $settings.launchAtLogin)
            }

            Section("Hover Delays") {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Activation Delay:")
                        Spacer()
                        Text("\(Int(settings.hoverDelay * 1000)) ms")
                            .foregroundColor(.secondary)
                    }
                    Slider(value: $settings.hoverDelay, in: 0.15...0.60, step: 0.05)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Collapse Delay:")
                        Spacer()
                        Text("\(Int(settings.collapseDelay * 1000)) ms")
                            .foregroundColor(.secondary)
                    }
                    Slider(value: $settings.collapseDelay, in: 0.20...0.80, step: 0.05)
                }
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Clipboard Tab

    private var clipboardTab: some View {
        Form {
            Section {
                Picker("Retention Limit", selection: $settings.clipboardRetention) {
                    ForEach(RetentionLimit.allCases) { limit in
                        Text(limit.description).tag(limit.rawValue)
                    }
                }

                Picker("Auto-delete History", selection: $settings.clipboardAutoDelete) {
                    ForEach(AutoDeletePeriod.allCases) { period in
                        Text(period.rawValue).tag(period.rawValue)
                    }
                }

                Toggle("Filter Sensitive Passwords & API Keys", isOn: $settings.filterSensitive)
            }

            Section {
                HStack {
                    Text("Total items recorded: \(clipboardManager.items.count)")
                        .foregroundColor(.secondary)

                    Spacer()

                    Button("Clear History Now") {
                        clipboardManager.clearHistory()
                    }
                    .foregroundColor(.red)
                }
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Weather Tab

    private var weatherTab: some View {
        Form {
            Section("Location") {
                Picker("City", selection: $settings.selectedLocationId) {
                    ForEach(WeatherLocation.presets) { loc in
                        Text(loc.name).tag(loc.id)
                    }
                }
            }

            Section("Units") {
                Picker("Temperature Unit", selection: $settings.tempUnit) {
                    ForEach(TemperatureUnit.allCases) { unit in
                        Text(unit.rawValue).tag(unit.rawValue)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Appearance Tab

    private var appearanceTab: some View {
        Form {
            Section("Theme") {
                Picker("Theme Appearance", selection: $settings.appAppearance) {
                    Text("System Default").tag("System")
                    Text("Dark Mode").tag("Dark")
                    Text("Light Mode").tag("Light")
                }
                .pickerStyle(.inline)
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Advanced Tab

    private var advancedTab: some View {
        Form {
            Section("Display Diagnostic") {
                HStack {
                    Text("Notch Detected:")
                    Spacer()
                    Text(screenManager.hasNotch ? "Yes" : "No (External / Non-Notch Display)")
                        .foregroundColor(screenManager.hasNotch ? .green : .secondary)
                }

                if let geo = screenManager.currentNotchGeometry {
                    HStack {
                        Text("Notch Size:")
                        Spacer()
                        Text("\(Int(geo.notchRect.width)) × \(Int(geo.notchRect.height)) pt")
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Screen Bounds:")
                        Spacer()
                        Text("\(Int(geo.screenFrame.width)) × \(Int(geo.screenFrame.height)) pt")
                            .foregroundColor(.secondary)
                    }
                }
            }

            Section {
                Button("Reset All Settings to Defaults") {
                    settings.resetToDefaults()
                }
                .foregroundColor(.red)
            }
        }
        .formStyle(.grouped)
    }
}
