import SwiftUI
import AppKit

/// View displaying staged files in a horizontal glassmorphic carousel.
/// Files can be dragged out into any external application (Slack, Mail, Safari, Finder).
public struct FileShelfView: View {
    @ObservedObject var shelfManager: FileShelfManager
    @State private var hoveredItemId: String? = nil

    public init(shelfManager: FileShelfManager) {
        self.shelfManager = shelfManager
    }

    public var body: some View {
        VStack(spacing: 8) {
            // Header Bar
            HStack {
                HStack(spacing: 5) {
                    Image(systemName: "tray.and.arrow.down.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.cyan)
                    Text("File Shelf (\(shelfManager.items.count))")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                }

                Spacer()

                if !shelfManager.items.isEmpty {
                    Button(action: {
                        withAnimation(DesignSystem.Animation.collapseSpring) {
                            shelfManager.clearAll()
                        }
                    }) {
                        HStack(spacing: 3) {
                            Image(systemName: "trash")
                                .font(.system(size: 10))
                            Text("Clear Shelf")
                                .font(.system(size: 10, weight: .medium))
                        }
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.white.opacity(0.06))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .help("Clear all files from shelf")
                }
            }
            .padding(.horizontal, 8)

            if shelfManager.items.isEmpty {
                emptyShelfView
            } else {
                itemsScrollView
            }
        }
    }

    // MARK: - Empty State

    private var emptyShelfView: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(Color.cyan.opacity(0.12))
                    .frame(width: 44, height: 44)
                Image(systemName: "arrow.down.doc.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.cyan)
            }

            Text("Drag & Drop Files Here")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(DesignSystem.Colors.textPrimary)

            Text("Drop files from Finder or apps to stage them in the Notch.\nDrag them out into Slack, Safari, or Mail anytime.")
                .font(.system(size: 10))
                .multilineTextAlignment(.center)
                .foregroundColor(DesignSystem.Colors.textSecondary)
                .frame(maxWidth: 320)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 16)
    }

    // MARK: - Shelf Items Scroll View

    private var itemsScrollView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 10) {
                ForEach(shelfManager.items) { item in
                    shelfItemCard(item)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
        }
    }

    // MARK: - Individual File Card

    private func shelfItemCard(_ item: FileShelfItem) -> some View {
        let isHovered = hoveredItemId == item.id

        return VStack(alignment: .leading, spacing: 6) {
            // Top Preview Thumbnail
            ZStack(alignment: .topTrailing) {
                Group {
                    if let image = item.thumbnailImage {
                        Image(nsImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 110, height: 68)
                            .clipped()
                            .cornerRadius(8)
                    } else {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.white.opacity(0.05))
                            .frame(width: 110, height: 68)
                            .overlay(
                                Image(systemName: "doc.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(.white.opacity(0.5))
                            )
                    }
                }

                // Delete button
                if isHovered {
                    Button(action: {
                        withAnimation(DesignSystem.Animation.collapseSpring) {
                            shelfManager.removeItem(id: item.id)
                        }
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.9))
                            .background(Circle().fill(Color.black.opacity(0.6)))
                    }
                    .buttonStyle(.plain)
                    .padding(4)
                }
            }

            // File Name and Size
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Text(item.fileSizeFormatted)
                    .font(.system(size: 9))
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }
            .frame(width: 110, alignment: .leading)

            // Bottom Quick Action Buttons
            HStack(spacing: 4) {
                Button(action: {
                    shelfManager.airDrop(item: item)
                }) {
                    Image(systemName: "airdrop")
                        .font(.system(size: 10))
                        .frame(width: 22, height: 18)
                        .background(Color.white.opacity(0.08))
                        .cornerRadius(4)
                }
                .buttonStyle(.plain)
                .help("AirDrop file")

                Button(action: {
                    shelfManager.revealInFinder(item: item)
                }) {
                    Image(systemName: "folder.fill")
                        .font(.system(size: 10))
                        .frame(width: 22, height: 18)
                        .background(Color.white.opacity(0.08))
                        .cornerRadius(4)
                }
                .buttonStyle(.plain)
                .help("Reveal in Finder")

                Button(action: {
                    shelfManager.copyPath(item: item)
                }) {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 10))
                        .frame(width: 22, height: 18)
                        .background(Color.white.opacity(0.08))
                        .cornerRadius(4)
                }
                .buttonStyle(.plain)
                .help("Copy POSIX Path")
            }
            .foregroundColor(.white.opacity(0.75))
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(isHovered ? 0.7 : 0.45))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isHovered ? Color.cyan.opacity(0.6) : DesignSystem.Colors.subtleBorder, lineWidth: 1)
                )
        )
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .onHover { isHov in
            withAnimation(.easeOut(duration: 0.12)) {
                hoveredItemId = isHov ? item.id : nil
            }
        }
        // Native Drag-Out: Allows dragging the staged file into other apps!
        .onDrag {
            NSItemProvider(object: item.url as NSURL)
        }
    }
}
