import Foundation
import AppKit

/// Retention limit options for clipboard history.
public enum RetentionLimit: Int, CaseIterable, Identifiable, Codable, Sendable {
    case fifty = 50
    case hundred = 100
    case fiveHundred = 500
    case unlimited = 0

    public var id: Int { rawValue }

    public var description: String {
        switch self {
        case .fifty: return "50 items"
        case .hundred: return "100 items"
        case .fiveHundred: return "500 items"
        case .unlimited: return "Unlimited"
        }
    }
}

/// Auto-deletion period options.
public enum AutoDeletePeriod: String, CaseIterable, Identifiable, Codable, Sendable {
    case never = "Never"
    case twentyFourHours = "24 Hours"
    case sevenDays = "7 Days"
    case thirtyDays = "30 Days"

    public var id: String { rawValue }

    public var timeInterval: TimeInterval? {
        switch self {
        case .never: return nil
        case .twentyFourHours: return 86400
        case .sevenDays: return 86400 * 7
        case .thirtyDays: return 86400 * 30
        }
    }
}

/// Handles local-only persistence of clipboard history and associated image assets.
public final class ClipboardStore: @unchecked Sendable {
    private let fileManager = FileManager.default
    private let storageDirectory: URL
    private let historyFileURL: URL
    private let imagesDirectoryURL: URL
    private let queue = DispatchQueue(label: "com.macnotch.clipboardstore", qos: .utility)

    public init(storageDirectory: URL? = nil) {
        if let dir = storageDirectory {
            self.storageDirectory = dir
        } else {
            let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            self.storageDirectory = appSupport.appendingPathComponent("MacNotch", isDirectory: true)
        }

        self.historyFileURL = self.storageDirectory.appendingPathComponent("clipboard_history.json")
        self.imagesDirectoryURL = self.storageDirectory.appendingPathComponent("images", isDirectory: true)

        createDirectoriesIfNeeded()
    }

    private func createDirectoriesIfNeeded() {
        try? fileManager.createDirectory(at: storageDirectory, withIntermediateDirectories: true)
        try? fileManager.createDirectory(at: imagesDirectoryURL, withIntermediateDirectories: true)
    }

    /// Loads history from disk, applying expiration filters.
    public func loadHistory(autoDeletePeriod: AutoDeletePeriod = .never) -> [ClipboardItem] {
        guard fileManager.fileExists(atPath: historyFileURL.path) else {
            return []
        }

        do {
            let data = try Data(contentsOf: historyFileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            var items = try decoder.decode([ClipboardItem].self, from: data)

            // Apply auto-delete filter
            if let maxAge = autoDeletePeriod.timeInterval {
                let cutoff = Date().addingTimeInterval(-maxAge)
                items = items.filter { $0.timestamp >= cutoff }
            }

            return items
        } catch {
            print("Failed to load clipboard history: \(error)")
            return []
        }
    }

    /// Saves history to disk, respecting retention limit.
    public func saveHistory(_ items: [ClipboardItem], limit: RetentionLimit = .hundred) {
        queue.async { [weak self] in
            guard let self = self else { return }
            self.saveHistoryDirect(items, limit: limit)
        }
    }

    /// Saves history synchronously. Useful for testing and termination.
    public func saveHistorySync(_ items: [ClipboardItem], limit: RetentionLimit = .hundred) {
        queue.sync {
            self.saveHistoryDirect(items, limit: limit)
        }
    }

    private func saveHistoryDirect(_ items: [ClipboardItem], limit: RetentionLimit) {
        createDirectoriesIfNeeded()
        var constrainedItems = items
        if limit != .unlimited && constrainedItems.count > limit.rawValue {
            constrainedItems = Array(constrainedItems.prefix(limit.rawValue))
        }

        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(constrainedItems)
            try data.write(to: self.historyFileURL, options: .atomic)
        } catch {
            print("Failed to save clipboard history: \(error)")
        }
    }

    /// Flushes any pending background operations on the store queue.
    public func flushQueue() {
        queue.sync {}
    }

    /// Saves image data and returns relative image filename.
    public func saveImage(data: Data, id: UUID) -> String? {
        let filename = "\(id.uuidString).png"
        let fileURL = imagesDirectoryURL.appendingPathComponent(filename)
        do {
            try data.write(to: fileURL, options: .atomic)
            return filename
        } catch {
            print("Failed to save image: \(error)")
            return nil
        }
    }

    /// Retrieves image from local storage.
    public func loadImage(filename: String) -> NSImage? {
        let fileURL = imagesDirectoryURL.appendingPathComponent(filename)
        return NSImage(contentsOf: fileURL)
    }

    /// Clears all stored items and image files.
    public func clearAll() {
        queue.async { [weak self] in
            guard let self = self else { return }
            try? self.fileManager.removeItem(at: self.historyFileURL)
            try? self.fileManager.removeItem(at: self.imagesDirectoryURL)
            self.createDirectoriesIfNeeded()
        }
    }
}
