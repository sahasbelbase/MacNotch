import SwiftUI

/// Animated audio spectrum waveform with fluidly bouncing equalizer bars.
/// Used in the Collapsed Notch Dynamic Island and in the expanded Music Card.
public struct WaveformVisualizerView: View {
    public var isPlaying: Bool
    public var color: Color
    public var barCount: Int
    public var maxHeight: CGFloat

    @State private var animating: Bool = false

    public init(
        isPlaying: Bool = true,
        color: Color = DesignSystem.Colors.emerald,
        barCount: Int = 4,
        maxHeight: CGFloat = 12
    ) {
        self.isPlaying = isPlaying
        self.color = color
        self.barCount = barCount
        self.maxHeight = maxHeight
    }

    public var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<barCount, id: \.self) { index in
                WaveformBar(
                    index: index,
                    isPlaying: isPlaying,
                    color: color,
                    maxHeight: maxHeight
                )
            }
        }
        .frame(height: maxHeight)
    }
}

private struct WaveformBar: View {
    let index: Int
    let isPlaying: Bool
    let color: Color
    let maxHeight: CGFloat

    @State private var barHeight: CGFloat = 3

    var body: some View {
        RoundedRectangle(cornerRadius: 1.5)
            .fill(color)
            .frame(width: 2.5, height: barHeight)
            .onAppear {
                updateAnimation()
            }
            .onChange(of: isPlaying) { _ in
                updateAnimation()
            }
    }

    private func updateAnimation() {
        if isPlaying {
            // Distinct natural oscillations per bar
            let durations = [0.45, 0.6, 0.35, 0.52, 0.4]
            let duration = durations[index % durations.count]
            let minH: CGFloat = 3.0
            let heights: [CGFloat] = [maxHeight * 0.9, maxHeight * 0.5, maxHeight, maxHeight * 0.7]
            let targetH = heights[index % heights.count]

            withAnimation(
                Animation.easeInOut(duration: duration)
                    .repeatForever(autoreverses: true)
                    .delay(Double(index) * 0.12)
            ) {
                barHeight = targetH
            }
        } else {
            withAnimation(.easeOut(duration: 0.2)) {
                barHeight = 2.5
            }
        }
    }
}
