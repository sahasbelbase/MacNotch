import SwiftUI

/// Minimal collapsed state that visually integrates with the physical camera housing
/// as a sleek hardware chin extending below the notch.
public struct CollapsedNotchView: View {
    @ObservedObject var appState: AppState

    public init(appState: AppState) {
        self.appState = appState
    }

    public var body: some View {
        ZStack {
            // Hardware-matched chin with continuous bottom rounded corners
            NotchShape(cornerRadius: 6)
                .fill(Color.black)
                .overlay(
                    NotchShape(cornerRadius: 6)
                        .stroke(DesignSystem.Colors.subtleBorder.opacity(0.4), lineWidth: 0.5)
                )

            // Subtle indicator when mouse enters activation zone
            if appState.currentState == .activating {
                Capsule()
                    .fill(Color.accentColor.opacity(0.9))
                    .frame(width: 28, height: 2.5)
                    .transition(.opacity.combined(with: .scale))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
