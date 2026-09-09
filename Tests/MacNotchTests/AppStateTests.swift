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

    func testShowAndDismissHUD() {
        XCTAssertNil(appState.activeHUD)
        appState.showHUD(.battery(percentage: 85, isCharging: true, timeRemaining: "42m to full"), duration: 1.0)
        XCTAssertEqual(appState.activeHUD, .battery(percentage: 85, isCharging: true, timeRemaining: "42m to full"))

        appState.showHUD(.volume(level: 0.75, isMuted: false), duration: 1.0)
        XCTAssertEqual(appState.activeHUD, .volume(level: 0.75, isMuted: false))

        appState.showHUD(.capsLock(isOn: true), duration: 1.0)
        XCTAssertEqual(appState.activeHUD, .capsLock(isOn: true))

        appState.dismissHUD()
        XCTAssertNil(appState.activeHUD)
    }

    func testHUDDismissOnMouseEnter() {
        appState.showHUD(.volume(level: 0.5, isMuted: false), duration: 2.0)
        XCTAssertNotNil(appState.activeHUD)

        appState.handleMouseEnter()
        XCTAssertNil(appState.activeHUD)
        XCTAssertEqual(appState.currentState, .activating)
    }
}
