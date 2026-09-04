import Foundation
import AppKit

/// Supported clipboard content classifications.
public enum ClipboardContentType: String, Codable, CaseIterable, Sendable {
    case text
    case url
    case code
    case image
    case file

    public var iconName: String {
        switch self {
        case .text: return "text.alignleft"
        case .url: return "link"
        case .code: return "chevron.left.forwardslash.chevron.right"
        case .image: return "photo"
        case .file: return "doc"
        }
    }

    public var title: String {
        switch self {
        case .text: return "Text"
        case .url: return "Link"
        case .code: return "Code"
        case .image: return "Image"
        case .file: return "File"
        }
    }
}

/// Represents an item recorded in clipboard history.
public struct ClipboardItem: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let timestamp: Date
    public let type: ClipboardContentType
    public let preview: String
    public let textContent: String?
    public let imagePath: String?
    public let fileURLString: String?
    public let isSensitive: Bool
    public let characterCount: Int?
    public var isPinned: Bool
    public let fileSize: Int64?
    public let imageDimensions: CGSize?

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        type: ClipboardContentType,
        preview: String,
        textContent: String? = nil,
        imagePath: String? = nil,
        fileURLString: String? = nil,
        isSensitive: Bool = false,
        characterCount: Int? = nil,
        isPinned: Bool = false,
        fileSize: Int64? = nil,
        imageDimensions: CGSize? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.type = type
        self.preview = preview
        self.textContent = textContent
        self.imagePath = imagePath
        self.fileURLString = fileURLString
        self.isSensitive = isSensitive
        self.characterCount = characterCount ?? textContent?.count
        self.isPinned = isPinned
        self.fileSize = fileSize
        self.imageDimensions = imageDimensions
    }

    // MARK: - Backward-Compatible Decoding

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        self.timestamp = try container.decodeIfPresent(Date.self, forKey: .timestamp) ?? Date()
        self.type = try container.decodeIfPresent(ClipboardContentType.self, forKey: .type) ?? .text
        self.preview = try container.decodeIfPresent(String.self, forKey: .preview) ?? ""
        self.textContent = try container.decodeIfPresent(String.self, forKey: .textContent)
        self.imagePath = try container.decodeIfPresent(String.self, forKey: .imagePath)
        self.fileURLString = try container.decodeIfPresent(String.self, forKey: .fileURLString)
        self.isSensitive = try container.decodeIfPresent(Bool.self, forKey: .isSensitive) ?? false
        self.characterCount = try container.decodeIfPresent(Int.self, forKey: .characterCount) ?? textContent?.count
        self.isPinned = try container.decodeIfPresent(Bool.self, forKey: .isPinned) ?? false
        self.fileSize = try container.decodeIfPresent(Int64.self, forKey: .fileSize)
        self.imageDimensions = try container.decodeIfPresent(CGSize.self, forKey: .imageDimensions)
    }

    private enum CodingKeys: String, CodingKey {
        case id, timestamp, type, preview, textContent, imagePath, fileURLString, isSensitive, characterCount, isPinned, fileSize, imageDimensions
    }

    // MARK: - Formatted Metadata

    /// Formatted relative timestamp (e.g. "2m ago", "1h ago").
    public var formattedTime: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: timestamp, relativeTo: Date())
    }

    /// Exact formatted date & time.
    public var formattedFullDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: timestamp)
    }

    /// URL representation if applicable.
    public var url: URL? {
        guard type == .url, let str = textContent ?? fileURLString else { return nil }
        return URL(string: str)
    }

    /// Extracted host domain for URL items (e.g. "github.com").
    public var domainHost: String? {
        url?.host
    }

    /// Formatted human-readable file size if available.
    public var formattedFileSize: String? {
        guard let size = fileSize else { return nil }
        return ClipboardPreviewProvider.shared.formatByteCount(size)
    }

    /// Formatted dimensions for images (e.g. "1920 × 1080").
    public var formattedDimensions: String? {
        guard let dims = imageDimensions else { return nil }
        return "\(Int(dims.width)) × \(Int(dims.height))"
    }

    /// Number of lines in text/code content.
    public var lineCount: Int {
        guard let text = textContent else { return 1 }
        return text.components(separatedBy: .newlines).count
    }

    /// Word count in text content.
    public var wordCount: Int {
        guard let text = textContent else { return 0 }
        return text.split { $0.isWhitespace || $0.isNewline }.count
    }
}
