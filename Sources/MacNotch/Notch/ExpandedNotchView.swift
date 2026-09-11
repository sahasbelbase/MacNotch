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
    @ObservedObject var fileShelfManager: FileShelfManager
    @ObservedObject var jotterManager: JotterManager
    @ObservedObject var timerService: TimerService
    @ObservedObject var calendarSyncService: CalendarSyncService
    @State private var isDropTargeted: Bool = false
    @State private var showPowerTools: Bool = false

    public init(
        appState: AppState,
        screenManager: ScreenManager,
        clipboardManager: ClipboardManager,
        timeService: TimeService,
        weatherService: WeatherService,
        nowPlayingService: SystemNowPlayingService,
        fileShelfManager: FileShelfManager? = nil,
        jotterManager: JotterManager? = nil,
        timerService: TimerService? = nil,
        calendarSyncService: CalendarSyncService? = nil
    ) {
        self.appState = appState
        self.screenManager = screenManager
        self.clipboardManager = clipboardManager
        self.timeService = timeService
        self.weatherService = weatherService
        self.nowPlayingService = nowPlayingService
        self.fileShelfManager = fileShelfManager ?? FileShelfManager()
        self.jotterManager = jotterManager ?? JotterManager()
        self.timerService = timerService ?? TimerService()
        self.calendarSyncService = calendarSyncService ?? CalendarSyncService()
    }

    public var body: some View {
        ZStack {
            mainContentLayout
            if showPowerTools {
                powerToolsOverlayView
            }
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
            AirDropService.handleDroppedProviders(providers) { urls in
                fileShelfManager.addFiles(urls)
                withAnimation(DesignSystem.Animation.tabSwitch) {
                    appState.selectedTab = .shelf
                }
            }
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
                    withAnimation(DesignSystem.Animation.tabSwitch) { appState.selectedTab = .shelf }
                    return .handled
                case "4":
                    withAnimation(DesignSystem.Animation.tabSwitch) { appState.selectedTab = .jotter }
                    return .handled
                case "5":
                    withAnimation(DesignSystem.Animation.tabSwitch) { appState.selectedTab = .calendar }
                    return .handled
                case "6":
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
        case .shelf:
            FileShelfView(shelfManager: fileShelfManager)
        case .jotter:
            JotterView(jotterManager: jotterManager)
        case .calendar:
            CalendarView(
                timeService: timeService,
                calendarSyncService: calendarSyncService,
                timerService: timerService
            )
        case .weather:
            WeatherView(weatherService: weatherService, isCompact: false)
        }
    }

    // MARK: - Header Bar (Left Ear / Notch Cutout / Right Ear Flanking Layout)
    private var topHeaderBar: some View {
        HStack(alignment: .center, spacing: 0) {
            // Left Ear: MacNotch Icon, Overview, Clipboard, File Shelf, & Jotter
            HStack(spacing: 5) {
                macNotchBrandBadge
                tabButton(for: .overview)
                tabButton(for: .clipboard)
                tabButton(for: .shelf)
                tabButton(for: .jotter)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.trailing, 8)

            // Center: Physical camera notch gap dynamically calculated from hardware screen
            let cameraWidth = screenManager.currentNotchGeometry?.cameraExclusionRect?.width ?? 226
            let cameraHeight = screenManager.currentNotchGeometry?.cameraExclusionRect?.height ?? 34
            Color.clear
                .frame(width: cameraWidth, height: cameraHeight)

            // Right Ear: Calendar, Weather, Timer Pill, Power Tools, AirDrop & Settings
            HStack(spacing: 5) {
                tabButton(for: .calendar)
                tabButton(for: .weather)
                if timerService.isRunning {
                    TimerWidgetView(timerService: timerService, isCompact: true)
                }
                toolsButton
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
        let isSelected = appState.selectedTab == tab
        Button(action: {
            withAnimation(DesignSystem.Animation.tabSwitch) {
                appState.selectedTab = tab
            }
        }) {
            HStack(spacing: 4) {
                Image(systemName: tab.icon)
                    .font(.system(size: 11, weight: isSelected ? .bold : .medium))
                if isSelected {
                    Text(tab.rawValue)
                        .font(.system(size: 11, weight: .semibold))
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                }
            }
            .padding(.horizontal, isSelected ? 8 : 6)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(isSelected ? Color.white.opacity(0.18) : Color.clear)
            )
            .foregroundColor(isSelected ? .white : DesignSystem.Colors.textSecondary)
        }
        .buttonStyle(.plain)
        .pointingHandCursor()
        .help(tab.rawValue)
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

    private var toolsButton: some View {
        Button(action: {
            withAnimation(DesignSystem.Animation.tabSwitch) {
                showPowerTools.toggle()
            }
        }) {
            Image(systemName: "wand.and.stars")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(showPowerTools ? .accentColor : DesignSystem.Colors.textSecondary)
                .frame(width: 24, height: 24)
                .background(showPowerTools ? Color.accentColor.opacity(0.25) : Color.white.opacity(0.08))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .help("Power Tools (Eyedropper, Screen OCR, QR Generator)")
    }

    private var powerToolsOverlayView: some View {
        ZStack {
            Color.black.opacity(0.85)
                .onTapGesture {
                    withAnimation(DesignSystem.Animation.tabSwitch) {
                        showPowerTools = false
                    }
                }

            VStack(spacing: 8) {
                HStack {
                    Label("Power Tools Suite", systemImage: "wand.and.stars")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.accentColor)

                    Spacer()

                    Button(action: {
                        withAnimation(DesignSystem.Animation.tabSwitch) {
                            showPowerTools = false
                        }
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(DesignSystem.Colors.textTertiary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 4)

                PowerToolsView(appState: appState, clipboardManager: clipboardManager)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(nsColor: .windowBackgroundColor).opacity(0.98))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(DesignSystem.Colors.subtleBorder, lineWidth: 1)
            )
            .padding(20)
        }
        .transition(.opacity.combined(with: .scale(scale: 0.96)))
    }

    @State private var overviewLowerMode: OverviewLowerMode = .musicStudio
    @State private var hasAutoSelectedMode: Bool = false

    // MARK: - Overview Hierarchy View (Music as Main Hero, Music Studio List & Clips Below)
    private var overviewHierarchyView: some View {
        let settings = SettingsStore.shared
        let trackCount = nowPlayingService.musicStudioProvider.libraryTracks.count
        let clipCount = clipboardManager.items.count

        // Smart Lower Mode: if user hasn't explicitly clicked a tab, default to Recent Clips if Music Studio has 0 tracks!
        let effectiveMode: OverviewLowerMode = {
            if hasAutoSelectedMode { return overviewLowerMode }
            return trackCount > 0 ? .musicStudio : .clipboard
        }()

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
                            hasAutoSelectedMode = true
                            overviewLowerMode = .musicStudio
                        }
                    }
                )
            }

            // Lower Section Switcher: [ 🎵 Music Studio (171) ] [ 📋 Recent Clips (80) ]
            HStack(spacing: 6) {
                Button(action: {
                    withAnimation(DesignSystem.Animation.tabSwitch) {
                        hasAutoSelectedMode = true
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
                        Capsule().fill(effectiveMode == .musicStudio ? Color.accentColor.opacity(0.2) : Color.white.opacity(0.06))
                    )
                    .foregroundColor(effectiveMode == .musicStudio ? .accentColor : DesignSystem.Colors.textSecondary)
                }
                .buttonStyle(.plain)

                if settings.showOverviewClipboard {
                    Button(action: {
                        withAnimation(DesignSystem.Animation.tabSwitch) {
                            hasAutoSelectedMode = true
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
                            Capsule().fill(effectiveMode == .clipboard ? Color.accentColor.opacity(0.2) : Color.white.opacity(0.06))
                        )
                        .foregroundColor(effectiveMode == .clipboard ? .accentColor : DesignSystem.Colors.textSecondary)
                    }
                    .buttonStyle(.plain)
                }

                Spacer()
            }
            .padding(.horizontal, 4)

            // Section 2: Lower Content (Music Studio Song List or Clipboard Carousel)
            Group {
                if effectiveMode == .musicStudio {
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
