import SwiftUI

/// Minimal collapsed state that remains completely invisible/clear when idle,
/// displaying an accent pill only while actively hovering inside the camera notch.
public struct CollapsedNotchView: View {
    @ObservedObject var appState: AppState

    public init(appState: AppState) {
        self.appState = appState
    }

    public var body: some View {
        ZStack {
            // When collapsed, do NOT draw any dark background or shape on the screen.
            // Only show a responsive accent indicator when actively hovering inside the camera notch.
            if appState.currentState == .activating {
                Capsule()
                    .fill(Color.accentColor.opacity(0.95))
                    .frame(width: 32, height: 3)
                    .shadow(color: Color.accentColor.opacity(0.6), radius: 6, x: 0, y: 1)
                    .transition(.opacity.combined(with: .scale))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.clear)
    }
}
