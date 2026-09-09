import XCTest
@testable import MacNotch
import AppKit

@MainActor
final class CalendarAndWeatherEnhancementsTests: XCTestCase {

    // MARK: - Weather Forecast & Advice Tests

    func testDayForecastItemFormatting() {
        let forecast = DayForecastItem(
            id: "2026-09-10",
            date: Date(),
            dayName: "Tomorrow",
            maxTemp: 22.0,
            minTemp: 15.0,
            condition: "Rain",
            symbolName: "cloud.rain.fill",
            precipitationProbability: 80
        )

        XCTAssertEqual(forecast.formattedMax(unit: .celsius), "22°")
        XCTAssertEqual(forecast.formattedMin(unit: .celsius), "15°")
        // 22°C = 71.6 -> 72°F, 15°C = 59°F
        XCTAssertEqual(forecast.formattedMax(unit: .fahrenheit), "72°")
        XCTAssertEqual(forecast.formattedMin(unit: .fahrenheit), "59°")
    }

    func testHourlyForecastItemFormatting() {
        let hourItem = HourlyForecastItem(
            id: "14:00",
            time: Date(),
            timeLabel: "2pm",
            temp: 25.0,
            condition: "Clear",
            symbolName: "sun.max.fill",
            precipitationProbability: 10
        )

        XCTAssertEqual(hourItem.formattedTemp(unit: .celsius), "25°")
        // 25°C = 77°F
        XCTAssertEqual(hourItem.formattedTemp(unit: .fahrenheit), "77°")
    }

    func testWeatherAdviceRainUmbrellaRecommendation() {
        let current = WeatherInfo(
            locationName: "Kathmandu",
            temperature: 18.0,
            condition: "Rain",
            symbolName: "cloud.rain.fill"
        )
        let rainForecast = [
            DayForecastItem(
                id: "today",
                date: Date(),
                dayName: "Today",
                maxTemp: 18.0,
                minTemp: 12.0,
                condition: "Rain",
                symbolName: "cloud.rain.fill",
                precipitationProbability: 85
            )
        ]

        let advice = WeatherService.shared.generateAdvice(
            current: current,
            daily: rainForecast
        )

        XCTAssertTrue(advice.shouldCarryUmbrella)
        XCTAssertEqual(advice.icon, "umbrella.fill")
        XCTAssertTrue(advice.title.contains("Rain"))
        XCTAssertTrue(advice.suggestion.localizedCaseInsensitiveContains("umbrella"))
    }

    func testWeatherAdviceColdWeatherJacket() {
        let current = WeatherInfo(
            locationName: "Kathmandu",
            temperature: 6.0,
            condition: "Clear",
            symbolName: "sun.max.fill"
        )
        let coldForecast = [
            DayForecastItem(
                id: "today",
                date: Date(),
                dayName: "Today",
                maxTemp: 8.0,
                minTemp: 3.0,
                condition: "Clear",
                symbolName: "sun.max.fill",
                precipitationProbability: 0
            )
        ]

        let advice = WeatherService.shared.generateAdvice(
            current: current,
            daily: coldForecast
        )

        XCTAssertFalse(advice.shouldCarryUmbrella)
        XCTAssertTrue(advice.title.contains("Cold") || advice.suggestion.contains("jacket") || advice.icon == "jacket.fill")
    }

    func testWeatherAdviceHotWeatherHydration() {
        let current = WeatherInfo(
            locationName: "Kathmandu",
            temperature: 33.0,
            condition: "Sunny",
            symbolName: "sun.max.fill"
        )
        let hotForecast = [
            DayForecastItem(
                id: "today",
                date: Date(),
                dayName: "Today",
                maxTemp: 34.0,
                minTemp: 24.0,
                condition: "Sunny",
                symbolName: "sun.max.fill",
                precipitationProbability: 0
            )
        ]

        let advice = WeatherService.shared.generateAdvice(
            current: current,
            daily: hotForecast
        )

        XCTAssertFalse(advice.shouldCarryUmbrella)
        XCTAssertTrue(advice.suggestion.localizedCaseInsensitiveContains("hydrate") || advice.suggestion.localizedCaseInsensitiveContains("sunscreen") || advice.badge.contains("Hot"))
    }

    // MARK: - Google Calendar iCal Parser Tests

    func testICalParserWithGoogleMeetAndDates() {
        let icsContent = """
        BEGIN:VCALENDAR
        VERSION:2.0
        PRODID:-//Google Inc//Google Calendar 70.9054//EN
        BEGIN:VEVENT
        UID:google-meet-event-12345@google.com
        DTSTART:20260910T100000Z
        DTEND:20260910T104500Z
        SUMMARY:MacNotch Architecture Review
        DESCRIPTION:Join video meeting at: https://meet.google.com/xyz-abcd-efg
        LOCATION:Google Meet
        STATUS:CONFIRMED
        END:VEVENT
        BEGIN:VEVENT
        UID:google-event-zoom-999@google.com
        DTSTART:20260910T140000Z
        DTEND:20260910T150000Z
        SUMMARY:Design Sync
        DESCRIPTION:Zoom link: https://zoom.us/j/987654321
        LOCATION:Online
        STATUS:CONFIRMED
        END:VEVENT
        END:VCALENDAR
        """

        let events = ICalParser.parse(icsString: icsContent)
        XCTAssertEqual(events.count, 2)

        let first = events[0]
        XCTAssertEqual(first.title, "MacNotch Architecture Review")
        XCTAssertTrue(first.isGoogleCalendar)
        XCTAssertEqual(first.meetingURL?.absoluteString, "https://meet.google.com/xyz-abcd-efg")

        let second = events[1]
        XCTAssertEqual(second.title, "Design Sync")
        XCTAssertTrue(second.isGoogleCalendar)
        XCTAssertEqual(second.meetingURL?.absoluteString, "https://zoom.us/j/987654321")
    }

    @MainActor
    func testSettingsStoreGoogleCalendarPersistence() {
        let store = SettingsStore.shared
        let originalURL = store.googleCalendarICalURL
        let originalEnabled = store.googleCalendarEnabled

        store.googleCalendarICalURL = "https://calendar.google.com/calendar/ical/test@example.com/private-123/basic.ics"
        store.googleCalendarEnabled = true

        XCTAssertEqual(store.googleCalendarICalURL, "https://calendar.google.com/calendar/ical/test@example.com/private-123/basic.ics")
        XCTAssertTrue(store.googleCalendarEnabled)

        // Restore
        store.googleCalendarICalURL = originalURL
        store.googleCalendarEnabled = originalEnabled
    }
}
