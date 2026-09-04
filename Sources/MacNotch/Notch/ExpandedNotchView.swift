import SwiftUI

/// Main expanded utility interface integrating Time, Weather, Music, and Clipboard history
/// with a responsive, vertically spacious hierarchy and zero icon collision.
public struct ExpandedNotchView: View {
    @ObservedObject var appState: AppState
    @ObservedObject var clipboardManager: ClipboardManager
    @ObservedObject var timeService: TimeService
    @ObservedObject var weatherService: WeatherService
    @ObservedObject var nowPlayingService: SystemNowPlayingService

    public init(
        appState: AppState,
        clipboardManager: ClipboardManager,
        timeService: TimeService,
        weatherService: WeatherService,
        nowPlayingService: SystemNowPlayingService
    ) {
        self.appState = appState
        self.clipboardManager = clipboardManager
        self.timeService = timeService
        self.weatherService = weatherService
        self.nowPlayingService = nowPlayingService
    }

    public var body: some View {
        VStack(spacing: 8) {
            // Row 1: Top Navigation Tabs & Status Pills
            topHeaderBar

            Divider()
                .background(DesignSystem.Colors.subtleBorder)
                .padding(.horizontal, 4)

            // Dynamic Tab Content
            Group {
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
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.Dimensions.cornerRadius, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.Dimensions.cornerRadius, style: .continuous)
                        .stroke(DesignSystem.Colors.subtleBorder, lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.4), radius: 24, x: 0, y: 12)
        )
    }

    // MARK: - Header Bar
    private var topHeaderBar: some View {
        HStack {
            // Tab Selection Pills (Overview, Clipboard, Calendar, Weather)
            HStack(spacing: 4) {
                ForEach(NotchTab.allCases) { tab in
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
            }

            Spacer(minLength: 12)

            // In-Notch Settings Button
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
        .padding(.horizontal, 6)
        .padding(.top, 2)
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
