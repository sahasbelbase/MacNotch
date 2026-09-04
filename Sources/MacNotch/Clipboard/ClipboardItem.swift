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

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        type: ClipboardContentType,
        preview: String,
        textContent: String? = nil,
        imagePath: String? = nil,
        fileURLString: String? = nil,
        isSensitive: Bool = false,
        characterCount: Int? = nil
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
    }

    /// Formatted relative timestamp (e.g. "2m ago", "1h ago").
    public var formattedTime: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: timestamp, relativeTo: Date())
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
}
