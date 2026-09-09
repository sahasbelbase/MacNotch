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
                let camWidth = screenManager.currentNotchGeometry?.cameraExclusionRect?.width ?? 200
                let camHeight = screenManager.currentNotchGeometry?.cameraExclusionRect?.height ?? 34
                HStack(spacing: 0) {
                    HStack(spacing: 4) {
                        Image(systemName: "timer")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.orange)
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.trailing, 10)

                    Color.clear
                        .frame(width: max(camWidth, 160), height: camHeight)

                    HStack(spacing: 4) {
                        Text(timer.formattedRemaining)
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 10)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(Color.black.opacity(0.88))
                        .overlay(
                            Capsule().stroke(Color.orange.opacity(0.5), lineWidth: 1)
                        )
                        .shadow(color: Color.orange.opacity(0.25), radius: 8, x: 0, y: 1)
                )
                .transition(.scale(scale: 0.95, anchor: .top).combined(with: .opacity))
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
