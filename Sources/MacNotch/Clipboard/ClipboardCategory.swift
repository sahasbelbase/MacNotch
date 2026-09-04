import Foundation

/// Filtering categories for the clipboard interface.
public enum ClipboardCategory: String, CaseIterable, Identifiable, Codable, Sendable {
    case all = "All"
    case text = "Text"
    case links = "Links"
    case images = "Images"
    case code = "Code"
    case files = "Files"

    public var id: String { rawValue }

    public var iconName: String {
        switch self {
        case .all: return "square.grid.2x2"
        case .text: return "text.alignleft"
        case .links: return "link"
        case .images: return "photo"
        case .code: return "chevron.left.forwardslash.chevron.right"
        case .files: return "doc"
        }
    }

    /// Determines if a clipboard item belongs to this category.
    public func matches(item: ClipboardItem) -> Bool {
        switch self {
        case .all:
            return true
        case .text:
            return item.type == .text
        case .links:
            return item.type == .url
        case .images:
            return item.type == .image
        case .code:
            return item.type == .code
        case .files:
            return item.type == .file
        }
    }
}
