import Combine
import Foundation

/// Protocol abstracting weather providers.
@MainActor
public protocol WeatherServiceProtocol: AnyObject, ObservableObject {
    var currentWeather: WeatherInfo? { get }
    var isLoading: Bool { get }
    var errorMessage: String? { get }
    func fetchWeather(for location: WeatherLocation) async
}

/// Fetches real-time weather forecasts via Open-Meteo API with local 15-minute caching.
@MainActor
public final class WeatherService: ObservableObject, WeatherServiceProtocol {
    public static let shared = WeatherService()

    @Published public private(set) var currentWeather: WeatherInfo?
    @Published public private(set) var isLoading: Bool = false
    @Published public private(set) var errorMessage: String?

    public var selectedLocation: WeatherLocation {
        didSet {
            Task {
                await fetchWeather(for: selectedLocation)
            }
        }
    }

    private var cache: [String: (info: WeatherInfo, timestamp: Date)] = [:]
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
            return
        }

        self.isLoading = true
        self.errorMessage = nil

        let urlString = "https://api.open-meteo.com/v1/forecast?latitude=\(location.latitude)&longitude=\(location.longitude)&current=temperature_2m,relative_humidity_2m,apparent_temperature,weather_code&daily=temperature_2m_max,temperature_2m_min&timezone=auto"

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

            self.currentWeather = info
            self.cache[location.id] = (info, Date())
            self.isLoading = false
        } catch {
            self.isLoading = false
            self.errorMessage = error.localizedDescription

            // If network fails and no cached info, provide sensible default fallback
            if self.currentWeather == nil {
                self.currentWeather = WeatherInfo(
                    locationName: location.name,
                    temperature: 21.0,
                    condition: "Clear",
                    symbolName: "sun.max.fill",
                    feelsLike: 22.0,
                    highTemp: 23.0,
                    lowTemp: 17.0
                )
            }
        }
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
}

private struct CurrentWeatherDTO: Decodable {
    let temperature_2m: Double
    let apparent_temperature: Double
    let relative_humidity_2m: Int
    let weather_code: Int
}

private struct DailyWeatherDTO: Decodable {
    let temperature_2m_max: [Double]
    let temperature_2m_min: [Double]
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
