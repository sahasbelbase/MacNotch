import AppKit
import Combine
import Foundation

/// Manages multi-display environments, observes display changes, and recalculates notch geometry.
@MainActor
public final class ScreenManager: ObservableObject {
    @Published public private(set) var activeScreen: NSScreen?
    @Published public private(set) var currentNotchGeometry: NotchGeometry?
    @Published public private(set) var hasNotch: Bool = false
    
    private let notchDetector: NotchDetector
    private var cancellables = Set<AnyCancellable>()
    private var screenChangeObserver: NSObjectProtocol?

    public init(notchDetector: NotchDetector = .shared) {
        self.notchDetector = notchDetector
        recalculateDisplayGeometry()
        setupObservers()
    }

    deinit {
        if let observer = screenChangeObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    /// Recalculates display and notch geometry from current system screens.
    public func recalculateDisplayGeometry() {
        if let result = notchDetector.findNotchScreen() {
            self.activeScreen = result.screen
            self.currentNotchGeometry = result.geometry
            self.hasNotch = true
        } else {
            // Fall back to main screen or nil (no visual notch on non-notch screen)
            self.activeScreen = NSScreen.main
            self.currentNotchGeometry = nil
            self.hasNotch = false
        }
    }

    private func setupObservers() {
        // Observe display changes (connections, disconnections, resolution changes, scaling)
        screenChangeObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.recalculateDisplayGeometry()
            }
        }
    }
}
