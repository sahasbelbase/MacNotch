import Foundation
import CoreGraphics

/// Generates intelligent, content-aware previews for clipboard items without altering original data.
public final class ClipboardPreviewProvider: Sendable {
    public static let shared = ClipboardPreviewProvider()

    public init() {}

    /// Formats an intelligent preview string for a given text and content type.
    public func generatePreview(for text: String, type: ClipboardContentType) -> String {
        switch type {
        case .url:
            return formatURLPreview(text)
        case .code:
            return formatCodePreview(text)
        case .text:
            if isJSON(text) {
                return formatJSONPreview(text)
            }
            return formatTextPreview(text)
        case .file:
            return formatFilePreview(text)
        case .image:
            return "Image"
        }
    }

    // MARK: - Formatters

    private func formatTextPreview(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let lines = trimmed.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        if lines.isEmpty { return "" }

        if lines.count == 1 {
            return truncate(lines[0], maxChars: 120)
        }

        // Combine first two meaningful lines
        let combined = lines.prefix(2).joined(separator: "\n")
        return truncate(combined, maxChars: 120)
    }

    private func formatCodePreview(_ text: String) -> String {
        let lines = text.components(separatedBy: .newlines)
        // Keep non-empty lines with their indentation preserved
        var meaningfulLines: [String] = []
        for line in lines {
            if !line.trimmingCharacters(in: .whitespaces).isEmpty {
                meaningfulLines.append(line)
                if meaningfulLines.count >= 3 { break }
            }
        }
        return meaningfulLines.joined(separator: "\n")
    }

    private func formatURLPreview(_ text: String) -> String {
        guard let url = URL(string: text.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            return text
        }
        if let host = url.host {
            let path = url.path
            if path.isEmpty || path == "/" {
                return host
            }
            return "\(host)\(path)"
        }
        return text
    }

    private func formatFilePreview(_ text: String) -> String {
        if let url = URL(string: text) {
            return url.lastPathComponent
        }
        return (text as NSString).lastPathComponent
    }

    public func isJSON(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (trimmed.hasPrefix("{") && trimmed.hasSuffix("}")) ||
              (trimmed.hasPrefix("[") && trimmed.hasSuffix("]")) else {
            return false
        }
        guard let data = trimmed.data(using: .utf8) else { return false }
        return (try? JSONSerialization.jsonObject(with: data, options: [])) != nil
    }

    private func formatJSONPreview(_ text: String) -> String {
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data, options: []),
              let prettyData = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted]),
              let prettyString = String(data: prettyData, encoding: .utf8) else {
            return formatTextPreview(text)
        }

        let lines = prettyString.components(separatedBy: .newlines).prefix(4)
        return lines.joined(separator: "\n")
    }

    public func formatByteCount(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        formatter.allowedUnits = [.useBytes, .useKB, .useMB, .useGB]
        return formatter.string(fromByteCount: bytes)
    }

    private func truncate(_ string: String, maxChars: Int) -> String {
        if string.count <= maxChars {
            return string
        }
        return String(string.prefix(maxChars)) + "…"
    }
}
