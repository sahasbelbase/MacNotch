import AppKit
import Foundation
import SwiftUI
import UniformTypeIdentifiers

/// Represents a file staged in the Notch File Shelf.
public struct FileShelfItem: Identifiable, Equatable, Sendable {
    public let id: String
    public let url: URL
    public let name: String
    public let fileSizeFormatted: String
    public let dateAdded: Date
    public let isImage: Bool

    public init(id: String = UUID().uuidString, url: URL, dateAdded: Date = Date()) {
        self.id = id
        self.url = url
        self.name = url.lastPathComponent
        self.dateAdded = dateAdded

        // File size calculation
        if let resources = try? url.resourceValues(forKeys: [.fileSizeKey]),
           let size = resources.fileSize {
            let bcf = ByteCountFormatter()
            bcf.allowedUnits = [.useAll]
            bcf.countStyle = .file
            self.fileSizeFormatted = bcf.string(fromByteCount: Int64(size))
        } else {
            self.fileSizeFormatted = "--"
        }

        let ext = url.pathExtension.lowercased()
        self.isImage = ["png", "jpg", "jpeg", "webp", "gif", "heic", "tiff", "svg"].contains(ext)
    }

    public var thumbnailImage: NSImage? {
        if isImage, FileManager.default.fileExists(atPath: url.path) {
            return NSImage(contentsOf: url)
        }
        return NSWorkspace.shared.icon(forFile: url.path)
    }
}

/// Manages files temporarily staged in the Notch shelf for easy cross-app drag-and-drop.
@MainActor
public final class FileShelfManager: ObservableObject {
    @Published public private(set) var items: [FileShelfItem] = []

    public init() {}

    /// Adds one or more file URLs to the shelf.
    public func addFiles(_ urls: [URL]) {
        for url in urls {
            // Deduplicate by path
            if !items.contains(where: { $0.url.standardizedFileURL == url.standardizedFileURL }) {
                items.insert(FileShelfItem(url: url), at: 0)
            }
        }
    }

    /// Removes an item by identifier.
    public func removeItem(id: String) {
        items.removeAll { $0.id == id }
    }

    /// Clears all items from the shelf.
    public func clearAll() {
        items.removeAll()
    }

    /// Reveals the file in Finder.
    public func revealInFinder(item: FileShelfItem) {
        NSWorkspace.shared.activateFileViewerSelecting([item.url])
    }

    /// Shares the file using native AirDrop.
    public func airDrop(item: FileShelfItem) {
        AirDropService.share(urls: [item.url])
    }

    /// Copies the file's POSIX path to the system clipboard.
    public func copyPath(item: FileShelfItem) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(item.url.path, forType: .string)
    }
}
