import SwiftUI

/// Compact search field for filtering clipboard records locally.
public struct ClipboardSearchBar: View {
    @Binding var text: String
    @FocusState.Binding var isFocused: Bool

    public init(text: Binding<String>, isFocused: FocusState<Bool>.Binding) {
        self._text = text
        self._isFocused = isFocused
    }

    public var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(DesignSystem.Colors.textTertiary)

            TextField("Search clipboard...", text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 11))
                .focused($isFocused)

            if !text.isEmpty {
                Button(action: {
                    text = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundColor(DesignSystem.Colors.textTertiary)
                }
                .buttonStyle(.plain)
            } else {
                Text("⌘F")
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .foregroundColor(DesignSystem.Colors.textTertiary.opacity(0.8))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(3)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.black.opacity(0.25))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(isFocused ? Color.accentColor.opacity(0.6) : DesignSystem.Colors.subtleBorder, lineWidth: 1)
                )
        )
    }
}
