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

            sectionsTab
                .tabItem {
                    Label("Layout", systemImage: "square.grid.2x2")
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
        .frame(width: 520, height: 380)
    }

    // MARK: - General Tab

    private var generalTab: some View {
        Form {
            Section {
                Toggle("Enable MacNotch Interaction", isOn: $settings.enableNotch)

                HStack {
                    Toggle("Launch at Login (Start on Boot)", isOn: Binding(
                        get: { settings.launchAtLogin },
                        set: { settings.setLaunchAtLogin($0) }
                    ))

                    Spacer()

                    if settings.isLaunchAtLoginActive {
                        Text("Active")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.green)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.15))
                            .clipShape(Capsule())
                    }
                }
            }

            Section("Hover Delays") {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Activation Delay:")
                        Spacer()
                        Text("\(Int(settings.hoverDelay * 1000)) ms")
                            .foregroundColor(.secondary)
                    }
                    Slider(value: $settings.hoverDelay, in: 0.05...0.40, step: 0.02)
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

    // MARK: - Sections & Layout Tab

    private var sectionsTab: some View {
        Form {
            Section("Default Startup Tab") {
                Picker("Default Tab on Expand", selection: $settings.defaultTab) {
                    ForEach(NotchTab.allCases) { tab in
                        Text(tab.rawValue).tag(tab.rawValue)
                    }
                }
            }

            Section("Overview Hierarchy Sections") {
                Toggle("Show Music Hero Player", isOn: $settings.showOverviewMusic)
                Toggle("Show Recent Clipboard Carousel", isOn: $settings.showOverviewClipboard)
            }

            Section("Music Player Integration") {
                Picker("Preferred Audio Source", selection: $settings.musicSource) {
                    Text("Automatic (Smart Fallback)").tag("Auto")
                    Text("Music Studio \(isMusicStudioDownloaded ? "✓" : "(Not Downloaded)")").tag("MusicStudio")
                    Text("Spotify \(isSpotifyDownloaded ? "✓" : "(Not Downloaded)")").tag("Spotify")
                    Text("YouTube Music \(isYouTubeMusicDownloaded ? "✓" : "(Web Streaming)")").tag("YouTubeMusic")
                    Text("Apple Music ✓").tag("Music")
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Smart Fallback Priority: Music Studio → Spotify → YouTube Music → Apple Music")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.primary)

                    HStack(spacing: 10) {
                        playerStatusPill(name: "Music Studio", isInstalled: isMusicStudioDownloaded)
                        playerStatusPill(name: "Spotify", isInstalled: isSpotifyDownloaded)
                        playerStatusPill(name: "Apple Music", isInstalled: isAppleMusicDownloaded)
                        playerStatusPill(name: "YouTube Music", isInstalled: isYouTubeMusicDownloaded)
                    }
                    .padding(.top, 2)
                }
            }
        }
        .formStyle(.grouped)
    }

    private var isMusicStudioDownloaded: Bool {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.musicstudio.app") != nil
            || FileManager.default.fileExists(atPath: "/Applications/Music Studio.app")
            || FileManager.default.fileExists(atPath: ("~/Applications/Music Studio.app" as NSString).expandingTildeInPath)
    }

    private var isSpotifyDownloaded: Bool {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.spotify.client") != nil
            || FileManager.default.fileExists(atPath: "/Applications/Spotify.app")
            || FileManager.default.fileExists(atPath: ("~/Applications/Spotify.app" as NSString).expandingTildeInPath)
    }

    private var isAppleMusicDownloaded: Bool {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Music") != nil
            || FileManager.default.fileExists(atPath: "/System/Applications/Music.app")
    }

    private var isYouTubeMusicDownloaded: Bool {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.github.th-ch.youtube-music") != nil
            || NSWorkspace.shared.urlForApplication(withBundleIdentifier: "app.ytmdesktop.ytmdesktop") != nil
            || FileManager.default.fileExists(atPath: "/Applications/YouTube Music.app")
    }

    private func playerStatusPill(name: String, isInstalled: Bool) -> some View {
        HStack(spacing: 3) {
            Circle()
                .fill(isInstalled ? Color.green : Color.orange.opacity(0.8))
                .frame(width: 6, height: 6)
            Text("\(name): \(isInstalled ? "Ready" : "Not Found")")
                .font(.system(size: 9))
                .foregroundColor(.secondary)
        }
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

                Picker("Duplicate Behavior", selection: $settings.duplicatePolicy) {
                    ForEach(ClipboardDuplicatePolicy.allCases) { policy in
                        Text(policy.rawValue).tag(policy.rawValue)
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
            Section("Developer Geometry Overlay") {
                Toggle("Show Geometry Overlay", isOn: $settings.showGeometryOverlay)
                    .onChange(of: settings.showGeometryOverlay) { _, isVisible in
                        GeometryOverlayWindow.shared.update(
                            geometry: screenManager.currentNotchGeometry,
                            isVisible: isVisible
                        )
                    }

                Text("Visual overlay rendering Camera Exclusion (Red), Activation (Blue), Collapsed (Green), and Expanded (Purple).")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }

            Section("Display Diagnostic") {
                if let screen = screenManager.activeScreen {
                    diagnosticRow("Screen:", screen.localizedName)
                    diagnosticRow("Frame:", formatRect(screen.frame))
                    diagnosticRow("Visible Frame:", formatRect(screen.visibleFrame))
                    diagnosticRow("Safe Area Insets:", "T:\(Int(screen.safeAreaInsets.top)) L:\(Int(screen.safeAreaInsets.left)) B:\(Int(screen.safeAreaInsets.bottom)) R:\(Int(screen.safeAreaInsets.right)) pt")
                    diagnosticRow("Backing Scale:", "\(Int(screen.backingScaleFactor))x (\(Int(screen.frame.width * screen.backingScaleFactor)) × \(Int(screen.frame.height * screen.backingScaleFactor)) px)")
                }

                if let caps = screenManager.currentCapabilities {
                    diagnosticRow("Display Type:", caps.isBuiltin ? "Built-in Display (Internal)" : "External Display")
                    diagnosticRow("Auxiliary Top Left:", caps.leftAuxiliaryArea.map { formatRect($0) } ?? "None")
                    diagnosticRow("Auxiliary Top Right:", caps.rightAuxiliaryArea.map { formatRect($0) } ?? "None")
                }

                HStack {
                    Text("Has Camera Notch:")
                    Spacer()
                    Text(screenManager.hasNotch ? "Yes (Hardware Notch)" : "No (External / Non-Notch Display)")
                        .fontWeight(.semibold)
                        .foregroundColor(screenManager.hasNotch ? .green : .secondary)
                }

                if let geo = screenManager.currentNotchGeometry {
                    if let cameraRect = geo.cameraExclusionRect {
                        diagnosticRow("Camera Exclusion:", formatRect(cameraRect))
                    }
                    diagnosticRow("Activation Rect:", formatRect(geo.activationRect))
                    diagnosticRow("Collapsed Rect:", formatRect(geo.collapsedRect))
                    diagnosticRow("Expanded Rect:", formatRect(geo.expandedRect))
                }
            }

            Section {
                Button("Reset All Settings to Defaults") {
                    settings.resetToDefaults()
                    GeometryOverlayWindow.shared.update(geometry: nil, isVisible: false)
                }
                .foregroundColor(.red)
            }
        }
        .formStyle(.grouped)
        .onAppear {
            if settings.showGeometryOverlay {
                GeometryOverlayWindow.shared.update(
                    geometry: screenManager.currentNotchGeometry,
                    isVisible: true
                )
            }
        }
    }

    private func diagnosticRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.secondary)
        }
    }

    private func formatRect(_ r: CGRect) -> String {
        "(\(Int(r.origin.x)), \(Int(r.origin.y)), \(Int(r.size.width)) × \(Int(r.size.height)))"
    }
}
