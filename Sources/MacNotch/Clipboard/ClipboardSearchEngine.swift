import Foundation

/// High-performance local search engine for filtering clipboard history by category and query.
public final class ClipboardSearchEngine: Sendable {
    public static let shared = ClipboardSearchEngine()

    public init() {}

    /// Filters and sorts items based on active category and search query.
    /// Pinned items always appear before unpinned items within matching results.
    public func search(
        items: [ClipboardItem],
        category: ClipboardCategory = .all,
        query: String = ""
    ) -> [ClipboardItem] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        let filtered = items.filter { item in
            // Category check
            guard category.matches(item: item) else {
                return false
            }

            // Query check
            guard !trimmedQuery.isEmpty else {
                return true
            }

            return matches(item: item, query: trimmedQuery)
        }

        // Sort: pinned first, then newest timestamp
        return filtered.sorted { a, b in
            if a.isPinned != b.isPinned {
                return a.isPinned && !b.isPinned
            }
            return a.timestamp > b.timestamp
        }
    }

    /// Evaluates whether an item matches the query.
    public func matches(item: ClipboardItem, query: String) -> Bool {
        // Match text content
        if let text = item.textContent?.lowercased(), text.contains(query) {
            return true
        }

        // Match preview
        if item.preview.lowercased().contains(query) {
            return true
        }

        // Match domain host or URL
        if let host = item.domainHost?.lowercased(), host.contains(query) {
            return true
        }
        if let urlStr = item.url?.absoluteString.lowercased(), urlStr.contains(query) {
            return true
        }

        // Match file name or path
        if let fileStr = item.fileURLString?.lowercased(), fileStr.contains(query) {
            return true
        }

        return false
    }
}
