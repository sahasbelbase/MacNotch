import SwiftUI

/// Compact or expanded Pomodoro Focus Timer widget.
public struct TimerWidgetView: View {
    @ObservedObject var timerService: TimerService
    public var isCompact: Bool = false

    public init(timerService: TimerService, isCompact: Bool = false) {
        self.timerService = timerService
        self.isCompact = isCompact
    }

    public var body: some View {
        if isCompact {
            compactPillView
        } else {
            fullTimerCard
        }
    }

    // MARK: - Compact Pill View (Used in Notch Wings or Header)

    private var compactPillView: some View {
        HStack(spacing: 4) {
            Image(systemName: timerService.isRunning ? "timer" : "timer.circle")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(timerService.isRunning ? .orange : .secondary)

            Text(timerService.isRunning ? timerService.formattedRemaining : "Timer")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundColor(timerService.isRunning ? .white : DesignSystem.Colors.textSecondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(
            Capsule()
                .fill(timerService.isRunning ? Color.orange.opacity(0.2) : Color.white.opacity(0.06))
        )
    }

    // MARK: - Full Timer Card (Used in Calendar & Schedule Sidebar)

    private var fullTimerCard: some View {
        VStack(spacing: 8) {
            HStack {
                Label("Focus Timer", systemImage: "timer")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.orange)

                Spacer()

                Text(timerService.currentMode.title)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }

            HStack(spacing: 12) {
                // Countdown text and progress bar
                VStack(alignment: .leading, spacing: 3) {
                    Text(timerService.formattedRemaining)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(.white)

                    // Fluid Progress Bar
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.white.opacity(0.12))
                            Capsule().fill(Color.orange)
                                .frame(width: max(0, min(geo.size.width, geo.size.width * CGFloat(timerService.progress))))
                        }
                    }
                    .frame(height: 4)
                }

                // Play / Pause / Reset Buttons
                HStack(spacing: 6) {
                    if timerService.isRunning && !timerService.isPaused {
                        Button(action: { timerService.pause() }) {
                            Image(systemName: "pause.fill")
                                .font(.system(size: 12))
                                .frame(width: 26, height: 26)
                                .background(Color.white.opacity(0.12))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                    } else if timerService.isPaused {
                        Button(action: { timerService.resume() }) {
                            Image(systemName: "play.fill")
                                .font(.system(size: 12))
                                .frame(width: 26, height: 26)
                                .background(Color.orange.opacity(0.9))
                                .foregroundColor(.black)
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                    } else {
                        Button(action: { timerService.start(minutes: 25, mode: .pomodoro(minutes: 25)) }) {
                            Image(systemName: "play.fill")
                                .font(.system(size: 12))
                                .frame(width: 26, height: 26)
                                .background(Color.orange.opacity(0.9))
                                .foregroundColor(.black)
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                    }

                    if timerService.isRunning || timerService.isPaused {
                        Button(action: { timerService.reset() }) {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.system(size: 10))
                                .frame(width: 24, height: 24)
                                .background(Color.white.opacity(0.08))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // Quick Presets
            HStack(spacing: 4) {
                presetButton(title: "25m Focus", minutes: 25, mode: .pomodoro(minutes: 25))
                presetButton(title: "5m Break", minutes: 5, mode: .shortBreak(minutes: 5))
                presetButton(title: "15m Sprint", minutes: 15, mode: .custom(minutes: 15))
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(timerService.isRunning ? Color.orange.opacity(0.4) : DesignSystem.Colors.subtleBorder, lineWidth: 1)
                )
        )
    }

    private func presetButton(title: String, minutes: Int, mode: TimerMode) -> some View {
        Button(action: {
            timerService.start(minutes: minutes, mode: mode)
        }) {
            Text(title)
                .font(.system(size: 9, weight: .medium))
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Color.white.opacity(0.06))
                .cornerRadius(4)
                .foregroundColor(DesignSystem.Colors.textSecondary)
        }
        .buttonStyle(.plain)
    }
}
