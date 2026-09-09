import XCTest
@testable import MacNotch
import CoreGraphics

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
        manager.stopMonitoring() // Avoid polling during unit tests
    }

    override func tearDown() async throws {
        store.flushQueue()
        try? FileManager.default.removeItem(at: tempDirectory)
        try await super.tearDown()
    }

    // MARK: - 1. Classification
    func testClassification() {
        XCTAssertEqual(manager.classify(string: "Hello, world!"), .text)
        XCTAssertEqual(manager.classify(string: "https://github.com/sahasbelbase/MacNotch"), .url)
        XCTAssertEqual(manager.classify(string: "func computeSum(a: Int, b: Int) -> Int {\n    return a + b\n}"), .code)
    }

    // MARK: - 2. Sensitive Data Heuristics
    func testSensitiveDataDetection() {
        XCTAssertTrue(manager.detectSensitiveContent("sk-proj-1234567890abcdef"))
        XCTAssertTrue(manager.detectSensitiveContent("sk-ant-1234567890abcdef"))
        XCTAssertTrue(manager.detectSensitiveContent("ghp_1234567890abcdefghijklmnop"))
        XCTAssertTrue(manager.detectSensitiveContent("-----BEGIN RSA PRIVATE KEY-----\nMIIE..."))
        XCTAssertTrue(manager.detectSensitiveContent("Bearer abcdef1234567890abcdef1234567890"))
        // Normal code should not be falsely flagged
        XCTAssertFalse(manager.detectSensitiveContent("let bearerTokenName = \"custom_token\""))
        XCTAssertFalse(manager.detectSensitiveContent("Just an ordinary shopping list: milk, bread, eggs"))
    }

    // MARK: - 3. Consecutive Duplicate Prevention
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

    // MARK: - 4. Retention Limits
    func testRetentionLimit() {
        manager.retentionLimit = .fifty

        for i in 0..<60 {
            let item = ClipboardItem(type: .text, preview: "Item \(i)", textContent: "Item \(i)")
            manager.add(item: item)
        }

        XCTAssertEqual(manager.items.count, 50)
    }

    func testEightyItemsRetentionLimit() {
        manager.retentionLimit = .eighty
        XCTAssertEqual(manager.retentionLimit.rawValue, 80)
        XCTAssertTrue(manager.retentionLimit.description.contains("80 items"))

        for i in 0..<100 {
            let item = ClipboardItem(type: .text, preview: "Item \(i)", textContent: "Item \(i)")
            manager.add(item: item)
        }

        XCTAssertEqual(manager.items.count, 80)
    }

    // MARK: - 5. Clear History
    func testClearHistory() {
        manager.add(item: ClipboardItem(type: .text, preview: "Sample", textContent: "Sample"))
        XCTAssertFalse(manager.items.isEmpty)

        manager.clearHistory()
        XCTAssertTrue(manager.items.isEmpty)
    }

    // MARK: - 6. Categories Filtering
    func testCategoryMatching() {
        let textItem = ClipboardItem(type: .text, preview: "A", textContent: "A")
        let urlItem = ClipboardItem(type: .url, preview: "https://apple.com", textContent: "https://apple.com")
        let codeItem = ClipboardItem(type: .code, preview: "func x() {}", textContent: "func x() {}")
        let imgItem = ClipboardItem(type: .image, preview: "Img", imagePath: "img.png")
        let fileItem = ClipboardItem(type: .file, preview: "doc.pdf", fileURLString: "file:///doc.pdf")

        XCTAssertTrue(ClipboardCategory.all.matches(item: textItem))
        XCTAssertTrue(ClipboardCategory.text.matches(item: textItem))
        XCTAssertFalse(ClipboardCategory.text.matches(item: urlItem))

        XCTAssertTrue(ClipboardCategory.links.matches(item: urlItem))
        XCTAssertTrue(ClipboardCategory.code.matches(item: codeItem))
        XCTAssertTrue(ClipboardCategory.images.matches(item: imgItem))
        XCTAssertTrue(ClipboardCategory.files.matches(item: fileItem))
    }

    // MARK: - 7. Search Text Matching
    func testSearchEngineTextMatching() {
        let items = [
            ClipboardItem(type: .text, preview: "Buy grocery groceries", textContent: "Buy groceries today"),
            ClipboardItem(type: .text, preview: "Meeting notes", textContent: "Sprint planning meeting"),
            ClipboardItem(type: .code, preview: "print(hello)", textContent: "print(\"hello\")")
        ]

        let results = ClipboardSearchEngine.shared.search(items: items, category: .all, query: "groceries")
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.preview, "Buy grocery groceries")
    }

    // MARK: - 8. Search URL & Domain Host
    func testSearchEngineURLAndDomainMatching() {
        let items = [
            ClipboardItem(type: .url, preview: "github.com", textContent: "https://github.com/sahasbelbase/MacNotch"),
            ClipboardItem(type: .url, preview: "apple.com", textContent: "https://developer.apple.com/documentation"),
            ClipboardItem(type: .text, preview: "Notes", textContent: "Some text about git")
        ]

        let results = ClipboardSearchEngine.shared.search(items: items, category: .links, query: "github")
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.domainHost, "github.com")
    }

    // MARK: - 9. Search Code Content
    func testSearchEngineCodeMatching() {
        let items = [
            ClipboardItem(type: .code, preview: "fetchUserData", textContent: "func fetchUserData() async throws -> User {\n    return user\n}"),
            ClipboardItem(type: .code, preview: "renderChart", textContent: "func renderChart() {}")
        ]

        let results = ClipboardSearchEngine.shared.search(items: items, category: .code, query: "fetchUserData")
        XCTAssertEqual(results.count, 1)
        XCTAssertTrue(results.first?.textContent?.contains("fetchUserData") == true)
    }

    // MARK: - 10. Search File Path Matching
    func testSearchEngineFilePathMatching() {
        let items = [
            ClipboardItem(type: .file, preview: "archive.zip", fileURLString: "file:///Users/test/Downloads/archive.zip"),
            ClipboardItem(type: .file, preview: "photo.jpg", fileURLString: "file:///Users/test/Desktop/photo.jpg")
        ]

        let results = ClipboardSearchEngine.shared.search(items: items, category: .files, query: "archive")
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.preview, "archive.zip")
    }

    // MARK: - 11. Search Case Insensitive
    func testSearchEngineCaseInsensitive() {
        let items = [
            ClipboardItem(type: .text, preview: "macnotch", textContent: "MACNOTCH UTILITY APP")
        ]

        let results = ClipboardSearchEngine.shared.search(items: items, category: .all, query: "macnotch")
        XCTAssertEqual(results.count, 1)
    }

    // MARK: - 12. Combined Category + Search Query
    func testCombinedCategoryAndSearchQuery() {
        let items = [
            ClipboardItem(type: .code, preview: "fetch", textContent: "func fetch() {}"),
            ClipboardItem(type: .text, preview: "fetch list", textContent: "fetch groceries"),
            ClipboardItem(type: .url, preview: "fetch.com", textContent: "https://fetch.com")
        ]

        let codeResults = ClipboardSearchEngine.shared.search(items: items, category: .code, query: "fetch")
        XCTAssertEqual(codeResults.count, 1)
        XCTAssertEqual(codeResults.first?.type, .code)

        let textResults = ClipboardSearchEngine.shared.search(items: items, category: .text, query: "fetch")
        XCTAssertEqual(textResults.count, 1)
        XCTAssertEqual(textResults.first?.type, .text)
    }

    // MARK: - 13. Pin Item
    func testPinItem() {
        let item = ClipboardItem(type: .text, preview: "Pinnable", textContent: "Pinnable", isPinned: false)
        manager.add(item: item)

        XCTAssertFalse(manager.items.first!.isPinned)

        manager.pin(item: manager.items.first!)
        XCTAssertTrue(manager.items.first!.isPinned)
    }

    // MARK: - 14. Unpin Item
    func testUnpinItem() {
        let item = ClipboardItem(type: .text, preview: "Pinned", textContent: "Pinned", isPinned: true)
        manager.add(item: item)
        XCTAssertTrue(manager.items.first!.isPinned)

        manager.unpin(item: manager.items.first!)
        XCTAssertFalse(manager.items.first!.isPinned)
    }

    // MARK: - 15. Pinned Items Always Sorted First
    func testPinnedItemsAlwaysSortedFirst() {
        let item1 = ClipboardItem(type: .text, preview: "1", textContent: "1", isPinned: false)
        let item2 = ClipboardItem(type: .text, preview: "2", textContent: "2", isPinned: false)
        let item3 = ClipboardItem(type: .text, preview: "3", textContent: "3", isPinned: false)

        manager.add(item: item1)
        manager.add(item: item2)
        manager.add(item: item3)

        // Pin item1 (which was the oldest)
        manager.pin(item: item1)

        XCTAssertEqual(manager.items.first?.textContent, "1")
        XCTAssertTrue(manager.items.first!.isPinned)
    }

    // MARK: - 16. Retention Protects Pinned Items
    func testRetentionProtectsPinnedItems() {
        manager.retentionLimit = .fifty

        // Add 5 pinned items
        for i in 0..<5 {
            let pinned = ClipboardItem(type: .text, preview: "Pinned \(i)", textContent: "Pinned \(i)", isPinned: true)
            manager.add(item: pinned)
        }

        // Add 60 unpinned items
        for i in 0..<60 {
            let unpinned = ClipboardItem(type: .text, preview: "Unpinned \(i)", textContent: "Unpinned \(i)", isPinned: false)
            manager.add(item: unpinned)
        }

        // Pinned count must remain 5
        let pinnedCount = manager.items.filter { $0.isPinned }.count
        XCTAssertEqual(pinnedCount, 5)
        XCTAssertLessThanOrEqual(manager.items.count, 50)
    }

    // MARK: - 17. Expiration Protects Pinned Items
    func testExpirationProtectsPinnedItems() {
        let oldDate = Date().addingTimeInterval(-86400 * 10) // 10 days ago
        let oldPinned = ClipboardItem(timestamp: oldDate, type: .text, preview: "Old Pinned", textContent: "Old Pinned", isPinned: true)
        let oldUnpinned = ClipboardItem(timestamp: oldDate, type: .text, preview: "Old Unpinned", textContent: "Old Unpinned", isPinned: false)

        store.saveHistorySync([oldPinned, oldUnpinned])

        // Load with 24 Hours auto-delete policy
        let loaded = store.loadHistory(autoDeletePeriod: .twentyFourHours)

        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded.first?.preview, "Old Pinned")
        XCTAssertTrue(loaded.first!.isPinned)
    }

    // MARK: - 18. Duplicate Policy Move To Top
    func testDuplicatePolicyMoveToTop() {
        manager.duplicatePolicy = .moveToTop

        let itemA = ClipboardItem(type: .text, preview: "A", textContent: "A")
        let itemB = ClipboardItem(type: .text, preview: "B", textContent: "B")

        manager.add(item: itemA)
        manager.add(item: itemB)

        XCTAssertEqual(manager.items[0].textContent, "B")
        XCTAssertEqual(manager.items[1].textContent, "A")

        // Re-add A (non-consecutive)
        let itemANew = ClipboardItem(type: .text, preview: "A", textContent: "A")
        manager.add(item: itemANew)

        // A should now be at the top, total count remains 2
        XCTAssertEqual(manager.items.count, 2)
        XCTAssertEqual(manager.items[0].textContent, "A")
        XCTAssertEqual(manager.items[1].textContent, "B")
    }

    // MARK: - 19. Duplicate Policy Keep Every
    func testDuplicatePolicyKeepEvery() {
        manager.duplicatePolicy = .keepEvery

        let itemA = ClipboardItem(type: .text, preview: "A", textContent: "A")
        let itemB = ClipboardItem(type: .text, preview: "B", textContent: "B")

        manager.add(item: itemA)
        manager.add(item: itemB)

        let itemANew = ClipboardItem(type: .text, preview: "A", textContent: "A")
        manager.add(item: itemANew)

        // Under keepEvery, non-consecutive duplicate A is kept
        XCTAssertEqual(manager.items.count, 3)
        XCTAssertEqual(manager.items[0].textContent, "A")
        XCTAssertEqual(manager.items[1].textContent, "B")
        XCTAssertEqual(manager.items[2].textContent, "A")
    }

    // MARK: - 20. Pinned State Preserved During Duplicate Bump
    func testDuplicatePolicyPreservesPinnedState() {
        manager.duplicatePolicy = .moveToTop

        let itemA = ClipboardItem(type: .text, preview: "A", textContent: "A", isPinned: true)
        let itemB = ClipboardItem(type: .text, preview: "B", textContent: "B", isPinned: false)

        manager.add(item: itemA)
        manager.add(item: itemB)

        // Re-add A
        let itemACopy = ClipboardItem(type: .text, preview: "A", textContent: "A", isPinned: false)
        manager.add(item: itemACopy)

        XCTAssertEqual(manager.items[0].textContent, "A")
        XCTAssertTrue(manager.items[0].isPinned) // Remains pinned!
    }

    // MARK: - 21. Delete Image File on Item Removal
    func testDeleteImageFileOnItemRemoval() {
        let id = UUID()
        let fakeImageData = "PNGDATA".data(using: .utf8)!
        guard let filename = store.saveImage(data: fakeImageData, id: id) else {
            XCTFail("Could not save image")
            return
        }

        let item = ClipboardItem(id: id, type: .image, preview: "Image", imagePath: filename)
        manager.add(item: item)

        manager.remove(item: item)
        store.flushQueue()

        let loaded = store.loadImage(filename: filename)
        XCTAssertNil(loaded)
    }

    // MARK: - 22. Clean Orphaned Images
    func testCleanOrphanedImages() {
        let fakeImageData = "FAKE".data(using: .utf8)!
        let idActive = UUID()
        let idOrphan = UUID()

        let activeFilename = store.saveImage(data: fakeImageData, id: idActive)!
        let orphanFilename = store.saveImage(data: fakeImageData, id: idOrphan)!

        let activeItem = ClipboardItem(id: idActive, type: .image, preview: "Active", imagePath: activeFilename)

        store.cleanOrphanedImages(activeItems: [activeItem])
        store.flushQueue()

        let imagesDir = tempDirectory.appendingPathComponent("images")
        let orphanURL = imagesDir.appendingPathComponent(orphanFilename)

        // Give file system a moment to complete async deletion
        let expectation = expectation(description: "Orphan cleaned")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let exists = FileManager.default.fileExists(atPath: orphanURL.path)
            XCTAssertFalse(exists)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
    }

    // MARK: - 23. Backward Compatible JSON Decoding
    func testBackwardCompatibleJSONDecoding() throws {
        // Simulates old JSON stored without isPinned or fileSize
        let oldJSON = """
        [
            {
                "id": "11111111-2222-3333-4444-555555555555",
                "timestamp": "2026-09-01T12:00:00Z",
                "type": "text",
                "preview": "Legacy item",
                "textContent": "Legacy item text",
                "isSensitive": false
            }
        ]
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode([ClipboardItem].self, from: oldJSON)

        XCTAssertEqual(decoded.count, 1)
        XCTAssertEqual(decoded.first?.preview, "Legacy item")
        XCTAssertFalse(decoded.first!.isPinned) // Safely defaulted to false
        XCTAssertNil(decoded.first!.fileSize)
    }

    // MARK: - 24. Intelligent Preview JSON Formatting
    func testIntelligentPreviewJSON() {
        let jsonString = "{\"user\":\"User\",\"role\":\"Developer\",\"active\":true}"
        let preview = ClipboardPreviewProvider.shared.generatePreview(for: jsonString, type: .text)

        XCTAssertTrue(preview.contains("{\n"))
        XCTAssertTrue(preview.contains("\"user\""))
    }

    // MARK: - 25. Intelligent Preview Code Formatting
    func testIntelligentPreviewCode() {
        let codeSnippet = "\n\n    func calculate() {\n        let sum = 1 + 1\n    }"
        let preview = ClipboardPreviewProvider.shared.generatePreview(for: codeSnippet, type: .code)

        // Should preserve indentation and omit leading empty lines
        XCTAssertFalse(preview.hasPrefix("\n"))
        XCTAssertTrue(preview.contains("func calculate()"))
    }

    // MARK: - 26. Intelligent Preview URL
    func testIntelligentPreviewURL() {
        let url = "https://github.com/sahasbelbase/MacNotch/releases/tag/v1.0.0"
        let preview = ClipboardPreviewProvider.shared.generatePreview(for: url, type: .url)

        XCTAssertEqual(preview, "github.com/sahasbelbase/MacNotch/releases/tag/v1.0.0")
    }

    // MARK: - 27. Intelligent Preview Long Paragraphs
    func testIntelligentPreviewParagraphs() {
        let paragraph = "First sentence of the note.\nSecond line with details.\nThird line which should be omitted."
        let preview = ClipboardPreviewProvider.shared.generatePreview(for: paragraph, type: .text)

        XCTAssertTrue(preview.contains("First sentence"))
        XCTAssertTrue(preview.contains("Second line"))
        XCTAssertFalse(preview.contains("Third line"))
    }

    // MARK: - 28. Copy Plain Text To Pasteboard
    func testCopyPlainTextToPasteboard() {
        let item = ClipboardItem(type: .code, preview: "let x = 10", textContent: "let x = 10")
        manager.copyPlainTextToPasteboard(item)

        let pasted = NSPasteboard.general.string(forType: .string)
        XCTAssertEqual(pasted, "let x = 10")
    }

    // MARK: - 29. Filtered Items Dynamically Updates
    func testFilteredItemsUpdatesDynamically() {
        let item1 = ClipboardItem(type: .text, preview: "Apple", textContent: "Apple")
        let item2 = ClipboardItem(type: .text, preview: "Banana", textContent: "Banana")
        let item3 = ClipboardItem(type: .code, preview: "Swift code", textContent: "let x = 1")

        manager.add(item: item1)
        manager.add(item: item2)
        manager.add(item: item3)

        XCTAssertEqual(manager.filteredItems.count, 3)

        manager.selectedCategory = .code
        XCTAssertEqual(manager.filteredItems.count, 1)

        manager.selectedCategory = .all
        manager.searchQuery = "Banana"
        XCTAssertEqual(manager.filteredItems.count, 1)
        XCTAssertEqual(manager.filteredItems.first?.preview, "Banana")
    }
}
