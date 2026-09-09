import AppKit
import Combine
import SwiftUI

/// Bridges AppKit window management with SwiftUI state and display geometry.
@MainActor
public final class WindowManager: ObservableObject {
    public let panel: NotchPanel
    private let appState: AppState
    private let screenManager: ScreenManager
    private var cancellables = Set<AnyCancellable>()

    public init(appState: AppState, screenManager: ScreenManager) {
        self.appState = appState
        self.screenManager = screenManager
        self.panel = NotchPanel(contentRect: .zero)

        setupSubscriptions()
        updateWindowPositionAndVisibility()
    }

    private func setupSubscriptions() {
        // React to state changes
        appState.$currentState
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.updateWindowPositionAndVisibility()
            }
            .store(in: &cancellables)

        // React to HUD changes
        appState.$activeHUD
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.updateWindowPositionAndVisibility()
            }
            .store(in: &cancellables)

        // React to geometry changes
        screenManager.$currentNotchGeometry
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.updateWindowPositionAndVisibility()
            }
            .store(in: &cancellables)
    }

    /// Embeds the root SwiftUI view into the panel.
    public func setContent<Content: View>(_ view: Content) {
        let hostingView = NSHostingView(rootView: view)
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = .clear
        panel.contentView = hostingView
    }

    /// Positions and sizes the panel according to current state and display geometry.
    public func updateWindowPositionAndVisibility() {
        guard appState.isEnabled,
              let geometry = screenManager.currentNotchGeometry,
              appState.currentState != .hidden else {
            panel.orderOut(nil)
            return
        }

        let targetFrame: NSRect
        switch appState.currentState {
        case .expanded:
            targetFrame = geometry.expandedRect
        case .collapsed, .activating, .collapsing:
            if appState.activeHUD != nil {
                targetFrame = geometry.hudRect
            } else {
                targetFrame = geometry.collapsedRect
            }
        case .hidden:
            panel.orderOut(nil)
            return
        }

        // Apply frame with smooth visual display
        if panel.frame != targetFrame {
            panel.setFrame(targetFrame, display: true, animate: false)
        }

        if !panel.isVisible {
            panel.orderFrontRegardless()
        }
    }
}
