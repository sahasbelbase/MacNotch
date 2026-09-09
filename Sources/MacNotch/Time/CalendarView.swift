import SwiftUI
import AppKit

/// Dedicated native macOS Calendar interface showing interactive monthly calendar,
/// today highlights, weekday grid, and agenda schedule.
public struct CalendarView: View {
    @ObservedObject var timeService: TimeService
    @ObservedObject var calendarSyncService: CalendarSyncService
    @ObservedObject var timerService: TimerService
    @State private var displayedMonthOffset: Int = 0
    @State private var selectedDate: Date?

    public init(
        timeService: TimeService,
        calendarSyncService: CalendarSyncService? = nil,
        timerService: TimerService? = nil
    ) {
        self.timeService = timeService
        self.calendarSyncService = calendarSyncService ?? CalendarSyncService()
        self.timerService = timerService ?? TimerService()
    }

    private var calendar: Calendar {
        Calendar.current
    }

    private var targetDate: Date {
        calendar.date(byAdding: .month, value: displayedMonthOffset, to: timeService.currentDate) ?? timeService.currentDate
    }

    public var body: some View {
        HStack(spacing: 14) {
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
            .frame(maxWidth: 300)

            // Right Column: Agenda, Meeting Glancer, & Focus Timer
            VStack(alignment: .leading, spacing: 8) {
                // Today Banner
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(timeService.dayOfWeek.uppercased())
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.accentColor)

                        Text(timeService.fullDate)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                    }

                    Spacer()

                    TimeView(timeService: timeService, isCompact: false)
                }

                Divider()
                    .background(DesignSystem.Colors.subtleBorder)

                // Agenda Highlights / Meeting Glancer
                agendaSectionView

                // Embedded Focus & Pomodoro Timer
                TimerWidgetView(timerService: timerService, isCompact: false)

                Spacer(minLength: 0)

                // Launch Calendar App Button
                Button(action: openSystemCalendar) {
                    HStack(spacing: 6) {
                        Image(systemName: "calendar.badge.plus")
                            .font(.system(size: 10))
                        Text("Open macOS Calendar")
                            .font(.system(size: 10, weight: .medium))
                        Spacer()
                        Image(systemName: "arrow.up.forward.app")
                            .font(.system(size: 9))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Color.white.opacity(0.06))
                    .cornerRadius(6)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                }
                .buttonStyle(.plain)
            }
            .padding(10)
            .macNotchCardStyle()
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 4)
    }

    // MARK: - Agenda & Meeting Glancer Subview
    @ViewBuilder
    private var agendaSectionView: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Schedule")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(DesignSystem.Colors.textSecondary)

                Spacer()

                if calendarSyncService.hasPermission {
                    Button(action: { calendarSyncService.fetchUpcomingEvents() }) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 9))
                            .foregroundColor(DesignSystem.Colors.textTertiary)
                    }
                    .buttonStyle(.plain)
                    .help("Refresh Calendar")
                }
            }

            if !calendarSyncService.hasPermission {
                // Permission Request Banner
                HStack(spacing: 8) {
                    Image(systemName: "calendar.badge.exclamationmark")
                        .font(.system(size: 14))
                        .foregroundColor(.yellow)

                    VStack(alignment: .leading, spacing: 1) {
                        Text("Sync macOS Calendar")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                        Text("Enable access to show meetings & video links")
                            .font(.system(size: 9))
                            .foregroundColor(DesignSystem.Colors.textTertiary)
                    }

                    Spacer()

                    Button(action: { calendarSyncService.requestAccess() }) {
                        Text("Connect")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.black)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.yellow)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
                .padding(8)
                .background(Color.yellow.opacity(0.1))
                .cornerRadius(8)
            } else if calendarSyncService.upcomingMeetings.isEmpty {
                // All clear banner
                HStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.green)
                        .frame(width: 3, height: 28)

                    VStack(alignment: .leading, spacing: 1) {
                        Text("All clear today")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                        Text("No pending meetings or conflicts")
                            .font(.system(size: 9))
                            .foregroundColor(DesignSystem.Colors.textTertiary)
                    }

                    Spacer()
                }
                .padding(6)
                .background(Color.white.opacity(0.04))
                .cornerRadius(6)
            } else {
                // Meeting list (top 2 events)
                VStack(spacing: 4) {
                    ForEach(Array(calendarSyncService.upcomingMeetings.prefix(2))) { meeting in
                        HStack(spacing: 8) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(meeting.isHappeningNow ? Color.green : Color.accentColor)
                                .frame(width: 3, height: 28)

                            VStack(alignment: .leading, spacing: 1) {
                                Text(meeting.title)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(DesignSystem.Colors.textPrimary)
                                    .lineLimit(1)

                                Text(meeting.formattedRelativeTime)
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundColor(meeting.isHappeningNow ? .green : .accentColor)
                            }

                            Spacer()

                            if let meetingURL = meeting.meetingURL {
                                Button(action: { calendarSyncService.joinMeeting(url: meetingURL) }) {
                                    HStack(spacing: 3) {
                                        Image(systemName: "video.fill")
                                            .font(.system(size: 9))
                                        Text("Join")
                                            .font(.system(size: 10, weight: .bold))
                                    }
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3.5)
                                    .background(Color.green.opacity(0.85))
                                    .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                                .help("Join \(meetingURL.host ?? "Call")")
                            }
                        }
                        .padding(6)
                        .background(Color.white.opacity(0.04))
                        .cornerRadius(6)
                    }
                }
            }
        }
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
        guard let monthInterval = calendar.dateInterval(of: .month, for: date) else {
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
