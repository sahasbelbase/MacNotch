import Foundation
import Combine

/// Provides minute-aligned time updates with near zero CPU overhead.
@MainActor
public final class TimeService: ObservableObject {
    @Published public private(set) var currentDate: Date = Date()
    private var timer: Timer?

    public init() {
        scheduleNextUpdate()
    }

    deinit {
        timer?.invalidate()
    }

    /// Schedules an update right at the next minute boundary, then repeats every 60 seconds.
    private func scheduleNextUpdate() {
        timer?.invalidate()

        let now = Date()
        let calendar = Calendar.current
        let seconds = calendar.component(.second, from: now)
        let nanoseconds = calendar.component(.nanosecond, from: now)
        let timeUntilNextMinute = Double(60 - seconds) - (Double(nanoseconds) / 1_000_000_000.0)

        timer = Timer.scheduledTimer(withTimeInterval: max(0.1, timeUntilNextMinute), repeats: false) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.currentDate = Date()
                self?.scheduleRecurringUpdate()
            }
        }
    }

    private func scheduleRecurringUpdate() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.currentDate = Date()
            }
        }
    }

    // MARK: - Formatted Strings

    public var shortTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter.string(from: currentDate)
    }

    public var dayOfWeek: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter.string(from: currentDate)
    }

    public var fullDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d"
        return formatter.string(from: currentDate)
    }

    public var fullTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: currentDate)
    }
}
