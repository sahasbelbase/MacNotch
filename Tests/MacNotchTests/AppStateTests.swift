import XCTest
@testable import MacNotch

@MainActor
final class AppStateTests: XCTestCase {
    var appState: AppState!

    override func setUp() async throws {
        try await super.setUp()
        appState = AppState()
        appState.hoverActivationDelay = 0.05
        appState.collapseDelay = 0.05
    }

    override func tearDown() async throws {
        appState.cancelAllTasks()
        try await super.tearDown()
    }

    func testInitialState() {
        XCTAssertEqual(appState.currentState, .collapsed)
        XCTAssertTrue(appState.isEnabled)
    }

    func testDisabledTransitionsToHidden() {
        appState.isEnabled = false
        XCTAssertEqual(appState.currentState, .hidden)

        appState.handleMouseEnter()
        XCTAssertEqual(appState.currentState, .hidden)

        appState.isEnabled = true
        XCTAssertEqual(appState.currentState, .collapsed)
    }

    func testStateTransitions() {
        appState.transition(to: .activating)
        XCTAssertEqual(appState.currentState, .activating)

        appState.transition(to: .expanded)
        XCTAssertEqual(appState.currentState, .expanded)

        appState.transition(to: .collapsing)
        XCTAssertEqual(appState.currentState, .collapsing)

        appState.transition(to: .collapsed)
        XCTAssertEqual(appState.currentState, .collapsed)
    }

    func testTabSwitching() {
        XCTAssertEqual(appState.selectedTab, .overview)
        appState.selectedTab = .clipboard
        XCTAssertEqual(appState.selectedTab, .clipboard)
        appState.selectedTab = .calendar
        XCTAssertEqual(appState.selectedTab, .calendar)
        appState.selectedTab = .weather
        XCTAssertEqual(appState.selectedTab, .weather)
        appState.selectedTab = .overview
        XCTAssertEqual(appState.selectedTab, .overview)
    }
}
