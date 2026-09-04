import XCTest
@testable import MacNotch

@MainActor
final class ClipboardManagerTests: XCTestCase {
    var tempDirectory: URL!
    var store: ClipboardStore!
    var manager: ClipboardManager!

    override func setUp() async throws {
        try await super.setUp()
        tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        store = ClipboardStore(storageDirectory: tempDirectory)
        manager = ClipboardManager(store: store)
        manager.stopMonitoring() // Avoid polling during unit test
    }

    override func tearDown() async throws {
        store.flushQueue()
        try? FileManager.default.removeItem(at: tempDirectory)
        try await super.tearDown()
    }

    func testClassification() {
        XCTAssertEqual(manager.classify(string: "Hello, world!"), .text)
        XCTAssertEqual(manager.classify(string: "https://github.com/sahasbelbase/MacNotch"), .url)
        XCTAssertEqual(manager.classify(string: "func computeSum(a: Int, b: Int) -> Int {\n    return a + b\n}"), .code)
    }

    func testSensitiveDataDetection() {
        XCTAssertTrue(manager.detectSensitiveContent("sk-proj-1234567890abcdef"))
        XCTAssertTrue(manager.detectSensitiveContent("ghp_1234567890abcdefghijklmnop"))
        XCTAssertTrue(manager.detectSensitiveContent("-----BEGIN RSA PRIVATE KEY-----\nMIIE..."))
        XCTAssertFalse(manager.detectSensitiveContent("Just an ordinary shopping list: milk, bread, eggs"))
    }

    func testConsecutiveDuplicatePrevention() {
        let item1 = ClipboardItem(type: .text, preview: "Test note", textContent: "Test note")
        let item2 = ClipboardItem(type: .text, preview: "Test note", textContent: "Test note")
        let item3 = ClipboardItem(type: .text, preview: "Different note", textContent: "Different note")

        manager.add(item: item1)
        XCTAssertEqual(manager.items.count, 1)

        manager.add(item: item2) // Duplicate, should not add
        XCTAssertEqual(manager.items.count, 1)

        manager.add(item: item3) // Different, should add
        XCTAssertEqual(manager.items.count, 2)
    }

    func testRetentionLimit() {
        manager.retentionLimit = .fifty

        for i in 0..<60 {
            let item = ClipboardItem(type: .text, preview: "Item \(i)", textContent: "Item \(i)")
            manager.add(item: item)
        }

        XCTAssertEqual(manager.items.count, 50)
    }

    func testClearHistory() {
        manager.add(item: ClipboardItem(type: .text, preview: "Sample", textContent: "Sample"))
        XCTAssertFalse(manager.items.isEmpty)

        manager.clearHistory()
        XCTAssertTrue(manager.items.isEmpty)
    }
}
