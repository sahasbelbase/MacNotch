import SwiftUI

/// Displays weather information in compact or expanded layouts with smart advice and multi-day forecasts.
public struct WeatherView: View {
    @ObservedObject var weatherService: WeatherService
    @ObservedObject var settings = SettingsStore.shared
    public var explicitUnit: TemperatureUnit?
    public var isCompact: Bool = false
    @State private var showCitySearch: Bool = false
    @State private var searchQuery: String = ""
    @State private var searchResults: [WeatherLocation] = []
    @State private var isSearching: Bool = false

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
            expandedDashboardView
        }
    }

    // MARK: - Compact View (Notch Status Pill)
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

    // MARK: - Expanded Dashboard View
    private var expandedDashboardView: some View {
        VStack(spacing: 8) {
            // 1. Header Bar: Location, Current Temperature, Unit Toggle & City Switcher
            currentWeatherHeaderView

            // 2. Smart Weather Suggestion Box ("Bring your umbrella with you")
            if let advice = weatherService.weatherAdvice {
                smartAdviceCardView(advice: advice)
            }

            // 3. Hourly Forecast Strip (Next 12 Hours)
            if !weatherService.hourlyForecast.isEmpty {
                hourlyForecastStripView
            }

            // 4. Multi-Day Forecast (Tomorrow + Upcoming Days)
            if !weatherService.dailyForecast.isEmpty {
                multiDayForecastView
            }

            // 5. Preset City Quick Switcher
            presetCityQuickSwitcherView
        }
        .padding(10)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Current Weather Header
    private var currentWeatherHeaderView: some View {
        HStack(alignment: .center, spacing: 12) {
            if let weather = weatherService.currentWeather {
                // Weather icon with gentle glow
                Image(systemName: weather.symbolName)
                    .font(.system(size: 32))
                    .foregroundColor(weatherIconColor(for: weather.symbolName))
                    .frame(width: 44, height: 44)
                    .background(weatherIconColor(for: weather.symbolName).opacity(0.12))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(weather.locationName)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(DesignSystem.Colors.textPrimary)

                        Text("• \(weather.condition)")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }

                    HStack(spacing: 8) {
                        Text("Feels like \(weather.formattedFeelsLike(unit: effectiveUnit))")
                            .font(.system(size: 10))
                            .foregroundColor(DesignSystem.Colors.textSecondary)

                        Text("H: \(weather.formattedHigh(unit: effectiveUnit))  L: \(weather.formattedLow(unit: effectiveUnit))")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(DesignSystem.Colors.textTertiary)

                        if let humidity = weather.humidity {
                            Text("💧 \(humidity)%")
                                .font(.system(size: 10))
                                .foregroundColor(Color.cyan)
                        }
                    }
                }

                Spacer()

                // Temperature + Unit Switcher Pill
                HStack(spacing: 6) {
                    Text(weather.formattedTemp(unit: effectiveUnit))
                        .font(.system(size: 28, weight: .heavy, design: .rounded))
                        .foregroundColor(DesignSystem.Colors.textPrimary)

                    Button(action: toggleTemperatureUnit) {
                        Text(effectiveUnit.rawValue)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.accentColor)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color.accentColor.opacity(0.15))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .help("Toggle °C / °F")
                }
            } else if weatherService.isLoading {
                ProgressView()
                    .scaleEffect(0.8)
                    .frame(maxWidth: .infinity)
            } else {
                Text("Weather unavailable")
                    .font(.system(size: 12))
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }
        }
        .padding(8)
        .macNotchCardStyle()
    }

    // MARK: - Smart Advice Card View
    private func smartAdviceCardView(advice: WeatherAdvice) -> some View {
        HStack(spacing: 10) {
            Image(systemName: advice.icon)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(adviceColor(for: advice.icon))
                .frame(width: 32, height: 32)
                .background(adviceColor(for: advice.icon).opacity(0.15))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 6) {
                    Text(advice.title)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(DesignSystem.Colors.textPrimary)

                    Text(advice.badge.uppercased())
                        .font(.system(size: 8, weight: .heavy))
                        .foregroundColor(adviceColor(for: advice.icon))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(adviceColor(for: advice.icon).opacity(0.12))
                        .clipShape(Capsule())
                }

                Text(advice.suggestion)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .lineLimit(2)
            }

            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(adviceColor(for: advice.icon).opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(adviceColor(for: advice.icon).opacity(0.25), lineWidth: 1)
                )
        )
    }

    // MARK: - Hourly Forecast Strip
    private var hourlyForecastStripView: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Upcoming Hours")
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(DesignSystem.Colors.textTertiary)
                .padding(.horizontal, 4)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(weatherService.hourlyForecast) { hour in
                        VStack(spacing: 3) {
                            Text(hour.timeLabel)
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(DesignSystem.Colors.textTertiary)

                            Image(systemName: hour.symbolName)
                                .font(.system(size: 12))
                                .foregroundColor(weatherIconColor(for: hour.symbolName))
                                .frame(height: 16)

                            Text(hour.formattedTemp(unit: effectiveUnit))
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .foregroundColor(DesignSystem.Colors.textPrimary)

                            if hour.precipitationProbability > 0 {
                                Text("\(hour.precipitationProbability)%")
                                    .font(.system(size: 8, weight: .semibold))
                                    .foregroundColor(.cyan)
                            } else {
                                Text("-")
                                    .font(.system(size: 8))
                                    .foregroundColor(Color.clear)
                            }
                        }
                        .frame(width: 44)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.04))
                        .cornerRadius(8)
                    }
                }
            }
        }
    }

    // MARK: - Multi-Day Forecast (Tomorrow + Upcoming 4 Days)
    private var multiDayForecastView: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Daily Forecast")
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(DesignSystem.Colors.textTertiary)
                .padding(.horizontal, 4)

            HStack(spacing: 6) {
                ForEach(weatherService.dailyForecast.prefix(5)) { day in
                    let isTomorrow = day.dayName == "Tomorrow"

                    VStack(spacing: 3) {
                        Text(day.dayName)
                            .font(.system(size: 9, weight: isTomorrow ? .bold : .medium))
                            .foregroundColor(isTomorrow ? .accentColor : DesignSystem.Colors.textSecondary)

                        Image(systemName: day.symbolName)
                            .font(.system(size: 14))
                            .foregroundColor(weatherIconColor(for: day.symbolName))
                            .frame(height: 18)

                        if day.precipitationProbability > 0 {
                            HStack(spacing: 1) {
                                Image(systemName: "drop.fill")
                                    .font(.system(size: 7))
                                Text("\(day.precipitationProbability)%")
                                    .font(.system(size: 8, weight: .bold))
                            }
                            .foregroundColor(.cyan)
                        } else {
                            Text("")
                                .font(.system(size: 8))
                                .frame(height: 10)
                        }

                        HStack(spacing: 3) {
                            Text(day.formattedMax(unit: effectiveUnit))
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .foregroundColor(DesignSystem.Colors.textPrimary)

                            Text(day.formattedMin(unit: effectiveUnit))
                                .font(.system(size: 9, design: .rounded))
                                .foregroundColor(DesignSystem.Colors.textTertiary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(isTomorrow ? Color.accentColor.opacity(0.08) : Color.white.opacity(0.04))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isTomorrow ? Color.accentColor.opacity(0.3) : Color.clear, lineWidth: 1)
                    )
                }
            }
        }
    }

    // MARK: - Preset City Quick Switcher
    private var presetCityQuickSwitcherView: some View {
        HStack(spacing: 6) {
            Image(systemName: "mappin.and.ellipse")
                .font(.system(size: 9))
                .foregroundColor(DesignSystem.Colors.textTertiary)

            ForEach(WeatherLocation.presets) { loc in
                let isSelected = weatherService.selectedLocation.name.lowercased() == loc.name.lowercased()

                Button(action: {
                    weatherService.setLocation(loc)
                }) {
                    Text(loc.name)
                        .font(.system(size: 9, weight: isSelected ? .bold : .medium))
                        .foregroundColor(isSelected ? .white : DesignSystem.Colors.textSecondary)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2.5)
                        .background(isSelected ? Color.accentColor : Color.white.opacity(0.06))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }

            Spacer()

            Button(action: {
                // Open Settings Weather Tab
                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
            }) {
                HStack(spacing: 3) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 8))
                    Text("Search City")
                        .font(.system(size: 9, weight: .medium))
                }
                .foregroundColor(DesignSystem.Colors.textTertiary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2.5)
                .background(Color.white.opacity(0.05))
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .help("Search any city in the world")
        }
        .padding(.horizontal, 4)
    }

    // MARK: - Styling Helpers
    private func toggleTemperatureUnit() {
        let nextUnit: TemperatureUnit = (settings.temperatureUnit == .celsius) ? .fahrenheit : .celsius
        settings.temperatureUnit = nextUnit
    }

    private func weatherIconColor(for symbolName: String) -> Color {
        if symbolName.contains("sun") {
            return .yellow
        } else if symbolName.contains("rain") || symbolName.contains("drizzle") {
            return .cyan
        } else if symbolName.contains("snow") {
            return .white
        } else if symbolName.contains("bolt") {
            return .orange
        } else {
            return .gray
        }
    }

    private func adviceColor(for iconName: String) -> Color {
        if iconName.contains("umbrella") || iconName.contains("rain") {
            return .cyan
        } else if iconName.contains("sun") {
            return .yellow
        } else if iconName.contains("jacket") || iconName.contains("snowflake") {
            return .indigo
        } else if iconName.contains("walk") {
            return .green
        } else {
            return .orange
        }
    }
}
