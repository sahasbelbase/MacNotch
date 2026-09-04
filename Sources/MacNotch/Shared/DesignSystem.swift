import SwiftUI

/// Shared styling, spacing, typography, and color tokens for MacNotch.
public enum DesignSystem {
    // MARK: - Dimensions
    public enum Dimensions {
        public static let collapsedHeight: CGFloat = 10
        public static let expandedWidth: CGFloat = 720
        public static let expandedHeight: CGFloat = 290
        public static let cornerRadius: CGFloat = 20
        public static let notchCornerRadius: CGFloat = 10
        public static let cardWidth: CGFloat = 200
        public static let cardHeight: CGFloat = 120
        public static let cardCornerRadius: CGFloat = 12
        public static let activationExtraHeight: CGFloat = 12
    }

    // MARK: - Animations
    public enum Animation {
        public static let expandSpring = SwiftUI.Animation.spring(response: 0.36, dampingFraction: 0.82, blendDuration: 0)
        public static let collapseSpring = SwiftUI.Animation.spring(response: 0.32, dampingFraction: 0.88, blendDuration: 0)
        public static let tabSwitch = SwiftUI.Animation.easeInOut(duration: 0.2)
        public static let cardHover = SwiftUI.Animation.easeOut(duration: 0.15)
        public static let reducedMotion = SwiftUI.Animation.easeInOut(duration: 0.15)
    }

    // MARK: - Colors
    public enum Colors {
        public static let backgroundOverlay = Color.black.opacity(0.85)
        public static let surface = Color(nsColor: .windowBackgroundColor).opacity(0.65)
        public static let cardBackground = Color(nsColor: .controlBackgroundColor).opacity(0.6)
        public static let cardHoverBackground = Color(nsColor: .selectedControlColor).opacity(0.25)
        public static let subtleBorder = Color.white.opacity(0.12)
        public static let activeBorder = Color.accentColor.opacity(0.6)
        public static let textPrimary = Color.primary
        public static let textSecondary = Color.secondary
        public static let textTertiary = Color.secondary.opacity(0.7)
    }
}
