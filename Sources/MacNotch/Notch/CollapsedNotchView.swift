import SwiftUI

/// Minimal collapsed state that visually integrates with the physical camera housing.
public struct CollapsedNotchView: View {
    @ObservedObject var appState: AppState

    public init(appState: AppState) {
        self.appState = appState
    }

    public var body: some View {
        ZStack {
            // Background matching physical camera notch
            NotchShape(cornerRadius: DesignSystem.Dimensions.notchCornerRadius)
                .fill(Color.black)
                .overlay(
                    NotchShape(cornerRadius: DesignSystem.Dimensions.notchCornerRadius)
                        .stroke(DesignSystem.Colors.subtleBorder.opacity(0.4), lineWidth: 0.5)
                )

            // Subtle indicator when activating
            if appState.currentState == .activating {
                Capsule()
                    .fill(Color.accentColor.opacity(0.8))
                    .frame(width: 24, height: 3)
                    .offset(y: 12)
                    .transition(.opacity.combined(with: .scale))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
