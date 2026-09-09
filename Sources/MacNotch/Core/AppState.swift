import Foundation
import SwiftUI
import Combine

/// Notch interaction states governed by the central state machine.
public enum NotchState: String, CaseIterable, Sendable {
    case hidden
    case collapsed
    case activating
    case expanded
    case collapsing

    public var isInteractive: Bool {
        self == .expanded
    }

    public var isExpandedOrActivating: Bool {
        self == .expanded || self == .activating
    }
}

/// Active tab in the expanded notch utility.
public enum NotchTab: String, CaseIterable, Identifiable, Sendable {
    case overview = "Overview"
    case clipboard = "Clipboard"
    case shelf = "Shelf"
    case jotter = "Jotter"
    case calendar = "Calendar"
    case weather = "Weather"

    public var id: String { rawValue }

    public var icon: String {
        switch self {
        case .overview: return "square.grid.2x2"
        case .clipboard: return "doc.on.clipboard"
        case .shelf: return "tray.and.arrow.down"
        case .jotter: return "square.and.pencil"
        case .calendar: return "calendar"
        case .weather: return "cloud.sun"
        }
    }
}

/// Transient Notch overlays that briefly flank the notch without requiring hover activation.
public enum TransientHUD: Equatable, Sendable {
    case battery(percentage: Int, isCharging: Bool, timeRemaining: String?)
    case volume(level: Float, isMuted: Bool)
    case brightness(level: Float)
    case capsLock(isOn: Bool)
    case accessory(name: String, icon: String, batteryPercentage: Int?)
    case notification(title: String, subtitle: String?, icon: String)
}

/// Central state machine and controller for the MacNotch application.
@MainActor
public final class AppState: ObservableObject {
    @Published public private(set) var currentState: NotchState = .collapsed
    @Published public var selectedTab: NotchTab = .overview
    @Published public var isEnabled: Bool = true {
        didSet {
            if !isEnabled {
                transition(to: .hidden)
            } else {
                transition(to: .collapsed)
            }
        }
    }

    // Transient HUD overlay (e.g. Volume, Battery MagSafe, Caps Lock)
    @Published public private(set) var activeHUD: TransientHUD?
    private var hudDismissTask: Task<Void, Never>?

    // Configurable delays (in seconds)
    @Published public var hoverActivationDelay: Double = 0.12
    @Published public var collapseDelay: Double = 0.35

    private var activationTask: Task<Void, Never>?
    private var collapseTask: Task<Void, Never>?

    public init() {}

    /// Triggers a sleek notch HUD overlay that automatically dismisses after `duration` seconds.
    public func showHUD(_ hud: TransientHUD, duration: Double = 2.5) {
        guard isEnabled else { return }
        guard currentState != .expanded else { return }

        activeHUD = hud
        hudDismissTask?.cancel()
        hudDismissTask = Task { @MainActor [weak self] in
            let delayNanos = UInt64(duration * 1_000_000_000)
            try? await Task.sleep(nanoseconds: delayNanos)
            if !Task.isCancelled {
                self?.dismissHUD()
            }
        }
    }

    public func dismissHUD() {
        hudDismissTask?.cancel()
        hudDismissTask = nil
        activeHUD = nil
    }

    /// Safely transitions to a new state, managing timers and avoiding jitter.
    public func transition(to newState: NotchState) {
        guard isEnabled else {
            currentState = .hidden
            return
        }

        switch (currentState, newState) {
        case (.hidden, .collapsed):
            currentState = .collapsed

        case (.collapsed, .activating):
            cancelCollapseTask()
            currentState = .activating
            startActivationTimer()

        case (.activating, .expanded):
            cancelActivationTask()
            currentState = .expanded

        case (.activating, .collapsed):
            cancelActivationTask()
            currentState = .collapsed

        case (.expanded, .collapsing):
            cancelActivationTask()
            currentState = .collapsing
            startCollapseTimer()

        case (.collapsing, .expanded):
            cancelCollapseTask()
            currentState = .expanded

        case (.collapsing, .collapsed):
            cancelCollapseTask()
            currentState = .collapsed

        case (_, .hidden):
            cancelAllTasks()
            currentState = .hidden

        default:
            // Direct transition fallback if forced
            cancelAllTasks()
            currentState = newState
        }
    }

    // MARK: - Timer Scheduling

    public func handleMouseEnter() {
        guard isEnabled else { return }
        dismissHUD()
        switch currentState {
        case .collapsed:
            transition(to: .activating)
        case .collapsing:
            transition(to: .expanded)
        case .activating, .expanded, .hidden:
            break
        }
    }

    public func handleMouseExit() {
        guard isEnabled else { return }
        switch currentState {
        case .activating:
            transition(to: .collapsed)
        case .expanded:
            transition(to: .collapsing)
        case .collapsing, .collapsed, .hidden:
            break
        }
    }

    private func startActivationTimer() {
        activationTask?.cancel()
        activationTask = Task { @MainActor [weak self] in
            guard let self = self else { return }
            let delayNanos = UInt64(self.hoverActivationDelay * 1_000_000_000)
            do {
                try await Task.sleep(nanoseconds: delayNanos)
                if !Task.isCancelled && self.currentState == .activating {
                    self.transition(to: .expanded)
                }
            } catch {
                // Task was cancelled, do nothing
            }
        }
    }

    private func startCollapseTimer() {
        collapseTask?.cancel()
        collapseTask = Task { @MainActor [weak self] in
            guard let self = self else { return }
            let delayNanos = UInt64(self.collapseDelay * 1_000_000_000)
            do {
                try await Task.sleep(nanoseconds: delayNanos)
                if !Task.isCancelled && self.currentState == .collapsing {
                    self.transition(to: .collapsed)
                }
            } catch {
                // Task was cancelled, do nothing
            }
        }
    }

    public func cancelActivationTask() {
        activationTask?.cancel()
        activationTask = nil
    }

    public func cancelCollapseTask() {
        collapseTask?.cancel()
        collapseTask = nil
    }

    public func cancelAllTasks() {
        cancelActivationTask()
        cancelCollapseTask()
    }
}
