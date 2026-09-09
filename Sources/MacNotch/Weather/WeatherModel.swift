import Foundation

/// Supported temperature units.
public enum TemperatureUnit: String, CaseIterable, Identifiable, Codable, Sendable {
    case celsius = "°C"
    case fahrenheit = "°F"

    public var id: String { rawValue }
}

/// Predefined or custom geographic location for weather lookup.
public struct WeatherLocation: Identifiable, Codable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let latitude: Double
    public let longitude: Double
    public let country: String?
    public let admin1: String?

    public init(
        id: String = UUID().uuidString,
        name: String,
        latitude: Double,
        longitude: Double,
        country: String? = nil,
        admin1: String? = nil
    ) {
        self.id = id
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
        self.country = country
        self.admin1 = admin1
    }

    public var displayName: String {
        var parts: [String] = [name]
        if let admin1 = admin1, !admin1.isEmpty, admin1 != name {
            parts.append(admin1)
        }
        if let country = country, !country.isEmpty {
            parts.append(country)
        }
        return parts.joined(separator: ", ")
    }

    public static let kathmandu = WeatherLocation(id: "ktm", name: "Kathmandu", latitude: 27.7172, longitude: 85.3240, country: "Nepal")
    public static let cupertino = WeatherLocation(id: "cup", name: "Cupertino", latitude: 37.3230, longitude: -122.0322, country: "United States", admin1: "California")
    public static let newYork = WeatherLocation(id: "nyc", name: "New York", latitude: 40.7128, longitude: -74.0060, country: "United States", admin1: "New York")
    public static let london = WeatherLocation(id: "lon", name: "London", latitude: 51.5074, longitude: -0.1278, country: "United Kingdom")
    public static let tokyo = WeatherLocation(id: "tyo", name: "Tokyo", latitude: 35.6762, longitude: 139.6503, country: "Japan")

    public static let presets: [WeatherLocation] = [.kathmandu, .cupertino, .newYork, .london, .tokyo]
}

/// Current weather conditions model.
public struct WeatherInfo: Equatable, Sendable {
    public let locationName: String
    public let temperature: Double // Stored in Celsius
    public let condition: String
    public let symbolName: String
    public let feelsLike: Double
    public let highTemp: Double
    public let lowTemp: Double
    public let humidity: Int?
    public let timestamp: Date

    public init(
        locationName: String,
        temperature: Double,
        condition: String,
        symbolName: String,
        feelsLike: Double,
        highTemp: Double,
        lowTemp: Double,
        humidity: Int? = nil,
        timestamp: Date = Date()
    ) {
        self.locationName = locationName
        self.temperature = temperature
        self.condition = condition
        self.symbolName = symbolName
        self.feelsLike = feelsLike
        self.highTemp = highTemp
        self.lowTemp = lowTemp
        self.humidity = humidity
        self.timestamp = timestamp
    }

    /// Formats temperature for display based on selected unit.
    public func formattedTemp(unit: TemperatureUnit) -> String {
        let value = (unit == .celsius) ? temperature : (temperature * 9 / 5 + 32)
        return "\(Int(round(value)))°"
    }

    public func formattedFeelsLike(unit: TemperatureUnit) -> String {
        let value = (unit == .celsius) ? feelsLike : (feelsLike * 9 / 5 + 32)
        return "\(Int(round(value)))°"
    }

    public func formattedHigh(unit: TemperatureUnit) -> String {
        let value = (unit == .celsius) ? highTemp : (highTemp * 9 / 5 + 32)
        return "\(Int(round(value)))°"
    }

    public func formattedLow(unit: TemperatureUnit) -> String {
        let value = (unit == .celsius) ? lowTemp : (lowTemp * 9 / 5 + 32)
        return "\(Int(round(value)))°"
    }
}
