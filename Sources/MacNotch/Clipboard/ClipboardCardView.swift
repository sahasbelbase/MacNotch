import SwiftUI
import AppKit

/// Individual card representing a clipboard item in the horizontal carousel.
public struct ClipboardCardView: View {
    public let item: ClipboardItem
    public var isSelected: Bool = false
    public let onCopy: () -> Void
    public let onCopyPlainText: () -> Void
    public let onTogglePin: () -> Void
    public let onDelete: () -> Void
    public let onInspect: () -> Void
    
    @State private var isHovered: Bool = false
    @State private var showCopiedBadge: Bool = false

    public init(
        item: ClipboardItem,
        isSelected: Bool = false,
        onCopy: @escaping () -> Void,
        onCopyPlainText: @escaping () -> Void,
        onTogglePin: @escaping () -> Void,
        onDelete: @escaping () -> Void,
        onInspect: @escaping () -> Void
    ) {
        self.item = item
        self.isSelected = isSelected
        self.onCopy = onCopy
        self.onCopyPlainText = onCopyPlainText
        self.onTogglePin = onTogglePin
        self.onDelete = onDelete
        self.onInspect = onInspect
    }

    public var body: some View {
        Button(action: handleCopy) {
            VStack(alignment: .leading, spacing: 6) {
                // Header: Icon, Type, Pin, Time/Size, Delete
                HStack(spacing: 4) {
                    Image(systemName: item.type.iconName)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(typeColor)

                    Text(item.type.title)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(DesignSystem.Colors.textSecondary)

                    if item.isPinned {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 8))
                            .foregroundColor(.orange)
                    }

                    Spacer()

                    if isHovered {
                        HStack(spacing: 4) {
                            Button(action: onInspect) {
                                Image(systemName: "info.circle")
                                    .font(.system(size: 11))
                                    .foregroundColor(DesignSystem.Colors.textTertiary)
                            }
                            .buttonStyle(.plain)
                            .help("Inspect details")

                            Button(action: onDelete) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 11))
                                    .foregroundColor(DesignSystem.Colors.textTertiary)
                            }
                            .buttonStyle(.plain)
                            .help("Delete item")
                        }
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
                            .font(.system(size: 10, weight: .regular, design: .monospaced))
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                            .lineLimit(3)
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                    } else if item.type == .url, let host = item.domainHost {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 3) {
                                Image(systemName: "link")
                                    .font(.system(size: 8))
                                Text(host)
                                    .font(.system(size: 10, weight: .bold))
                            }
                            .foregroundColor(Color.accentColor)
                            .lineLimit(1)

                            Text(item.preview)
                                .font(.system(size: 9))
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                                .lineLimit(2)
                        }
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                    } else if item.type == .file {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 3) {
                                Image(systemName: "doc.fill")
                                    .font(.system(size: 9))
                                Text(item.preview)
                                    .font(.system(size: 10, weight: .semibold))
                            }
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                            .lineLimit(1)

                            if let size = item.formattedFileSize {
                                Text(size)
                                    .font(.system(size: 9))
                                    .foregroundColor(DesignSystem.Colors.textTertiary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                    } else {
                        Text(item.preview)
                            .font(.system(size: 10))
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
                .frame(height: 52)

                // Footer: Secondary Metadata (size / dimensions / chars)
                HStack {
                    if let dims = item.formattedDimensions {
                        Text(dims)
                            .font(.system(size: 8))
                            .foregroundColor(DesignSystem.Colors.textTertiary)
                    } else if let size = item.formattedFileSize {
                        Text(size)
                            .font(.system(size: 8))
                            .foregroundColor(DesignSystem.Colors.textTertiary)
                    } else if let chars = item.characterCount {
                        Text("\(chars) chars")
                            .font(.system(size: 8))
                            .foregroundColor(DesignSystem.Colors.textTertiary)
                    }

                    Spacer()
                }

                Spacer(minLength: 0)
            }
            .padding(8)
            .frame(width: DesignSystem.Dimensions.cardWidth, height: DesignSystem.Dimensions.cardHeight)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.Dimensions.cardCornerRadius, style: .continuous)
                    .fill(isSelected ? DesignSystem.Colors.cardHoverBackground : (isHovered ? DesignSystem.Colors.cardHoverBackground.opacity(0.5) : DesignSystem.Colors.cardBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.Dimensions.cardCornerRadius, style: .continuous)
                    .stroke(isSelected ? Color.accentColor : (isHovered ? DesignSystem.Colors.activeBorder.opacity(0.4) : DesignSystem.Colors.subtleBorder), lineWidth: isSelected ? 1.5 : 1)
            )
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Copy") {
                handleCopy()
            }

            Button("Copy as Plain Text") {
                onCopyPlainText()
            }

            Button(item.isPinned ? "Unpin" : "Pin") {
                onTogglePin()
            }

            if item.type == .url, let url = item.url {
                Button("Open in Browser") {
                    NSWorkspace.shared.open(url)
                }
            }

            if item.type == .file, let path = item.fileURLString, let url = URL(string: path) {
                Button("Reveal in Finder") {
                    NSWorkspace.shared.selectFile(url.path, inFileViewerRootedAtPath: "")
                }
            }

            Button("Inspect Details...") {
                onInspect()
            }

            Divider()

            Button(role: .destructive, action: onDelete) {
                Text("Delete")
            }
        }
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
