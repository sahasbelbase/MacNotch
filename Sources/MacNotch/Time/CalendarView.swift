import SwiftUI
import AppKit

/// Dedicated native macOS Calendar interface showing interactive monthly calendar,
/// today highlights, weekday grid, and agenda schedule.
public struct CalendarView: View {
    @ObservedObject var timeService: TimeService
    @State private var displayedMonthOffset: Int = 0
    @State private var selectedDate: Date?

    public init(timeService: TimeService) {
        self.timeService = timeService
    }

    private var calendar: Calendar {
        Calendar.current
    }

    private var targetDate: Date {
        calendar.date(byAdding: .month, value: displayedMonthOffset, to: timeService.currentDate) ?? timeService.currentDate
    }

    public var body: some View {
        HStack(spacing: 16) {
            // Left Column: Interactive Month Grid
            VStack(spacing: 8) {
                // Month Navigation Header
                HStack {
                    Text(monthYearString(targetDate))
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(DesignSystem.Colors.textPrimary)

                    Spacer()

                    HStack(spacing: 6) {
                        Button(action: { withAnimation(.easeInOut(duration: 0.2)) { displayedMonthOffset -= 1 } }) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                                .frame(width: 20, height: 20)
                                .background(Color.white.opacity(0.1))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)

                        Button(action: { withAnimation(.easeInOut(duration: 0.2)) { displayedMonthOffset = 0 } }) {
                            Text("Today")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.accentColor)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.accentColor.opacity(0.15))
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)

                        Button(action: { withAnimation(.easeInOut(duration: 0.2)) { displayedMonthOffset += 1 } }) {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                                .frame(width: 20, height: 20)
                                .background(Color.white.opacity(0.1))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 4)

                // Weekday Row
                HStack(spacing: 0) {
                    ForEach(["S", "M", "T", "W", "T", "F", "S"], id: \.self) { day in
                        Text(day)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(DesignSystem.Colors.textTertiary)
                            .frame(maxWidth: .infinity)
                    }
                }

                Divider()
                    .background(DesignSystem.Colors.subtleBorder)

                // Month Days Grid
                let days = generateDaysInMonth(for: targetDate)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 7), spacing: 4) {
                    ForEach(days, id: \.id) { day in
                        if let date = day.date {
                            let isToday = calendar.isDate(date, inSameDayAs: timeService.currentDate)
                            let isSelected = selectedDate.map { calendar.isDate(date, inSameDayAs: $0) } ?? false

                            Button(action: { selectedDate = date }) {
                                Text("\(calendar.component(.day, from: date))")
                                    .font(.system(size: 11, weight: isToday ? .bold : .regular))
                                    .frame(width: 24, height: 24)
                                    .background(
                                        isToday
                                            ? Color.accentColor
                                            : (isSelected ? Color.white.opacity(0.2) : Color.clear)
                                    )
                                    .foregroundColor(isToday ? .white : DesignSystem.Colors.textPrimary)
                                    .clipShape(Circle())
                            }
                            .buttonStyle(.plain)
                        } else {
                            Text("")
                                .frame(width: 24, height: 24)
                        }
                    }
                }
            }
            .padding(10)
            .macNotchCardStyle()
            .frame(maxWidth: 320)

            // Right Column: Agenda & Date Details
            VStack(alignment: .leading, spacing: 10) {
                // Today Banner
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(timeService.dayOfWeek.uppercased())
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.accentColor)

                        Text(timeService.fullDate)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                    }

                    Spacer()

                    TimeView(timeService: timeService, isCompact: false)
                }

                Divider()
                    .background(DesignSystem.Colors.subtleBorder)

                // Agenda Highlights
                VStack(alignment: .leading, spacing: 6) {
                    Text("Today's Schedule")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(DesignSystem.Colors.textSecondary)

                    HStack(spacing: 8) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.green)
                            .frame(width: 3, height: 32)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("All clear today")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(DesignSystem.Colors.textPrimary)
                            Text("No pending meetings or conflicts")
                                .font(.system(size: 10))
                                .foregroundColor(DesignSystem.Colors.textTertiary)
                        }

                        Spacer()
                    }
                    .padding(8)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(8)
                }

                Spacer()

                // Launch Calendar App Button
                Button(action: openSystemCalendar) {
                    HStack(spacing: 6) {
                        Image(systemName: "calendar.badge.plus")
                            .font(.system(size: 11))
                        Text("Open macOS Calendar")
                            .font(.system(size: 11, weight: .medium))
                        Spacer()
                        Image(systemName: "arrow.up.forward.app")
                            .font(.system(size: 10))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(8)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                }
                .buttonStyle(.plain)
            }
            .padding(10)
            .macNotchCardStyle()
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 4)
    }

    private func openSystemCalendar() {
        if let url = URL(string: "ical:") {
            NSWorkspace.shared.open(url)
        }
    }

    private func monthYearString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date)
    }

    private struct CalendarDayItem: Identifiable {
        let id = UUID()
        let date: Date?
    }

    private func generateDaysInMonth(for date: Date) -> [CalendarDayItem] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: date),
              let monthFirstWeek = calendar.dateInterval(of: .weekOfMonth, for: monthInterval.start) else {
            return []
        }

        var days: [CalendarDayItem] = []

        // Empty padding before the 1st of the month
        let startWeekday = calendar.component(.weekday, from: monthInterval.start) - 1
        for _ in 0..<startWeekday {
            days.append(CalendarDayItem(date: nil))
        }

        // Days of current month
        var current = monthInterval.start
        while current < monthInterval.end {
            days.append(CalendarDayItem(date: current))
            guard let next = calendar.date(byAdding: .day, value: 1, to: current) else { break }
            current = next
        }

        return days
    }
}
