import XCTest
@testable import MacNotch
import AppKit

final class AdvancedFeaturesTests: XCTestCase {

    // MARK: - TimerService Tests

    @MainActor
    func testTimerServiceBasicOperations() {
        let timer = TimerService()
        XCTAssertFalse(timer.isRunning)
        XCTAssertFalse(timer.isPaused)

        // Start 25m Pomodoro
        timer.start(minutes: 25, mode: .pomodoro(minutes: 25))
        XCTAssertTrue(timer.isRunning)
        XCTAssertFalse(timer.isPaused)
        XCTAssertEqual(timer.formattedRemaining, "25:00")
        XCTAssertEqual(timer.progress, 0.0, accuracy: 0.01)

        // Pause
        timer.pause()
        XCTAssertTrue(timer.isPaused)
        XCTAssertTrue(timer.isRunning)

        // Resume
        timer.resume()
        XCTAssertFalse(timer.isPaused)
        XCTAssertTrue(timer.isRunning)

        // Reset
        timer.reset()
        XCTAssertFalse(timer.isRunning)
        XCTAssertFalse(timer.isPaused)
        XCTAssertEqual(timer.remainingSeconds, timer.totalSeconds)
    }

    @MainActor
    func testTimerModeTitles() {
        XCTAssertEqual(TimerMode.pomodoro(minutes: 25).title, "25m Focus")
        XCTAssertEqual(TimerMode.shortBreak(minutes: 5).title, "5m Break")
        XCTAssertEqual(TimerMode.custom(minutes: 15).title, "15m Timer")
    }

    // MARK: - Calendar Meeting Item Tests

    func testCalendarMeetingItemRelativeTimes() {
        let now = Date()

        // Ongoing meeting
        let ongoing = CalendarMeetingItem(
            title: "Sprint Planning",
            startDate: now.addingTimeInterval(-300),
            endDate: now.addingTimeInterval(1500),
            meetingURL: URL(string: "https://meet.google.com/abc-defg-hij")
        )
        XCTAssertTrue(ongoing.isHappeningNow)
        XCTAssertEqual(ongoing.formattedRelativeTime, "Now")
        XCTAssertNotNil(ongoing.meetingURL)

        // Future meeting in 15 mins
        let futureShort = CalendarMeetingItem(
            title: "1:1 Sync",
            startDate: now.addingTimeInterval(900),
            endDate: now.addingTimeInterval(2700),
            meetingURL: URL(string: "https://zoom.us/j/123456789")
        )
        XCTAssertFalse(futureShort.isHappeningNow)
        XCTAssertEqual(futureShort.formattedRelativeTime, "in 15m")

        // Future meeting in 2 hours
        let futureLong = CalendarMeetingItem(
            title: "All Hands",
            startDate: now.addingTimeInterval(7200),
            endDate: now.addingTimeInterval(10800)
        )
        XCTAssertFalse(futureLong.isHappeningNow)
        XCTAssertEqual(futureLong.formattedRelativeTime, "in 2h")
    }

    // MARK: - Bluetooth Accessory Service Tests

    @MainActor
    func testBluetoothAccessoryIconResolution() {
        let service = BluetoothAccessoryService()
        XCTAssertEqual(service.resolveAccessoryIcon(name: "User's AirPods Max"), "airpodsmax")
        XCTAssertEqual(service.resolveAccessoryIcon(name: "AirPods Pro - Left"), "airpodspro")
        XCTAssertEqual(service.resolveAccessoryIcon(name: "AirPods 3"), "airpods")
        XCTAssertEqual(service.resolveAccessoryIcon(name: "Beats Studio Pro"), "beats.headphones")
        XCTAssertEqual(service.resolveAccessoryIcon(name: "Sony WH-1000XM5"), "headphones")
        XCTAssertEqual(service.resolveAccessoryIcon(name: "Bose QC 45"), "headphones")
        XCTAssertEqual(service.resolveAccessoryIcon(name: "Generic Bluetooth Speaker"), "speaker.wave.2.fill")
    }

    func testAccessoryEventModel() {
        let event = AccessoryEvent(name: "AirPods Pro", icon: "airpodspro", batteryPercentage: 92)
        XCTAssertEqual(event.name, "AirPods Pro")
        XCTAssertEqual(event.icon, "airpodspro")
        XCTAssertEqual(event.batteryPercentage, 92)
    }

    // MARK: - QR Code Generator Tests

    func testQRCodeGenerator() {
        let qr = QRCodeService.shared
        let image = qr.generateQRCode(from: "https://github.com/sahasbelbase/MacNotch", size: 160)
        XCTAssertNotNil(image)
        XCTAssertEqual(image?.size.width, 160)
        XCTAssertEqual(image?.size.height, 160)

        let copied = qr.copyQRCodeToClipboard(from: "MacNotch Offline QR")
        XCTAssertTrue(copied)
    }

    // MARK: - Transient HUD Model Tests

    func testNewTransientHUDEquality() {
        let acc1 = TransientHUD.accessory(name: "AirPods", icon: "airpods", batteryPercentage: 85)
        let acc2 = TransientHUD.accessory(name: "AirPods", icon: "airpods", batteryPercentage: 85)
        let acc3 = TransientHUD.accessory(name: "Beats", icon: "headphones", batteryPercentage: 50)
        XCTAssertEqual(acc1, acc2)
        XCTAssertNotEqual(acc1, acc3)

        let notif1 = TransientHUD.notification(title: "Text Copied", subtitle: "Hello", icon: "text.viewfinder")
        let notif2 = TransientHUD.notification(title: "Text Copied", subtitle: "Hello", icon: "text.viewfinder")
        XCTAssertEqual(notif1, notif2)
    }
}
