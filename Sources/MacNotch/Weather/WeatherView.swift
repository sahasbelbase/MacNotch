import SwiftUI

/// Displays weather information in compact or expanded layouts.
public struct WeatherView: View {
    @ObservedObject var weatherService: WeatherService
    @ObservedObject var settings = SettingsStore.shared
    public var explicitUnit: TemperatureUnit?
    public var isCompact: Bool = false

    public var effectiveUnit: TemperatureUnit {
        explicitUnit ?? settings.temperatureUnit
    }

    public init(weatherService: WeatherService, unit: TemperatureUnit? = nil, isCompact: Bool = false) {
        self.weatherService = weatherService
        self.explicitUnit = unit
        self.isCompact = isCompact
    }

    public var body: some View {
        if isCompact {
            compactView
        } else {
            expandedView
        }
    }

    private var compactView: some View {
        HStack(spacing: 4) {
            if let weather = weatherService.currentWeather {
                Image(systemName: weather.symbolName)
                    .font(.system(size: 11))
                    .foregroundColor(.yellow)

                Text(weather.formattedTemp(unit: effectiveUnit))
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(DesignSystem.Colors.textPrimary)
            } else {
                Image(systemName: "cloud.sun.fill")
                    .font(.system(size: 11))
                    .foregroundColor(.yellow)
            }
        }
    }

    private var expandedView: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let weather = weatherService.currentWeather {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(weather.locationName)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(DesignSystem.Colors.textPrimary)

                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text(weather.formattedTemp(unit: effectiveUnit))
                                .font(.system(size: 26, weight: .bold, design: .rounded))
                                .foregroundColor(DesignSystem.Colors.textPrimary)

                            Text(weather.condition)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                        }
                    }

                    Spacer()

                    Image(systemName: weather.symbolName)
                        .font(.system(size: 28))
                        .foregroundColor(.yellow)
                }

                Divider()
                    .background(DesignSystem.Colors.subtleBorder)

                HStack {
                    Text("Feels like \(weather.formattedFeelsLike(unit: effectiveUnit))")
                        .font(.system(size: 10))
                        .foregroundColor(DesignSystem.Colors.textSecondary)

                    Spacer()

                    Text("H \(weather.formattedHigh(unit: effectiveUnit))  L \(weather.formattedLow(unit: effectiveUnit))")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
            } else if weatherService.isLoading {
                ProgressView()
                    .scaleEffect(0.7)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Text("Weather unavailable")
                    .font(.system(size: 11))
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }
        }
        .padding(10)
        .macNotchCardStyle()
    }
}
