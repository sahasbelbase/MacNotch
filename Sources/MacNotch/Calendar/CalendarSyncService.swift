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
    public let isGoogleCalendar: Bool
    public let accountName: String?

    public init(
        id: String = UUID().uuidString,
        title: String,
        startDate: Date,
        endDate: Date,
        meetingURL: URL? = nil,
        isGoogleCalendar: Bool = false,
        accountName: String? = nil
    ) {
        self.id = id
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.meetingURL = meetingURL
        self.isGoogleCalendar = isGoogleCalendar
        self.accountName = accountName
    }

    public var isGoogleMeet: Bool {
        guard let url = meetingURL else { return false }
        return url.absoluteString.lowercased().contains("meet.google.com")
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

/// Synchronizes with macOS Calendar (EventKit) and Google Calendar feeds to power the Notch Meeting Glancer.
@MainActor
public final class CalendarSyncService: ObservableObject {
    @Published public private(set) var upcomingMeetings: [CalendarMeetingItem] = []
    @Published public private(set) var nextMeeting: CalendarMeetingItem?
    @Published public private(set) var hasPermission: Bool = false
    @Published public private(set) var detectedGoogleAccount: String? = nil
    @Published public private(set) var isGoogleSyncActive: Bool = false
    @Published public private(set) var isSyncingGoogleICal: Bool = false
    @Published public private(set) var lastSyncDate: Date? = nil

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

        fetchUpcomingEvents()
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
        var meetings: [CalendarMeetingItem] = []
        var googleAccountFound: String? = nil

        if hasPermission {
            // Check connected calendars for Google accounts
            let calendars = eventStore.calendars(for: .event)
            for cal in calendars {
                let title = cal.title.lowercased()
                let sourceTitle = cal.source.title.lowercased()
                if title.contains("google") || title.contains("gmail") || sourceTitle.contains("google") || sourceTitle.contains("gmail") {
                    googleAccountFound = cal.source.title.isEmpty ? cal.title : cal.source.title
                    break
                }
            }

            let now = Date()
            let endOfDay = Calendar.current.date(bySettingHour: 23, minute: 59, second: 59, of: now) ?? now.addingTimeInterval(86400)
            let predicate = eventStore.predicateForEvents(withStart: now.addingTimeInterval(-900), end: endOfDay, calendars: nil)
            let rawEvents = eventStore.events(matching: predicate)

            for event in rawEvents {
                guard !event.isAllDay else { continue }

                let url = extractMeetingLink(from: event)
                let calSource = event.calendar?.source.title ?? ""
                let isGoogle = calSource.localizedCaseInsensitiveContains("google")
                    || calSource.localizedCaseInsensitiveContains("gmail")
                    || (event.calendar?.title ?? "").localizedCaseInsensitiveContains("google")
                    || (event.calendar?.title ?? "").localizedCaseInsensitiveContains("gmail")

                let item = CalendarMeetingItem(
                    id: event.eventIdentifier ?? UUID().uuidString,
                    title: event.title ?? "Meeting",
                    startDate: event.startDate,
                    endDate: event.endDate,
                    meetingURL: url,
                    isGoogleCalendar: isGoogle,
                    accountName: isGoogle ? (calSource.isEmpty ? "Google Calendar" : calSource) : nil
                )
                meetings.append(item)
            }
        }

        self.detectedGoogleAccount = googleAccountFound
        self.isGoogleSyncActive = (googleAccountFound != nil)

        // If user provided a direct Google Calendar secret iCal URL in SettingsStore, sync it asynchronously
        let settings = SettingsStore.shared
        if settings.googleCalendarEnabled && !settings.googleCalendarICalURL.isEmpty {
            Task { [weak self] in
                guard let self = self else { return }
                await self.fetchGoogleICalFeed(urlString: settings.googleCalendarICalURL, existingMeetings: meetings)
            }
        } else {
            finalizeMeetings(meetings)
        }
    }

    /// Fetches and parses a Google Calendar private/secret address in iCal (.ics) format.
    public func fetchGoogleICalFeed(urlString: String, existingMeetings: [CalendarMeetingItem]? = nil) async {
        guard let url = URL(string: urlString.trimmingCharacters(in: .whitespacesAndNewlines)) else { return }

        self.isSyncingGoogleICal = true

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode),
                  let icsString = String(data: data, encoding: .utf8) else {
                self.isSyncingGoogleICal = false
                return
            }

            let now = Date()
            let endOfDay = Calendar.current.date(bySettingHour: 23, minute: 59, second: 59, of: now) ?? now.addingTimeInterval(86400)
            let parsedEvents = ICalParser.parse(icsString: icsString, fromDate: now.addingTimeInterval(-1800), toDate: endOfDay)
            var merged = existingMeetings ?? self.upcomingMeetings

            for event in parsedEvents {
                // Deduplicate by title & start time
                if !merged.contains(where: { abs($0.startDate.timeIntervalSince(event.startDate)) < 60 && $0.title == event.title }) {
                    merged.append(event)
                }
            }

            self.isGoogleSyncActive = true
            if self.detectedGoogleAccount == nil {
                self.detectedGoogleAccount = "Google Calendar (iCal Feed)"
            }
            self.lastSyncDate = Date()
            self.isSyncingGoogleICal = false
            finalizeMeetings(merged)
        } catch {
            self.isSyncingGoogleICal = false
        }
    }

    private func finalizeMeetings(_ meetings: [CalendarMeetingItem]) {
        var sorted = meetings
        sorted.sort { $0.startDate < $1.startDate }

        self.upcomingMeetings = sorted
        self.nextMeeting = sorted.first(where: { $0.isHappeningNow || $0.minutesUntilStart <= 30 })
    }

    public func joinMeeting(url: URL) {
        NSWorkspace.shared.open(url)
    }

    // MARK: - Navigation Helpers

    /// Opens macOS Internet Accounts preferences so user can link their Google account.
    public func openSystemInternetAccounts() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.Internet-Accounts-Settings.extension") {
            NSWorkspace.shared.open(url)
        } else if let fallback = URL(string: "x-apple.systempreferences:com.apple.preferences.internetaccounts") {
            NSWorkspace.shared.open(fallback)
        }
    }

    public func openGoogleInternetAccountsSettings() {
        openSystemInternetAccounts()
    }

    /// Opens Google Calendar in web browser.
    public func openGoogleCalendarWeb() {
        if let url = URL(string: "https://calendar.google.com") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - Video Link Extraction

    private func extractMeetingLink(from event: EKEvent) -> URL? {
        if let direct = event.url, isValidMeetingURL(direct) {
            return direct
        }

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

// MARK: - Lightweight RFC 5545 iCal Parser for Google Calendar

public enum ICalParser {
    public static func parse(icsString: String, fromDate: Date? = nil, toDate: Date? = nil) -> [CalendarMeetingItem] {
        var items: [CalendarMeetingItem] = []

        // Unfold lines that continue with a whitespace
        let unfolded = icsString.replacingOccurrences(of: "\r\n ", with: "")
            .replacingOccurrences(of: "\n ", with: "")
            .replacingOccurrences(of: "\r\n\t", with: "")
            .replacingOccurrences(of: "\n\t", with: "")

        let rawLines = unfolded.components(separatedBy: .newlines)
        var insideVEvent = false

        var currentSummary: String = ""
        var currentStart: Date? = nil
        var currentEnd: Date? = nil
        var currentDescription: String = ""
        var currentLocation: String = ""
        var currentUID: String = UUID().uuidString

        for line in rawLines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed == "BEGIN:VEVENT" {
                insideVEvent = true
                currentSummary = "Google Calendar Event"
                currentStart = nil
                currentEnd = nil
                currentDescription = ""
                currentLocation = ""
                currentUID = UUID().uuidString
            } else if trimmed == "END:VEVENT" {
                insideVEvent = false
                if let start = currentStart, let end = currentEnd ?? currentStart?.addingTimeInterval(3600) {
                    var inRange = true
                    if let fromDate = fromDate, start < fromDate { inRange = false }
                    if let toDate = toDate, start > toDate { inRange = false }

                    if inRange {
                        let meetingURL = extractURL(from: "\(currentDescription) \(currentLocation)")
                        let item = CalendarMeetingItem(
                            id: currentUID,
                            title: currentSummary,
                            startDate: start,
                            endDate: end,
                            meetingURL: meetingURL,
                            isGoogleCalendar: true,
                            accountName: "Google Calendar"
                        )
                        items.append(item)
                    }
                }
            } else if insideVEvent {
                if trimmed.hasPrefix("SUMMARY:") {
                    currentSummary = String(trimmed.dropFirst(8))
                } else if trimmed.hasPrefix("UID:") {
                    currentUID = String(trimmed.dropFirst(4))
                } else if trimmed.hasPrefix("DESCRIPTION:") {
                    currentDescription = String(trimmed.dropFirst(12))
                } else if trimmed.hasPrefix("LOCATION:") {
                    currentLocation = String(trimmed.dropFirst(9))
                } else if trimmed.hasPrefix("DTSTART") {
                    currentStart = parseICalDate(from: trimmed)
                } else if trimmed.hasPrefix("DTEND") {
                    currentEnd = parseICalDate(from: trimmed)
                }
            }
        }

        return items
    }

    private static func parseICalDate(from line: String) -> Date? {
        guard let colonIndex = line.firstIndex(of: ":") else { return nil }
        let dateStr = String(line[line.index(after: colonIndex)...]).trimmingCharacters(in: .whitespaces)

        let posixLocale = Locale(identifier: "en_US_POSIX")

        let utcFormatter = DateFormatter()
        utcFormatter.locale = posixLocale
        utcFormatter.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
        utcFormatter.timeZone = TimeZone(secondsFromGMT: 0)

        if let d = utcFormatter.date(from: dateStr) {
            return d
        }

        let localFormatter = DateFormatter()
        localFormatter.locale = posixLocale
        localFormatter.dateFormat = "yyyyMMdd'T'HHmmss"
        if let d = localFormatter.date(from: dateStr) {
            return d
        }

        let dayFormatter = DateFormatter()
        dayFormatter.locale = posixLocale
        dayFormatter.dateFormat = "yyyyMMdd"
        return dayFormatter.date(from: dateStr)
    }

    private static func extractURL(from text: String) -> URL? {
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        let matches = detector?.matches(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count)) ?? []

        for match in matches {
            if let url = match.url {
                let str = url.absoluteString.lowercased()
                if str.contains("meet.google.com/") || str.contains("zoom.us/") || str.contains("teams.microsoft.com/") {
                    return url
                }
            }
        }
        return nil
    }
}
