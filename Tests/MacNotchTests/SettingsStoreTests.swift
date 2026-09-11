import XCTest
@testable import MacNotch

@MainActor
final class SettingsStoreTests: XCTestCase {
    func testSettingsDefaultsAndReset() {
        let settings = SettingsStore.shared
        settings.resetToDefaults()

        XCTAssertTrue(settings.enableNotch)
        XCTAssertTrue(settings.showNotchHardwareHUD)
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
        XCTAssertEqual(settings.selectedLocationName, "Kathmandu")
        XCTAssertEqual(settings.tempUnit, TemperatureUnit.celsius.rawValue)
        XCTAssertEqual(settings.temperatureUnit, .celsius)
        XCTAssertEqual(settings.appAppearance, "System")
    }

    func testWeatherLocationPersistenceAndUnitConversion() {
        let settings = SettingsStore.shared
        let customLocation = WeatherLocation(
            id: "pok",
            name: "Pokhara",
            latitude: 28.2096,
            longitude: 83.9856,
            country: "Nepal",
            admin1: "Gandaki"
        )

        XCTAssertEqual(customLocation.displayName, "Pokhara, Gandaki, Nepal")

        settings.currentWeatherLocation = customLocation
        XCTAssertEqual(settings.selectedLocationName, "Pokhara")
        XCTAssertEqual(settings.selectedLocationLat, 28.2096, accuracy: 0.001)
        XCTAssertEqual(settings.selectedLocationLon, 83.9856, accuracy: 0.001)
        XCTAssertEqual(settings.selectedLocationCountry, "Nepal")
        XCTAssertEqual(settings.currentWeatherLocation.name, "Pokhara")

        settings.temperatureUnit = .fahrenheit
        XCTAssertEqual(settings.tempUnit, TemperatureUnit.fahrenheit.rawValue)
        XCTAssertEqual(settings.temperatureUnit, .fahrenheit)

        let weather = WeatherInfo(
            locationName: "Pokhara",
            temperature: 20.0,
            condition: "Clear",
            symbolName: "sun.max.fill",
            feelsLike: 21.0,
            highTemp: 24.0,
            lowTemp: 16.0
        )

        // 20°C in Fahrenheit = 20 * 9/5 + 32 = 68°F
        XCTAssertEqual(weather.formattedTemp(unit: .celsius), "20°")
        XCTAssertEqual(weather.formattedTemp(unit: .fahrenheit), "68°")

        // Reset back to defaults
        settings.resetToDefaults()
        XCTAssertEqual(settings.temperatureUnit, .celsius)
    }
}
