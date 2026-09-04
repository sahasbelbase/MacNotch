import SwiftUI

/// Minimal collapsed state that remains completely invisible/clear when idle,
/// displaying an accent pill only while actively hovering inside the camera notch.
public struct CollapsedNotchView: View {
    @ObservedObject var appState: AppState
    @State private var isDragTargeted: Bool = false

    public init(appState: AppState) {
        self.appState = appState
    }

    public var body: some View {
        ZStack {
            // When collapsed, do NOT draw any dark background or shape on the screen.
            // Only show a responsive accent indicator when actively hovering inside the camera notch or dragging files.
            if isDragTargeted {
                HStack(spacing: 4) {
                    Image(systemName: "airdrop")
                        .font(.system(size: 11, weight: .bold))
                    Text("Drop to AirDrop")
                        .font(.system(size: 9, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.accentColor.opacity(0.9))
                .clipShape(Capsule())
                .shadow(color: Color.accentColor.opacity(0.6), radius: 8, x: 0, y: 2)
                .transition(.scale.combined(with: .opacity))
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
        .onDrop(of: [.fileURL], isTargeted: $isDragTargeted) { providers in
            AirDropService.handleDroppedProviders(providers)
            return true
        }
    }
}
