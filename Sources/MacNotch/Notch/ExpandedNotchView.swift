import SwiftUI

/// Main expanded utility interface integrating Time, Weather, Music, and Clipboard history
/// with a responsive, vertically spacious hierarchy and zero icon collision.
public struct ExpandedNotchView: View {
    @ObservedObject var appState: AppState
    @ObservedObject var screenManager: ScreenManager
    @ObservedObject var clipboardManager: ClipboardManager
    @ObservedObject var timeService: TimeService
    @ObservedObject var weatherService: WeatherService
    @ObservedObject var nowPlayingService: SystemNowPlayingService
    @State private var isDropTargeted: Bool = false

    public init(
        appState: AppState,
        screenManager: ScreenManager,
        clipboardManager: ClipboardManager,
        timeService: TimeService,
        weatherService: WeatherService,
        nowPlayingService: SystemNowPlayingService
    ) {
        self.appState = appState
        self.screenManager = screenManager
        self.clipboardManager = clipboardManager
        self.timeService = timeService
        self.weatherService = weatherService
        self.nowPlayingService = nowPlayingService
    }

    public var body: some View {
        ZStack {
            mainContentLayout
            if isDropTargeted {
                airDropOverlayView
            }
        }
        .padding(10)
        .background(panelBackgroundView)
        .onAppear {
            nowPlayingService.musicStudioProvider.fetchPlaybackState()
        }
        .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
            AirDropService.handleDroppedProviders(providers)
            return true
        }
        .onKeyPress { press in
            if press.modifiers.contains(.command) {
                switch press.characters {
                case "1":
                    withAnimation(DesignSystem.Animation.tabSwitch) { appState.selectedTab = .overview }
                    return .handled
                case "2":
                    withAnimation(DesignSystem.Animation.tabSwitch) { appState.selectedTab = .clipboard }
                    return .handled
                case "3":
                    withAnimation(DesignSystem.Animation.tabSwitch) { appState.selectedTab = .calendar }
                    return .handled
                case "4":
                    withAnimation(DesignSystem.Animation.tabSwitch) { appState.selectedTab = .weather }
                    return .handled
                default:
                    break
                }
            }
            return .ignored
        }
    }

    private var mainContentLayout: some View {
        VStack(spacing: 8) {
            topHeaderBar
            Divider()
                .background(DesignSystem.Colors.subtleBorder)
                .padding(.horizontal, 4)
            tabContentView
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var panelBackgroundView: some View {
        RoundedRectangle(cornerRadius: DesignSystem.Dimensions.cornerRadius, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.Dimensions.cornerRadius, style: .continuous)
                    .stroke(DesignSystem.Colors.subtleBorder, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.4), radius: 24, x: 0, y: 12)
    }

    @ViewBuilder
    private var tabContentView: some View {
        switch appState.selectedTab {
        case .overview:
            overviewHierarchyView
        case .clipboard:
            ClipboardView(clipboardManager: clipboardManager)
        case .calendar:
            CalendarView(timeService: timeService)
        case .weather:
            WeatherView(weatherService: weatherService, isCompact: false)
        }
    }

    // MARK: - Header Bar (Left Ear / Notch Cutout / Right Ear Flanking Layout)
    private var topHeaderBar: some View {
        HStack(alignment: .center, spacing: 0) {
            // Left Ear: MacNotch Icon, Overview & Clipboard (flanking left of the physical camera notch)
            HStack(spacing: 6) {
                macNotchBrandBadge
                tabButton(for: .overview)
                tabButton(for: .clipboard)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.trailing, 8)

            // Center: Physical camera notch gap dynamically calculated from hardware screen
            let cameraWidth = screenManager.currentNotchGeometry?.cameraExclusionRect?.width ?? 226
            let cameraHeight = screenManager.currentNotchGeometry?.cameraExclusionRect?.height ?? 34
            Color.clear
                .frame(width: cameraWidth, height: cameraHeight)

            // Right Ear: Calendar, Weather, AirDrop & Settings (flanking right of the physical camera notch)
            HStack(spacing: 5) {
                tabButton(for: .calendar)
                tabButton(for: .weather)
                airDropButton
                settingsButton
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 8)
        }
        .padding(.horizontal, 6)
        .padding(.top, 2)
    }

    private var macNotchBrandBadge: some View {
        Button(action: {
            withAnimation(DesignSystem.Animation.tabSwitch) {
                appState.selectedTab = .overview
            }
        }) {
            Group {
                if let appIcon = NSImage(named: "AppIcon") ?? NSApplication.shared.applicationIconImage {
                    Image(nsImage: appIcon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 20, height: 20)
                        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                } else {
                    Image(systemName: "menubar.arrow.up.rectangle")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.accentColor)
                        .frame(width: 20, height: 20)
                }
            }
            .shadow(color: Color.accentColor.opacity(0.35), radius: 3, x: 0, y: 1)
        }
        .buttonStyle(.plain)
        .pointingHandCursor()
        .help("MacNotch Overview (⌘1)")
    }

    @ViewBuilder
    private func tabButton(for tab: NotchTab) -> some View {
        Button(action: {
            withAnimation(DesignSystem.Animation.tabSwitch) {
                appState.selectedTab = tab
            }
        }) {
            HStack(spacing: 4) {
                Image(systemName: tab.icon)
                    .font(.system(size: 10, weight: .semibold))
                Text(tab.rawValue)
                    .font(.system(size: 11, weight: .medium))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(appState.selectedTab == tab ? Color.white.opacity(0.18) : Color.clear)
            )
            .foregroundColor(appState.selectedTab == tab ? .white : DesignSystem.Colors.textSecondary)
        }
        .buttonStyle(.plain)
    }

    private var airDropButton: some View {
        Button(action: {
            openAirDropFilePicker()
        }) {
            Image(systemName: "airdrop")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(DesignSystem.Colors.textSecondary)
                .frame(width: 24, height: 24)
                .background(Color.white.opacity(0.08))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .help("Share files via AirDrop (or drag & drop files onto the Notch)")
    }

    private func openAirDropFilePicker() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.prompt = "AirDrop"
        panel.message = "Select files to share via AirDrop"
        panel.begin { response in
            if response == .OK {
                AirDropService.share(urls: panel.urls)
            }
        }
    }

    private var airDropOverlayView: some View {
        ZStack {
            RoundedRectangle(cornerRadius: DesignSystem.Dimensions.cornerRadius, style: .continuous)
                .fill(Color.black.opacity(0.88))
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.Dimensions.cornerRadius, style: .continuous)
                        .stroke(Color.accentColor, lineWidth: 2)
                )

            VStack(spacing: 8) {
                Image(systemName: "airdrop")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(.accentColor)
                Text("Drop to AirDrop")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
                Text("Release files here to instantly share with nearby Apple devices")
                    .font(.system(size: 11))
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }
        }
        .transition(.opacity)
    }

    private var settingsButton: some View {
        Button(action: {
            SettingsWindowController.shared.showSettings(clipboardManager: clipboardManager)
        }) {
            Image(systemName: "gearshape.fill")
                .font(.system(size: 11))
                .foregroundColor(DesignSystem.Colors.textSecondary)
                .frame(width: 24, height: 24)
                .background(Color.white.opacity(0.08))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .help("Open MacNotch Settings")
    }

    @State private var overviewLowerMode: OverviewLowerMode = .musicStudio

    // MARK: - Overview Hierarchy View (Music as Main Hero, Music Studio List & Clips Below)
    private var overviewHierarchyView: some View {
        let settings = SettingsStore.shared
        let trackCount = nowPlayingService.musicStudioProvider.libraryTracks.count
        let clipCount = clipboardManager.items.count

        return VStack(spacing: 6) {
            // Section 1: Prominent Music Hero Card
            if settings.showOverviewMusic {
                MusicView(
                    nowPlayingService: nowPlayingService,
                    isCompact: false,
                    isFullTab: false,
                    isHero: true,
                    onOpenLibrary: {
                        withAnimation(DesignSystem.Animation.tabSwitch) {
                            overviewLowerMode = .musicStudio
                        }
                    }
                )
            }

            // Lower Section Switcher: [ 🎵 Music Studio (171) ] [ 📋 Recent Clips (80) ]
            HStack(spacing: 6) {
                Button(action: {
                    withAnimation(DesignSystem.Animation.tabSwitch) {
                        overviewLowerMode = .musicStudio
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "music.note.list")
                            .font(.system(size: 9, weight: .semibold))
                        Text("Music Studio List\(trackCount > 0 ? " (\(trackCount))" : "")")
                            .font(.system(size: 10, weight: .medium))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 3.5)
                    .background(
                        Capsule().fill(overviewLowerMode == .musicStudio ? Color.accentColor.opacity(0.2) : Color.white.opacity(0.06))
                    )
                    .foregroundColor(overviewLowerMode == .musicStudio ? .accentColor : DesignSystem.Colors.textSecondary)
                }
                .buttonStyle(.plain)

                if settings.showOverviewClipboard {
                    Button(action: {
                        withAnimation(DesignSystem.Animation.tabSwitch) {
                            overviewLowerMode = .clipboard
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "doc.on.clipboard")
                                .font(.system(size: 9, weight: .semibold))
                            Text("Recent Clips\(clipCount > 0 ? " (\(clipCount))" : "")")
                                .font(.system(size: 10, weight: .medium))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 3.5)
                        .background(
                            Capsule().fill(overviewLowerMode == .clipboard ? Color.accentColor.opacity(0.2) : Color.white.opacity(0.06))
                        )
                        .foregroundColor(overviewLowerMode == .clipboard ? .accentColor : DesignSystem.Colors.textSecondary)
                    }
                    .buttonStyle(.plain)
                }

                Spacer()
            }
            .padding(.horizontal, 4)

            // Section 2: Lower Content (Music Studio Song List or Clipboard Carousel)
            Group {
                if overviewLowerMode == .musicStudio {
                    MusicStudioListView(musicStudioProvider: nowPlayingService.musicStudioProvider)
                } else if settings.showOverviewClipboard {
                    ClipboardView(clipboardManager: clipboardManager)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

public enum OverviewLowerMode: String, CaseIterable, Identifiable {
    case musicStudio = "Music Studio"
    case clipboard = "Recent Clips"
    public var id: String { rawValue }
}
