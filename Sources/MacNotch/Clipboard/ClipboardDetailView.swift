import SwiftUI
import AppKit

/// Expanded inspector modal displaying full content, metadata, and actions for a clipboard record.
public struct ClipboardDetailView: View {
    public let item: ClipboardItem
    public let onCopy: () -> Void
    public let onCopyPlainText: () -> Void
    public let onTogglePin: () -> Void
    public let onDelete: () -> Void
    public let onClose: () -> Void

    @State private var showCopiedBadge: Bool = false

    public init(
        item: ClipboardItem,
        onCopy: @escaping () -> Void,
        onCopyPlainText: @escaping () -> Void,
        onTogglePin: @escaping () -> Void,
        onDelete: @escaping () -> Void,
        onClose: @escaping () -> Void
    ) {
        self.item = item
        self.onCopy = onCopy
        self.onCopyPlainText = onCopyPlainText
        self.onTogglePin = onTogglePin
        self.onDelete = onDelete
        self.onClose = onClose
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header: Type, Pin, Date, Close
            HStack(spacing: 8) {
                Image(systemName: item.type.iconName)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.accentColor)

                Text(item.type.title)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(DesignSystem.Colors.textPrimary)

                if item.isPinned {
                    HStack(spacing: 3) {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 9))
                        Text("Pinned")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundColor(.orange)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.orange.opacity(0.15))
                    .clipShape(Capsule())
                }

                Spacer()

                Text(item.formattedFullDate)
                    .font(.system(size: 11))
                    .foregroundColor(DesignSystem.Colors.textSecondary)

                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(DesignSystem.Colors.textTertiary)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.escape, modifiers: [])
            }

            Divider()
                .background(DesignSystem.Colors.subtleBorder)

            // Content Area
            contentBody
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()
                .background(DesignSystem.Colors.subtleBorder)

            // Footer: Metadata & Actions
            HStack {
                // Metadata chips
                HStack(spacing: 8) {
                    if let chars = item.characterCount {
                        Text("\(chars) chars")
                            .font(.system(size: 10))
                            .foregroundColor(DesignSystem.Colors.textTertiary)
                    }
                    if item.type == .code || item.type == .text {
                        Text("\(item.lineCount) lines")
                            .font(.system(size: 10))
                            .foregroundColor(DesignSystem.Colors.textTertiary)
                    }
                    if let size = item.formattedFileSize {
                        Text(size)
                            .font(.system(size: 10))
                            .foregroundColor(DesignSystem.Colors.textTertiary)
                    }
                    if let dims = item.formattedDimensions {
                        Text(dims)
                            .font(.system(size: 10))
                            .foregroundColor(DesignSystem.Colors.textTertiary)
                    }
                }

                Spacer()

                // Actions
                HStack(spacing: 8) {
                    Button(action: onTogglePin) {
                        Image(systemName: item.isPinned ? "pin.slash" : "pin")
                            .font(.system(size: 11))
                    }
                    .buttonStyle(.plain)
                    .help(item.isPinned ? "Unpin item" : "Pin item")

                    if item.type == .url, let url = item.url {
                        Button(action: {
                            NSWorkspace.shared.open(url)
                        }) {
                            Image(systemName: "safari")
                                .font(.system(size: 11))
                        }
                        .buttonStyle(.plain)
                        .help("Open URL in Browser")
                    }

                    if item.type == .file, let path = item.fileURLString, let url = URL(string: path) {
                        Button(action: {
                            NSWorkspace.shared.selectFile(url.path, inFileViewerRootedAtPath: "")
                        }) {
                            Image(systemName: "folder")
                                .font(.system(size: 11))
                        }
                        .buttonStyle(.plain)
                        .help("Reveal in Finder")
                    }

                    Button(action: {
                        onDelete()
                        onClose()
                    }) {
                        Image(systemName: "trash")
                            .font(.system(size: 11))
                            .foregroundColor(.red)
                    }
                    .buttonStyle(.plain)
                    .help("Delete item")

                    Button(action: handleCopy) {
                        HStack(spacing: 4) {
                            Image(systemName: showCopiedBadge ? "checkmark" : "doc.on.clipboard")
                            Text(showCopiedBadge ? "Copied" : "Copy")
                        }
                        .font(.system(size: 11, weight: .semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.Dimensions.cornerRadius, style: .continuous)
                .fill(Color(nsColor: .windowBackgroundColor).opacity(0.95))
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.Dimensions.cornerRadius, style: .continuous)
                        .stroke(DesignSystem.Colors.subtleBorder, lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.5), radius: 25, x: 0, y: 12)
        )
    }

    @ViewBuilder
    private var contentBody: some View {
        switch item.type {
        case .image:
            if let path = item.imagePath, let image = NSImage(contentsOfFile: imagePathURL(path).path) {
                ScrollView([.horizontal, .vertical]) {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .cornerRadius(8)
                }
            } else {
                Text("Image unavailable")
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }

        case .code:
            ScrollView([.horizontal, .vertical]) {
                Text(item.textContent ?? item.preview)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .padding(4)
            }

        case .url:
            VStack(alignment: .leading, spacing: 8) {
                if let host = item.domainHost {
                    HStack(spacing: 4) {
                        Image(systemName: "globe")
                            .font(.system(size: 11))
                        Text(host)
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundColor(.accentColor)
                }
                ScrollView(.vertical) {
                    Text(item.textContent ?? item.preview)
                        .font(.system(size: 12))
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                }
            }

        case .file:
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Image(systemName: "doc.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.accentColor)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.preview)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                        if let path = item.fileURLString {
                            Text(path)
                                .font(.system(size: 10))
                                .foregroundColor(DesignSystem.Colors.textTertiary)
                                .lineLimit(2)
                        }
                    }
                }
                .padding(8)
                .macNotchCardStyle()
                Spacer()
            }

        case .text:
            ScrollView(.vertical) {
                Text(item.textContent ?? item.preview)
                    .font(.system(size: 12))
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .padding(4)
            }
        }
    }

    private func handleCopy() {
        onCopy()
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .default)
        withAnimation { showCopiedBadge = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation { showCopiedBadge = false }
        }
    }

    private func imagePathURL(_ filename: String) -> URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("MacNotch/images/\(filename)")
    }
}
