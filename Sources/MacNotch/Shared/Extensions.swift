import SwiftUI
import AppKit

extension View {
    /// Applies conditional modifier.
    @ViewBuilder
    public func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }

    /// Custom subtle glass card modifier.
    public func macNotchCardStyle(isSelected: Bool = false) -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.Dimensions.cardCornerRadius, style: .continuous)
                    .fill(isSelected ? DesignSystem.Colors.cardHoverBackground : DesignSystem.Colors.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.Dimensions.cardCornerRadius, style: .continuous)
                    .stroke(isSelected ? DesignSystem.Colors.activeBorder : DesignSystem.Colors.subtleBorder, lineWidth: 1)
            )
    }
}

extension NSRect {
    /// Center point of the rectangle.
    public var center: CGPoint {
        CGPoint(x: midX, y: midY)
    }
}
