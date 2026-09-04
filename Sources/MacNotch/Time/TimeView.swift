import SwiftUI

/// Displays current time and date formatted according to system preferences.
public struct TimeView: View {
    @ObservedObject var timeService: TimeService
    public var isCompact: Bool = false

    public init(timeService: TimeService, isCompact: Bool = false) {
        self.timeService = timeService
        self.isCompact = isCompact
    }

    public var body: some View {
        if isCompact {
            Text(timeService.shortTime)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundColor(DesignSystem.Colors.textPrimary)
        } else {
            VStack(alignment: .leading, spacing: 2) {
                Text(timeService.dayOfWeek)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(DesignSystem.Colors.textSecondary)

                Text(timeService.fullDate)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(DesignSystem.Colors.textPrimary)

                Text(timeService.fullTime)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                    .padding(.top, 2)
            }
            .padding(10)
            .macNotchCardStyle()
        }
    }
}
