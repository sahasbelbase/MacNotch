import SwiftUI

/// Minimal collapsed state that remains completely invisible/clear when idle,
/// displaying an accent pill only while actively hovering inside the camera notch.
public struct CollapsedNotchView: View {
    @ObservedObject var appState: AppState
    @ObservedObject var screenManager: ScreenManager
    var fileShelfManager: FileShelfManager?
    var timerService: TimerService?
    var nowPlayingService: SystemNowPlayingService?
    @State private var isDragTargeted: Bool = false

    public init(
        appState: AppState,
        screenManager: ScreenManager? = nil,
        fileShelfManager: FileShelfManager? = nil,
        timerService: TimerService? = nil,
        nowPlayingService: SystemNowPlayingService? = nil
    ) {
        self.appState = appState
        self.screenManager = screenManager ?? ScreenManager()
        self.fileShelfManager = fileShelfManager
        self.timerService = timerService
        self.nowPlayingService = nowPlayingService
    }

    public var body: some View {
        ZStack {
            if let hud = appState.activeHUD {
                let camWidth = screenManager.currentNotchGeometry?.cameraExclusionRect?.width ?? 200
                let camHeight = screenManager.currentNotchGeometry?.cameraExclusionRect?.height ?? 34
                NotchHUDView(hud: hud, cameraWidth: camWidth, cameraHeight: camHeight)
            } else if isDragTargeted {
                HStack(spacing: 5) {
                    Image(systemName: "tray.and.arrow.down.fill")
                        .font(.system(size: 11, weight: .bold))
                    Text("Drop to Shelf & AirDrop")
                        .font(.system(size: 9, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 3.5)
                .background(Color.cyan.opacity(0.9))
                .clipShape(Capsule())
                .shadow(color: Color.cyan.opacity(0.6), radius: 8, x: 0, y: 2)
                .transition(.scale.combined(with: .opacity))
            } else if let timer = timerService, timer.isRunning {
                HStack(spacing: 5) {
                    Image(systemName: "timer")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.orange)
                    Text(timer.formattedRemaining)
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 3.5)
                .background(Color.black.opacity(0.85))
                .overlay(
                    Capsule().stroke(Color.orange.opacity(0.7), lineWidth: 1)
                )
                .clipShape(Capsule())
                .shadow(color: Color.orange.opacity(0.4), radius: 6, x: 0, y: 1)
                .transition(.scale.combined(with: .opacity))
            } else if let nowPlaying = nowPlayingService, nowPlaying.isPlaying {
                HStack(spacing: 5) {
                    WaveformVisualizerView(
                        isPlaying: true,
                        color: DesignSystem.Colors.emerald,
                        barCount: 4,
                        maxHeight: 9
                    )
                    if let track = nowPlaying.currentTrack?.title, !track.isEmpty {
                        Text(track)
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(.white.opacity(0.9))
                            .lineLimit(1)
                            .frame(maxWidth: 80)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 3.5)
                .background(Color.black.opacity(0.85))
                .overlay(
                    Capsule().stroke(DesignSystem.Colors.emerald.opacity(0.6), lineWidth: 1)
                )
                .clipShape(Capsule())
                .shadow(color: DesignSystem.Colors.emerald.opacity(0.35), radius: 6, x: 0, y: 1)
                .transition(.scale.combined(with: .opacity))
            } else if appState.currentState == .activating {
                Capsule()
                    .fill(Color.accentColor.opacity(0.95))
                    .frame(width: 32, height: 3)
                    .shadow(color: Color.accentColor.opacity(0.6), radius: 6, x: 0, y: 1)
                    .transition(.opacity.combined(with: .scale))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.clear)
        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: appState.activeHUD)
        .onDrop(of: [.fileURL], isTargeted: $isDragTargeted) { providers in
            AirDropService.handleDroppedProviders(providers) { urls in
                fileShelfManager?.addFiles(urls)
                withAnimation(DesignSystem.Animation.expandSpring) {
                    appState.selectedTab = .shelf
                    appState.transition(to: .expanded)
                }
            }
            return true
        }
    }
}
