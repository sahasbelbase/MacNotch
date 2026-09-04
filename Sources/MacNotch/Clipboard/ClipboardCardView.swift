import SwiftUI
import AppKit

/// Individual card representing a clipboard item in the horizontal carousel.
public struct ClipboardCardView: View {
    public let item: ClipboardItem
    public let onCopy: () -> Void
    public let onDelete: () -> Void
    
    @State private var isHovered: Bool = false
    @State private var showCopiedBadge: Bool = false

    public init(item: ClipboardItem, onCopy: @escaping () -> Void, onDelete: @escaping () -> Void) {
        self.item = item
        self.onCopy = onCopy
        self.onDelete = onDelete
    }

    public var body: some View {
        Button(action: handleCopy) {
            VStack(alignment: .leading, spacing: 6) {
                // Header: Icon, Type, Time, Delete
                HStack(spacing: 4) {
                    Image(systemName: item.type.iconName)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(typeColor)

                    Text(item.type.title)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(DesignSystem.Colors.textSecondary)

                    Spacer()

                    if isHovered {
                        Button(action: onDelete) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 12))
                                .foregroundColor(DesignSystem.Colors.textTertiary)
                        }
                        .buttonStyle(.plain)
                        .transition(.opacity)
                    } else {
                        Text(item.formattedTime)
                            .font(.system(size: 9))
                            .foregroundColor(DesignSystem.Colors.textTertiary)
                    }
                }

                // Main Content Preview
                ZStack {
                    if let path = item.imagePath, let image = NSImage(contentsOfFile: imagePathURL(path).path) {
                        Image(nsImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(maxWidth: .infinity, maxHeight: 52)
                            .clipped()
                            .cornerRadius(6)
                    } else if item.type == .code {
                        Text(item.preview)
                            .font(.system(size: 11, weight: .regular, design: .monospaced))
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                            .lineLimit(3)
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                    } else if item.type == .url, let host = item.domainHost {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(host)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(Color.accentColor)
                                .lineLimit(1)
                            Text(item.preview)
                                .font(.system(size: 10))
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                                .lineLimit(2)
                        }
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                    } else {
                        Text(item.preview)
                            .font(.system(size: 11))
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                            .lineLimit(3)
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                    }

                    // Copied Feedback Badge
                    if showCopiedBadge {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Copied")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.black.opacity(0.85))
                        .clipShape(Capsule())
                        .transition(.scale.combined(with: .opacity))
                    }
                }
                .frame(height: 54)

                Spacer(minLength: 0)
            }
            .padding(8)
            .frame(width: DesignSystem.Dimensions.cardWidth, height: DesignSystem.Dimensions.cardHeight)
            .macNotchCardStyle(isSelected: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(DesignSystem.Animation.cardHover) {
                self.isHovered = hovering
            }
        }
    }

    private func handleCopy() {
        onCopy()
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .default)

        withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
            showCopiedBadge = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            withAnimation(.easeOut(duration: 0.2)) {
                showCopiedBadge = false
            }
        }
    }

    private var typeColor: Color {
        switch item.type {
        case .text: return .blue
        case .url: return .indigo
        case .code: return .orange
        case .image: return .purple
        case .file: return .teal
        }
    }

    private func imagePathURL(_ filename: String) -> URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("MacNotch/images/\(filename)")
    }
}
