import SwiftUI

/// Compact horizontal pill bar for selecting clipboard content categories.
public struct ClipboardCategoryBar: View {
    @Binding var selectedCategory: ClipboardCategory
    public var onSelect: ((ClipboardCategory) -> Void)?

    public init(selectedCategory: Binding<ClipboardCategory>, onSelect: ((ClipboardCategory) -> Void)? = nil) {
        self._selectedCategory = selectedCategory
        self.onSelect = onSelect
    }

    public var body: some View {
        HStack(spacing: 4) {
            ForEach(ClipboardCategory.allCases) { category in
                Button(action: {
                    withAnimation(DesignSystem.Animation.tabSwitch) {
                        selectedCategory = category
                        onSelect?(category)
                    }
                }) {
                    HStack(spacing: 3) {
                        Image(systemName: category.iconName)
                            .font(.system(size: 9, weight: .semibold))
                        Text(category.rawValue)
                            .font(.system(size: 10, weight: .medium))
                    }
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(
                        Capsule()
                            .fill(selectedCategory == category ? Color.accentColor.opacity(0.85) : Color.white.opacity(0.08))
                    )
                    .foregroundColor(selectedCategory == category ? .white : DesignSystem.Colors.textSecondary)
                }
                .buttonStyle(.plain)
            }
        }
    }
}
