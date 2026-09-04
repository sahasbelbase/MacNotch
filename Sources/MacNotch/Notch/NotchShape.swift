import SwiftUI

/// Custom continuous corner shape that cleanly attaches to the top edge of the screen,
/// emulating the MacBook camera housing silhouette.
public struct NotchShape: Shape {
    public var cornerRadius: CGFloat
    public var topCornersRadius: CGFloat

    public var animatableData: CGFloat {
        get { cornerRadius }
        set { cornerRadius = newValue }
    }

    public init(cornerRadius: CGFloat = DesignSystem.Dimensions.notchCornerRadius, topCornersRadius: CGFloat = 0) {
        self.cornerRadius = cornerRadius
        self.topCornersRadius = topCornersRadius
    }

    public func path(in rect: CGRect) -> Path {
        var path = Path()

        // Start top-left corner
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))

        // Top edge
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))

        // Right edge down to bottom-right corner
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - cornerRadius))

        // Bottom-right rounded corner
        path.addArc(
            center: CGPoint(x: rect.maxX - cornerRadius, y: rect.maxY - cornerRadius),
            radius: cornerRadius,
            startAngle: .degrees(0),
            endAngle: .degrees(90),
            clockwise: false
        )

        // Bottom edge
        path.addLine(to: CGPoint(x: rect.minX + cornerRadius, y: rect.maxY))

        // Bottom-left rounded corner
        path.addArc(
            center: CGPoint(x: rect.minX + cornerRadius, y: rect.maxY - cornerRadius),
            radius: cornerRadius,
            startAngle: .degrees(90),
            endAngle: .degrees(180),
            clockwise: false
        )

        // Left edge back to top
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.closeSubpath()

        return path
    }
}
