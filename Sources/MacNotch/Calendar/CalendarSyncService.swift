import AppKit
import EventKit
import Foundation

/// Model representing a glanceable calendar meeting with 1-click video link extraction.
public struct CalendarMeetingItem: Identifiable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let startDate: Date
    public let endDate: Date
    public let meetingURL: URL?

    public init(id: String = UUID().uuidString, title: String, startDate: Date, endDate: Date, meetingURL: URL? = nil) {
        self.id = id
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.meetingURL = meetingURL
    }

    public var minutesUntilStart: Int {
        Int(round(startDate.timeIntervalSince(Date()) / 60))
    }

    public var isHappeningNow: Bool {
        let now = Date()
        return startDate <= now && now <= endDate
    }

    public var formattedRelativeTime: String {
        if isHappeningNow {
            return "Now"
        }
        let mins = minutesUntilStart
        if mins < 60 {
            return "in \(max(1, mins))m"
        } else {
            let hrs = mins / 60
            let remainder = mins % 60
            return remainder > 0 ? "in \(hrs)h \(remainder)m" : "in \(hrs)h"
        }
    }
}

/// Synchronizes with macOS Calendar using EventKit to power the Notch Meeting Glancer.
@MainActor
public final class CalendarSyncService: ObservableObject {
    @Published public private(set) var upcomingMeetings: [CalendarMeetingItem] = []
    @Published public private(set) var nextMeeting: CalendarMeetingItem?
    @Published public private(set) var hasPermission: Bool = false

    private let eventStore = EKEventStore()
    private var refreshTimer: Timer?

    public init() {
        checkPermissionAndFetch()
        setupRecurringRefresh()
    }

    deinit {
        refreshTimer?.invalidate()
    }

    public func requestAccess() {
        if #available(macOS 14.0, *) {
            eventStore.requestFullAccessToEvents { [weak self] granted, _ in
                Task { @MainActor in
                    self?.hasPermission = granted
                    if granted {
                        self?.fetchUpcomingEvents()
                    }
                }
            }
        }
    }

    private func checkPermissionAndFetch() {
        let status = EKEventStore.authorizationStatus(for: .event)
        if #available(macOS 14.0, *) {
            self.hasPermission = (status == .fullAccess)
        } else {
            self.hasPermission = (status == .authorized)
        }

        if hasPermission {
            fetchUpcomingEvents()
        }
    }

    private func setupRecurringRefresh() {
        // Refresh every 2 minutes
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 120.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.fetchUpcomingEvents()
            }
        }
    }

    public func fetchUpcomingEvents() {
        guard hasPermission else { return }

        let now = Date()
        let endOfDay = Calendar.current.date(bySettingHour: 23, minute: 59, second: 59, of: now) ?? now.addingTimeInterval(86400)
        let predicate = eventStore.predicateForEvents(withStart: now.addingTimeInterval(-900), end: endOfDay, calendars: nil)
        let rawEvents = eventStore.events(matching: predicate)

        var meetings: [CalendarMeetingItem] = []

        for event in rawEvents {
            // Exclude all-day events from the immediate meeting alert
            guard !event.isAllDay else { continue }

            let url = extractMeetingLink(from: event)
            let item = CalendarMeetingItem(
                id: event.eventIdentifier ?? UUID().uuidString,
                title: event.title ?? "Meeting",
                startDate: event.startDate,
                endDate: event.endDate,
                meetingURL: url
            )
            meetings.append(item)
        }

        // Sort by start date
        meetings.sort { $0.startDate < $1.startDate }

        self.upcomingMeetings = meetings
        // Next meeting: within 30 minutes or happening now
        self.nextMeeting = meetings.first(where: { $0.isHappeningNow || $0.minutesUntilStart <= 30 })
    }

    public func joinMeeting(url: URL) {
        NSWorkspace.shared.open(url)
    }

    // MARK: - Video Link Extraction

    private func extractMeetingLink(from event: EKEvent) -> URL? {
        // Check event.url
        if let direct = event.url, isValidMeetingURL(direct) {
            return direct
        }

        // Search notes and location for meeting links
        let textSources = [event.location, event.notes].compactMap { $0 }
        for text in textSources {
            if let found = findFirstMeetingURL(in: text) {
                return found
            }
        }

        return event.url
    }

    private func isValidMeetingURL(_ url: URL) -> Bool {
        let str = url.absoluteString.lowercased()
        return str.contains("zoom.us/") ||
               str.contains("meet.google.com/") ||
               str.contains("teams.microsoft.com/") ||
               str.contains("webex.com/")
    }

    private func findFirstMeetingURL(in text: String) -> URL? {
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        let matches = detector?.matches(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count)) ?? []

        for match in matches {
            if let url = match.url, isValidMeetingURL(url) {
                return url
            }
        }
        return nil
    }
}
