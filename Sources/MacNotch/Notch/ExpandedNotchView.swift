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
                case .music:
                    MusicView(nowPlayingService: nowPlayingService, isCompact: false, isFullTab: true)
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
            // Tab Selection Pills
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

            // Status Pills (Time & Weather)
            HStack(spacing: 8) {
                TimeView(timeService: timeService, isCompact: true)
                Text("•")
                    .foregroundColor(DesignSystem.Colors.textTertiary)
                    .font(.system(size: 8))
                WeatherView(weatherService: weatherService, isCompact: true)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(Color.black.opacity(0.35))
            )
        }
        .padding(.horizontal, 6)
        .padding(.top, 2)
    }

    // MARK: - Overview Hierarchy View (Zero-overlap vertical arrangement)
    private var overviewHierarchyView: some View {
        VStack(spacing: 8) {
            // Row 2: Full-width Music bar with dedicated controls
            MusicView(nowPlayingService: nowPlayingService, isCompact: false, isFullTab: false)

            // Row 3: Full-width Clipboard Carousel
            ClipboardView(clipboardManager: clipboardManager)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
