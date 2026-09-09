import SwiftUI

/// Root SwiftUI view hosted inside `NotchPanel`.
public struct NotchView: View {
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
    @Environment(\.accessibilityReduceMotion) var reduceMotion

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
            if appState.currentState == .expanded {
                ExpandedNotchView(
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
                .transition(
                    reduceMotion
                    ? .opacity
                    : .asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.95, anchor: .top)),
                        removal: .opacity.combined(with: .scale(scale: 0.95, anchor: .top))
                    )
                )
            } else if appState.currentState != .hidden {
                CollapsedNotchView(
                    appState: appState,
                    screenManager: screenManager,
                    fileShelfManager: fileShelfManager,
                    timerService: timerService,
                    nowPlayingService: nowPlayingService
                )
                .transition(.opacity)
            }
        }
        .animation(reduceMotion ? DesignSystem.Animation.reducedMotion : DesignSystem.Animation.expandSpring, value: appState.currentState)
    }
}
