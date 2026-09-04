import AppKit
import Combine
import Foundation

/// Monitors cursor movements and coordinates with `AppState` and `ScreenManager`
/// to provide flicker-free, debounced hover activation and collapse.
@MainActor
public final class MouseTracker: ObservableObject {
    private let appState: AppState
    private let screenManager: ScreenManager
    
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var fallbackTimer: Timer?

    public init(appState: AppState, screenManager: ScreenManager) {
        self.appState = appState
        self.screenManager = screenManager
        setupTracking()
    }

    deinit {
        if let global = globalMonitor {
            NSEvent.removeMonitor(global)
        }
        if let local = localMonitor {
            NSEvent.removeMonitor(local)
        }
        fallbackTimer?.invalidate()
    }

    public func setupTracking() {
        stopTracking()

        // Global mouse moved monitor
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved]) { [weak self] event in
            MainActor.assumeIsolated {
                self?.handleMouseMoved(screenLocation: NSEvent.mouseLocation)
            }
        }

        // Local mouse moved monitor
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved]) { [weak self] event in
            MainActor.assumeIsolated {
                self?.handleMouseMoved(screenLocation: NSEvent.mouseLocation)
            }
            return event
        }

        // Fallback periodic timer (runs at low frequency only when in transitioning/expanded states
        // to catch cursor teleportation or rapid gestures that may bypass event monitors)
        fallbackTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.handleMouseMoved(screenLocation: NSEvent.mouseLocation)
            }
        }
    }

    public func stopTracking() {
        if let global = globalMonitor {
            NSEvent.removeMonitor(global)
            globalMonitor = nil
        }
        if let local = localMonitor {
            NSEvent.removeMonitor(local)
            localMonitor = nil
        }
        fallbackTimer?.invalidate()
        fallbackTimer = nil
    }

    /// Evaluates current mouse position against notch activation and expanded regions.
    public func handleMouseMoved(screenLocation: NSPoint) {
        guard appState.isEnabled, let geometry = screenManager.currentNotchGeometry else {
            return
        }

        let isInsideActivation = geometry.activationRect(extraBottomPadding: 16).contains(screenLocation)
        let expandedRect = geometry.expandedFrame()
        // Provide 10pt safety margin around the expanded frame so cursor can navigate easily
        let isInsideExpanded = expandedRect.insetBy(dx: -10, dy: -10).contains(screenLocation)

        switch appState.currentState {
        case .collapsed:
            if isInsideActivation {
                appState.handleMouseEnter()
            }

        case .activating:
            if !isInsideActivation {
                appState.handleMouseExit()
            }

        case .expanded:
            if !isInsideExpanded {
                appState.handleMouseExit()
            }

        case .collapsing:
            if isInsideExpanded || isInsideActivation {
                appState.handleMouseEnter()
            }

        case .hidden:
            break
        }
    }
}
