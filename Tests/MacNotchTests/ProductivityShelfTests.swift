import XCTest
@testable import MacNotch
import AppKit

@MainActor
final class ProductivityShelfTests: XCTestCase {
    func testFileShelfItemCreation() {
        let tempURL = URL(fileURLWithPath: "/tmp/sample_image.png")
        let item = FileShelfItem(url: tempURL)

        XCTAssertEqual(item.name, "sample_image.png")
        XCTAssertTrue(item.isImage)
        XCTAssertFalse(item.fileSizeFormatted.isEmpty)
    }

    func testFileShelfManagerAddRemoveClear() {
        let manager = FileShelfManager()
        XCTAssertEqual(manager.items.count, 0)

        let file1 = URL(fileURLWithPath: "/tmp/file1.pdf")
        let file2 = URL(fileURLWithPath: "/tmp/file2.txt")

        manager.addFiles([file1, file2])
        XCTAssertEqual(manager.items.count, 2)

        // Deduplication: adding file1 again should not duplicate
        manager.addFiles([file1])
        XCTAssertEqual(manager.items.count, 2)

        // Remove item
        let firstId = manager.items[0].id
        manager.removeItem(id: firstId)
        XCTAssertEqual(manager.items.count, 1)

        // Clear all
        manager.clearAll()
        XCTAssertEqual(manager.items.count, 0)
    }

    func testJotterManagerMutationsAndPersistence() {
        let tempDir = FileManager.default.temporaryDirectory
        let customURL = tempDir.appendingPathComponent("test_jotter_\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: customURL) }

        let manager = JotterManager(customStorageURL: customURL)
        manager.noteText = "Meeting notes with Sarah"
        manager.addTask("Review PR #42")
        manager.addTask("Push release build")

        XCTAssertEqual(manager.tasks.count, 2)
        XCTAssertEqual(manager.tasks[0].title, "Push release build")
        XCTAssertFalse(manager.tasks[0].isCompleted)

        // Toggle task
        let taskId = manager.tasks[0].id
        manager.toggleTask(id: taskId)
        XCTAssertTrue(manager.tasks[0].isCompleted)

        // Clear completed
        manager.clearCompleted()
        XCTAssertEqual(manager.tasks.count, 1)
        XCTAssertEqual(manager.tasks[0].title, "Review PR #42")

        // Reload manager from disk to verify atomic JSON persistence
        let reloadedManager = JotterManager(customStorageURL: customURL)
        XCTAssertEqual(reloadedManager.noteText, "Meeting notes with Sarah")
        XCTAssertEqual(reloadedManager.tasks.count, 1)
        XCTAssertEqual(reloadedManager.tasks[0].title, "Review PR #42")
    }

    func testNotchTabCases() {
        XCTAssertEqual(NotchTab.overview.rawValue, "Overview")
        XCTAssertEqual(NotchTab.clipboard.rawValue, "Clipboard")
        XCTAssertEqual(NotchTab.shelf.rawValue, "Shelf")
        XCTAssertEqual(NotchTab.jotter.rawValue, "Jotter")
        XCTAssertEqual(NotchTab.calendar.rawValue, "Calendar")
        XCTAssertEqual(NotchTab.weather.rawValue, "Weather")
    }
}
