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

    /// Changes cursor to pointing hand on mouse hover.
    public func pointingHandCursor() -> some View {
        self.onHover { inside in
            if inside {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
    }
}

extension NSRect {
    /// Center point of the rectangle.
    public var center: CGPoint {
        CGPoint(x: midX, y: midY)
    }
}
