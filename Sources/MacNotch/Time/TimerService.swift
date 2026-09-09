import AppKit
import Combine
import Foundation

/// Timer preset / operation mode.
public enum TimerMode: Equatable, Sendable {
    case pomodoro(minutes: Int)
    case shortBreak(minutes: Int)
    case custom(minutes: Int)

    public var title: String {
        switch self {
        case .pomodoro(let mins): return "\(mins)m Focus"
        case .shortBreak(let mins): return "\(mins)m Break"
        case .custom(let mins): return "\(mins)m Timer"
        }
    }
}

/// Service managing focus timers, Pomodoro cycles, and glanceable notch countdowns.
@MainActor
public final class TimerService: ObservableObject {
    @Published public private(set) var isRunning: Bool = false
    @Published public private(set) var isPaused: Bool = false
    @Published public private(set) var totalSeconds: Int = 1500
    @Published public private(set) var remainingSeconds: Int = 1500
    @Published public private(set) var currentMode: TimerMode = .pomodoro(minutes: 25)

    public var onTimerFinished: ((TimerMode) -> Void)?
    public var onTimerCompleted: ((TimerMode) -> Void)?

    private var countdownTimer: Timer?

    public init() {}

    deinit {
        countdownTimer?.invalidate()
    }

    public var progress: Double {
        guard totalSeconds > 0 else { return 0.0 }
        return 1.0 - (Double(remainingSeconds) / Double(totalSeconds))
    }

    public var formattedRemaining: String {
        let mins = remainingSeconds / 60
        let secs = remainingSeconds % 60
        return String(format: "%02d:%02d", mins, secs)
    }

    // MARK: - Control Actions

    public func start(minutes: Int, mode: TimerMode? = nil) {
        countdownTimer?.invalidate()
        let seconds = max(1, minutes * 60)
        self.totalSeconds = seconds
        self.remainingSeconds = seconds
        self.currentMode = mode ?? .custom(minutes: minutes)
        self.isRunning = true
        self.isPaused = false

        scheduleTick()
    }

    public func pause() {
        guard isRunning, !isPaused else { return }
        countdownTimer?.invalidate()
        isPaused = true
    }

    public func resume() {
        guard isRunning, isPaused else { return }
        isPaused = false
        scheduleTick()
    }

    public func reset() {
        countdownTimer?.invalidate()
        isRunning = false
        isPaused = false
        remainingSeconds = totalSeconds
    }

    private func scheduleTick() {
        countdownTimer?.invalidate()
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.handleTick()
            }
        }
    }

    private func handleTick() {
        guard isRunning, !isPaused else { return }

        if remainingSeconds > 1 {
            remainingSeconds -= 1
        } else {
            remainingSeconds = 0
            isRunning = false
            isPaused = false
            countdownTimer?.invalidate()

            // Play system notification chime
            NSSound(named: "Glass")?.play()
            onTimerFinished?(currentMode)
            onTimerCompleted?(currentMode)
        }
    }
}
