import XCTest
@testable import MacNotch

@MainActor
final class SettingsStoreTests: XCTestCase {
    func testSettingsDefaultsAndReset() {
        let settings = SettingsStore.shared
        settings.resetToDefaults()

        XCTAssertTrue(settings.enableNotch)
        XCTAssertEqual(settings.hoverDelay, 0.12, accuracy: 0.01)
        XCTAssertEqual(settings.collapseDelay, 0.35, accuracy: 0.01)
        XCTAssertEqual(settings.clipboardRetention, 80)
        XCTAssertEqual(settings.clipboardAutoDelete, AutoDeletePeriod.never.rawValue)
        XCTAssertTrue(settings.filterSensitive)
        XCTAssertEqual(settings.musicSource, "Auto")
        XCTAssertTrue(settings.showOverviewMusic)
        XCTAssertTrue(settings.showOverviewClipboard)
        XCTAssertEqual(settings.defaultTab, "Overview")
        XCTAssertEqual(settings.selectedLocationId, "ktm")
        XCTAssertEqual(settings.tempUnit, TemperatureUnit.celsius.rawValue)
        XCTAssertEqual(settings.appAppearance, "System")
    }
}
