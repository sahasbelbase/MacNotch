import Combine
import Foundation

/// Protocol abstracting weather providers.
@MainActor
public protocol WeatherServiceProtocol: AnyObject, ObservableObject {
    var currentWeather: WeatherInfo? { get }
    var dailyForecast: [DayForecastItem] { get }
    var hourlyForecast: [HourlyForecastItem] { get }
    var weatherAdvice: WeatherAdvice? { get }
    var isLoading: Bool { get }
    var errorMessage: String? { get }
    func fetchWeather(for location: WeatherLocation) async
}

/// Fetches real-time weather forecasts, multi-day predictions, and smart advice via Open-Meteo API.
@MainActor
public final class WeatherService: ObservableObject, WeatherServiceProtocol {
    public static let shared = WeatherService()

    @Published public private(set) var currentWeather: WeatherInfo?
    @Published public private(set) var dailyForecast: [DayForecastItem] = []
    @Published public private(set) var hourlyForecast: [HourlyForecastItem] = []
    @Published public private(set) var weatherAdvice: WeatherAdvice?
    @Published public private(set) var isLoading: Bool = false
    @Published public private(set) var errorMessage: String?

    public var selectedLocation: WeatherLocation {
        didSet {
            Task {
                await fetchWeather(for: selectedLocation)
            }
        }
    }

    private var cache: [String: (info: WeatherInfo, daily: [DayForecastItem], hourly: [HourlyForecastItem], advice: WeatherAdvice?, timestamp: Date)] = [:]
    private let cacheDuration: TimeInterval = 900 // 15 minutes

    public init() {
        let initialLoc = SettingsStore.shared.currentWeatherLocation
        self.selectedLocation = initialLoc
        Task {
            await fetchWeather(for: initialLoc)
        }
    }

    public func setLocation(_ location: WeatherLocation) {
        self.selectedLocation = location
        SettingsStore.shared.currentWeatherLocation = location
        Task {
            await fetchWeather(for: location)
        }
    }

    /// Queries Open-Meteo worldwide geocoding database for city names, countries, and coordinates.
    public func searchLocations(query: String) async throws -> [WeatherLocation] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else { return [] }
        guard let encoded = trimmed.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://geocoding-api.open-meteo.com/v1/search?name=\(encoded)&count=10&language=en&format=json") else {
            return []
        }

        let (data, response) = try await URLSession.shared.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }

        let decoded = try JSONDecoder().decode(OpenMeteoGeocodingResponse.self, from: data)
        guard let results = decoded.results else { return [] }

        return results.map { res in
            WeatherLocation(
                id: "\(res.id)",
                name: res.name,
                latitude: res.latitude,
                longitude: res.longitude,
                country: res.country,
                admin1: res.admin1
            )
        }
    }

    public func fetchWeather(for location: WeatherLocation) async {
        // Check cache
        if let cached = cache[location.id], Date().timeIntervalSince(cached.timestamp) < cacheDuration {
            self.currentWeather = cached.info
            self.dailyForecast = cached.daily
            self.hourlyForecast = cached.hourly
            self.weatherAdvice = cached.advice
            return
        }

        self.isLoading = true
        self.errorMessage = nil

        let urlString = "https://api.open-meteo.com/v1/forecast?latitude=\(location.latitude)&longitude=\(location.longitude)&current=temperature_2m,relative_humidity_2m,apparent_temperature,weather_code&daily=weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max,precipitation_sum,uv_index_max&hourly=temperature_2m,weather_code,precipitation_probability&forecast_days=7&timezone=auto"

        guard let url = URL(string: urlString) else {
            self.isLoading = false
            self.errorMessage = "Invalid weather URL"
            return
        }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                throw URLError(.badServerResponse)
            }

            let decoded = try JSONDecoder().decode(OpenMeteoResponse.self, from: data)

            let (condition, symbol) = mapWeatherCode(decoded.current.weather_code)
            let high = decoded.daily.temperature_2m_max.first ?? decoded.current.temperature_2m
            let low = decoded.daily.temperature_2m_min.first ?? decoded.current.temperature_2m

            let info = WeatherInfo(
                locationName: location.name,
                temperature: decoded.current.temperature_2m,
                condition: condition,
                symbolName: symbol,
                feelsLike: decoded.current.apparent_temperature,
                highTemp: high,
                lowTemp: low,
                humidity: decoded.current.relative_humidity_2m
            )

            // Parse Daily Forecast (Tomorrow + Upcoming 5 days)
            let dailyItems = parseDailyForecast(from: decoded.daily)

            // Parse Hourly Forecast (Next 12 hours)
            let hourlyItems = parseHourlyForecast(from: decoded.hourly)

            // Generate Smart Weather Advice (e.g. umbrella reminder, jacket, sunglasses)
            let advice = generateAdvice(current: info, daily: dailyItems, hourly: hourlyItems)

            self.currentWeather = info
            self.dailyForecast = dailyItems
            self.hourlyForecast = hourlyItems
            self.weatherAdvice = advice

            self.cache[location.id] = (info, dailyItems, hourlyItems, advice, Date())
            self.isLoading = false
        } catch {
            self.isLoading = false
            self.errorMessage = error.localizedDescription

            // Fallback for offline/error state
            if self.currentWeather == nil {
                let fallback = WeatherInfo(
                    locationName: location.name,
                    temperature: 21.0,
                    condition: "Clear",
                    symbolName: "sun.max.fill",
                    feelsLike: 22.0,
                    highTemp: 23.0,
                    lowTemp: 17.0
                )
                self.currentWeather = fallback
                self.weatherAdvice = WeatherAdvice(
                    title: "Pleasant Day",
                    suggestion: "Mild and comfortable temperatures. Enjoy your day!",
                    icon: "sun.max.fill",
                    badge: "All Good"
                )
            }
        }
    }

    private func parseDailyForecast(from daily: DailyWeatherDTO) -> [DayForecastItem] {
        var items: [DayForecastItem] = []
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        let dayDisplayFormatter = DateFormatter()
        dayDisplayFormatter.dateFormat = "EEE"

        let count = min(daily.time.count, daily.weather_code.count, daily.temperature_2m_max.count, daily.temperature_2m_min.count)

        for i in 0..<count {
            guard let date = dateFormatter.date(from: daily.time[i]) else { continue }
            let (cond, sym) = mapWeatherCode(daily.weather_code[i])
            let maxT = daily.temperature_2m_max[i]
            let minT = daily.temperature_2m_min[i]
            let rainProb = (daily.precipitation_probability_max != nil && i < daily.precipitation_probability_max!.count)
                ? daily.precipitation_probability_max![i]
                : 0
            let rainSum = (daily.precipitation_sum != nil && i < daily.precipitation_sum!.count)
                ? daily.precipitation_sum![i]
                : 0.0
            let uv = (daily.uv_index_max != nil && i < daily.uv_index_max!.count)
                ? daily.uv_index_max![i]
                : nil

            let isToday = Calendar.current.isDateInToday(date)
            let isTomorrow = Calendar.current.isDateInTomorrow(date)
            let dayName = isToday ? "Today" : (isTomorrow ? "Tomorrow" : dayDisplayFormatter.string(from: date))

            items.append(DayForecastItem(
                date: date,
                dayName: dayName,
                maxTemp: maxT,
                minTemp: minT,
                condition: cond,
                symbolName: sym,
                precipitationProbability: rainProb,
                precipitationSum: rainSum,
                uvIndex: uv
            ))
        }

        return items
    }

    private func parseHourlyForecast(from hourly: HourlyWeatherDTO?) -> [HourlyForecastItem] {
        guard let hourly = hourly else { return [] }
        var items: [HourlyForecastItem] = []

        let isoFormatter = DateFormatter()
        isoFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm"

        let hourDisplayFormatter = DateFormatter()
        hourDisplayFormatter.dateFormat = "ha"

        let now = Date()
        let count = min(hourly.time.count, hourly.temperature_2m.count, hourly.weather_code.count)

        for i in 0..<count {
            guard let date = isoFormatter.date(from: hourly.time[i]) else { continue }
            // Only keep upcoming hours (from current hour up to 12 hours ahead)
            if date.timeIntervalSince(now) >= -1800 && items.count < 12 {
                let (cond, sym) = mapWeatherCode(hourly.weather_code[i])
                let isCurrentHour = abs(date.timeIntervalSince(now)) < 1800
                let label = isCurrentHour ? "Now" : hourDisplayFormatter.string(from: date).lowercased()
                let rainProb = (hourly.precipitation_probability != nil && i < hourly.precipitation_probability!.count)
                    ? hourly.precipitation_probability![i]
                    : 0

                items.append(HourlyForecastItem(
                    time: date,
                    timeLabel: label,
                    temp: hourly.temperature_2m[i],
                    condition: cond,
                    symbolName: sym,
                    precipitationProbability: rainProb
                ))
            }
        }

        return items
    }

    public func generateAdvice(current: WeatherInfo, daily: [DayForecastItem], hourly: [HourlyForecastItem] = []) -> WeatherAdvice {
        let todayRainChance = daily.first(where: { $0.dayName == "Today" })?.precipitationProbability ?? 0
        let tomorrowRainChance = daily.first(where: { $0.dayName == "Tomorrow" })?.precipitationProbability ?? 0
        let currentCode = current.symbolName

        // 1. Rain Alert: If rain is happening or chance is high today
        if currentCode.contains("rain") || currentCode.contains("drizzle") || currentCode.contains("bolt") || todayRainChance >= 40 {
            let pct = max(todayRainChance, 45)
            return WeatherAdvice(
                title: "Rain Expected",
                suggestion: "Rain expected today (\(pct)% chance) — bring your umbrella with you!",
                icon: "umbrella.fill",
                badge: "Take Umbrella"
            )
        }

        // 2. Tomorrow Rain Alert: If tomorrow will be rainy
        if tomorrowRainChance >= 50 {
            return WeatherAdvice(
                title: "Rain Tomorrow",
                suggestion: "Showers forecasted tomorrow (\(tomorrowRainChance)%) — keep an umbrella ready!",
                icon: "cloud.rain.fill",
                badge: "Rain Alert"
            )
        }

        // 3. Freezing / Snow Alert
        if current.temperature <= 0 || currentCode.contains("snow") {
            return WeatherAdvice(
                title: "Freezing Weather",
                suggestion: "Sub-zero conditions outside — bundle up in heavy winter layers.",
                icon: "snowflake",
                badge: "Bundle Up"
            )
        }

        // 4. Cold / Chilly Alert
        if current.temperature <= 12 {
            return WeatherAdvice(
                title: "Chilly Temperatures",
                suggestion: "Brisk cold air today — wear a warm jacket before heading out.",
                icon: "thermometer.snowflake",
                badge: "Wear Jacket"
            )
        }

        // 5. Extreme Heat Alert
        if current.temperature >= 30 {
            return WeatherAdvice(
                title: "Hot & Sunny",
                suggestion: "High heat outside (\(Int(round(current.temperature)))°C) — stay well hydrated and apply sunscreen.",
                icon: "sun.max.fill",
                badge: "Stay Hydrated"
            )
        }

        // 6. High UV / Sunny Alert
        let uv = daily.first(where: { $0.dayName == "Today" })?.uvIndex ?? 0
        if uv >= 6 || ((current.condition.contains("Clear") || current.condition.contains("Sunny")) && current.temperature >= 24) {
            return WeatherAdvice(
                title: "Sunny & High UV",
                suggestion: "Bright skies and strong sunshine — don't forget sunglasses and sunscreen.",
                icon: "sunglasses.fill",
                badge: "Sunglasses"
            )
        }

        // 6. Pleasant Weather
        if current.temperature >= 18 && current.temperature <= 25 {
            return WeatherAdvice(
                title: "Great Weather",
                suggestion: "Pleasant \(Int(round(current.temperature)))°C with clear air — great day for an outdoor break!",
                icon: "figure.walk",
                badge: "Pleasant Day"
            )
        }

        // 7. Default Mild
        return WeatherAdvice(
            title: "Fair Weather",
            suggestion: "\(current.condition) conditions throughout the day. Have a productive day!",
            icon: "sparkles",
            badge: "All Clear"
        )
    }

    private func mapWeatherCode(_ code: Int) -> (condition: String, symbol: String) {
        switch code {
        case 0: return ("Clear", "sun.max.fill")
        case 1, 2: return ("Partly Cloudy", "cloud.sun.fill")
        case 3: return ("Overcast", "cloud.fill")
        case 45, 48: return ("Foggy", "cloud.fog.fill")
        case 51, 53, 55: return ("Drizzle", "cloud.drizzle.fill")
        case 61, 63, 65: return ("Rain", "cloud.rain.fill")
        case 71, 73, 75: return ("Snow", "cloud.snow.fill")
        case 80, 81, 82: return ("Showers", "cloud.heavyrain.fill")
        case 95, 96, 99: return ("Thunderstorm", "cloud.bolt.rain.fill")
        default: return ("Clear", "sun.max.fill")
        }
    }
}

// MARK: - OpenMeteo JSON Decoding Models

private struct OpenMeteoResponse: Decodable {
    let current: CurrentWeatherDTO
    let daily: DailyWeatherDTO
    let hourly: HourlyWeatherDTO?
}

private struct CurrentWeatherDTO: Decodable {
    let temperature_2m: Double
    let apparent_temperature: Double
    let relative_humidity_2m: Int
    let weather_code: Int
}

private struct DailyWeatherDTO: Decodable {
    let time: [String]
    let weather_code: [Int]
    let temperature_2m_max: [Double]
    let temperature_2m_min: [Double]
    let precipitation_probability_max: [Int]?
    let precipitation_sum: [Double]?
    let uv_index_max: [Double]?
}

private struct HourlyWeatherDTO: Decodable {
    let time: [String]
    let temperature_2m: [Double]
    let weather_code: [Int]
    let precipitation_probability: [Int]?
}

private struct OpenMeteoGeocodingResponse: Decodable {
    let results: [GeocodingResultDTO]?
}

private struct GeocodingResultDTO: Decodable {
    let id: Int
    let name: String
    let latitude: Double
    let longitude: Double
    let country: String?
    let admin1: String?
}
