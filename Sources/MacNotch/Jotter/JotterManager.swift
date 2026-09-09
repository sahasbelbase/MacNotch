import Foundation
import AppKit

/// Individual checklist task in the Notch Jotter.
public struct JotterTask: Identifiable, Codable, Equatable, Sendable {
    public let id: String
    public var title: String
    public var isCompleted: Bool
    public let createdAt: Date

    public init(id: String = UUID().uuidString, title: String, isCompleted: Bool = false, createdAt: Date = Date()) {
        self.id = id
        self.title = title
        self.isCompleted = isCompleted
        self.createdAt = createdAt
    }
}

/// Persistent payload for Notch Jotter.
public struct JotterData: Codable, Equatable, Sendable {
    public var noteText: String
    public var tasks: [JotterTask]

    public init(noteText: String = "", tasks: [JotterTask] = []) {
        self.noteText = noteText
        self.tasks = tasks
    }
}

/// Manages instant auto-saving notes and checklist tasks in the Notch.
@MainActor
public final class JotterManager: ObservableObject {
    @Published public var noteText: String = "" {
        didSet { scheduleAutoSave() }
    }
    @Published public private(set) var tasks: [JotterTask] = []

    private let storageURL: URL
    private var autoSaveTask: Task<Void, Never>?

    public init(customStorageURL: URL? = nil) {
        if let custom = customStorageURL {
            self.storageURL = custom
        } else {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            let dir = appSupport.appendingPathComponent("MacNotch", isDirectory: true)
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            self.storageURL = dir.appendingPathComponent("jotter.json")
        }

        loadData()
    }

    private func loadData() {
        guard FileManager.default.fileExists(atPath: storageURL.path),
              let data = try? Data(contentsOf: storageURL),
              let decoded = try? JSONDecoder().decode(JotterData.self, from: data) else {
            return
        }
        self.noteText = decoded.noteText
        self.tasks = decoded.tasks
    }

    public func saveImmediately() {
        let payload = JotterData(noteText: noteText, tasks: tasks)
        if let encoded = try? JSONEncoder().encode(payload) {
            try? encoded.write(to: storageURL, options: .atomic)
        }
    }

    private func scheduleAutoSave() {
        autoSaveTask?.cancel()
        autoSaveTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s debounce
            if !Task.isCancelled {
                self?.saveImmediately()
            }
        }
    }

    // MARK: - Task Mutations

    public func addTask(_ title: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        tasks.insert(JotterTask(title: trimmed), at: 0)
        saveImmediately()
    }

    public func toggleTask(id: String) {
        if let index = tasks.firstIndex(where: { $0.id == id }) {
            tasks[index].isCompleted.toggle()
            saveImmediately()
        }
    }

    public func deleteTask(id: String) {
        tasks.removeAll { $0.id == id }
        saveImmediately()
    }

    public func clearCompleted() {
        tasks.removeAll { $0.isCompleted }
        saveImmediately()
    }

    public func clearAllNotes() {
        noteText = ""
        saveImmediately()
    }

    public func copyAllToClipboard() {
        var content = ""
        if !noteText.isEmpty {
            content += "## Notes\n\(noteText)\n\n"
        }
        if !tasks.isEmpty {
            content += "## Checklist\n"
            for task in tasks {
                content += "- [\(task.isCompleted ? "x" : " ")] \(task.title)\n"
            }
        }

        guard !content.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(content.trimmingCharacters(in: .whitespacesAndNewlines), forType: .string)
    }
}
