import SwiftUI

/// Horizontally scrollable carousel displaying clipboard history.
public struct ClipboardView: View {
    @ObservedObject var clipboardManager: ClipboardManager

    public init(clipboardManager: ClipboardManager) {
        self.clipboardManager = clipboardManager
    }

    public var body: some View {
        VStack(spacing: 8) {
            // Header: Title, Pause Status, Item Count, Clear
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "doc.on.clipboard.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.accentColor)
                    Text("Clipboard")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(DesignSystem.Colors.textPrimary)

                    if clipboardManager.isPaused {
                        Text("Paused")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.orange)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Color.orange.opacity(0.15))
                            .clipShape(Capsule())
                    }
                }

                Spacer()

                HStack(spacing: 12) {
                    Button(action: {
                        clipboardManager.isPaused.toggle()
                    }) {
                        Image(systemName: clipboardManager.isPaused ? "play.circle" : "pause.circle")
                            .font(.system(size: 12))
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                    .buttonStyle(.plain)
                    .help(clipboardManager.isPaused ? "Resume Recording" : "Pause History Recording")

                    if !clipboardManager.items.isEmpty {
                        Button(action: {
                            clipboardManager.clearHistory()
                        }) {
                            Text("Clear")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                        }
                        .buttonStyle(.plain)
                        .help("Clear Clipboard History")
                    }
                }
            }
            .padding(.horizontal, 4)

            // Horizontal Carousel
            if clipboardManager.items.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "clipboard")
                        .font(.system(size: 24))
                        .foregroundColor(DesignSystem.Colors.textTertiary)
                    Text("Clipboard history is empty")
                        .font(.system(size: 11))
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                    Text("Copied text, links, and code will appear here")
                        .font(.system(size: 10))
                        .foregroundColor(DesignSystem.Colors.textTertiary)
                }
                .frame(maxWidth: .infinity, maxHeight: DesignSystem.Dimensions.cardHeight)
            } else {
                ScrollViewReader { proxy in
                    HStack(spacing: 4) {
                        // Previous Button
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                proxy.scrollTo(clipboardManager.items.first?.id, anchor: .leading)
                            }
                        }) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(DesignSystem.Colors.textTertiary)
                                .frame(width: 14, height: 40)
                        }
                        .buttonStyle(.plain)

                        // Cards Carousel
                        ScrollView(.horizontal, showsIndicators: false) {
                            LazyHStack(spacing: 10) {
                                ForEach(clipboardManager.items) { item in
                                    ClipboardCardView(
                                        item: item,
                                        onCopy: {
                                            clipboardManager.copyToPasteboard(item)
                                        },
                                        onDelete: {
                                            withAnimation(.easeOut(duration: 0.2)) {
                                                clipboardManager.remove(item: item)
                                            }
                                        }
                                    )
                                    .id(item.id)
                                }
                            }
                            .padding(.vertical, 2)
                        }

                        // Next Button
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                proxy.scrollTo(clipboardManager.items.last?.id, anchor: .trailing)
                            }
                        }) {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(DesignSystem.Colors.textTertiary)
                                .frame(width: 14, height: 40)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
}
