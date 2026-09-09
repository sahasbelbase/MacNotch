import XCTest
@testable import MacNotch
import AppKit

@MainActor
final class HardwareDynamicsTests: XCTestCase {
    func testBatterySnapshotModel() {
        let snapshot = BatterySnapshot(
            hasBattery: true,
            percentage: 85,
            isCharging: true,
            isPluggedIn: true,
            timeToFullMinutes: 45,
            timeToEmptyMinutes: nil,
            isLowPower: false
        )

        XCTAssertTrue(snapshot.hasBattery)
        XCTAssertEqual(snapshot.percentage, 85)
        XCTAssertTrue(snapshot.isCharging)
        XCTAssertTrue(snapshot.isPluggedIn)
        XCTAssertEqual(snapshot.timeToFullMinutes, 45)
        XCTAssertNil(snapshot.timeToEmptyMinutes)
        XCTAssertFalse(snapshot.isLowPower)
    }

    func testBatteryServiceInitialization() {
        let service = BatteryService()
        // Should query current system state without crashing
        _ = service.snapshot.hasBattery
        _ = service.snapshot.percentage
        _ = service.snapshot.isCharging
        _ = service.snapshot.isPluggedIn

        XCTAssertGreaterThanOrEqual(service.snapshot.percentage, 0)
        XCTAssertLessThanOrEqual(service.snapshot.percentage, 100)
    }

    func testSystemHUDServiceInitialization() {
        let hudService = SystemHUDService()
        XCTAssertGreaterThanOrEqual(hudService.currentVolume, 0.0)
        XCTAssertLessThanOrEqual(hudService.currentVolume, 1.0)
        _ = hudService.isMuted
        _ = hudService.isCapsLockOn
    }

    func testNotchGeometryHUDRect() {
        let screenRect = CGRect(x: 0, y: 0, width: 1728, height: 1117)
        let safeArea = CGRect(x: 0, y: 0, width: 1728, height: 1083)
        let cameraRect = CGRect(x: 764, y: 1083, width: 200, height: 34)

        let capabilities = DisplayCapabilities(
            hasCameraNotch: true,
            cameraHousingRect: cameraRect,
            safeArea: safeArea,
            leftAuxiliaryArea: nil,
            rightAuxiliaryArea: nil,
            backingScaleFactor: 2.0
        )

        guard let geometry = NotchGeometry.compute(from: capabilities, screenFrame: screenRect) else {
            XCTFail("Failed to compute NotchGeometry")
            return
        }

        // Verify hudRect properties
        XCTAssertTrue(geometry.hudRect.width > cameraRect.width)
        XCTAssertEqual(geometry.hudRect.midX, cameraRect.midX, accuracy: 1.0)
        XCTAssertEqual(geometry.hudRect.maxY, screenRect.maxY, accuracy: 0.1)
    }

    func testTransientHUDEquality() {
        let batteryHUD1 = TransientHUD.battery(percentage: 90, isCharging: true, timeRemaining: "30m to full")
        let batteryHUD2 = TransientHUD.battery(percentage: 90, isCharging: true, timeRemaining: "30m to full")
        let batteryHUD3 = TransientHUD.battery(percentage: 90, isCharging: false, timeRemaining: nil)

        XCTAssertEqual(batteryHUD1, batteryHUD2)
        XCTAssertNotEqual(batteryHUD1, batteryHUD3)

        let volHUD1 = TransientHUD.volume(level: 0.8, isMuted: false)
        let volHUD2 = TransientHUD.volume(level: 0.8, isMuted: false)
        let volHUD3 = TransientHUD.volume(level: 0.8, isMuted: true)

        XCTAssertEqual(volHUD1, volHUD2)
        XCTAssertNotEqual(volHUD1, volHUD3)

        let caps1 = TransientHUD.capsLock(isOn: true)
        let caps2 = TransientHUD.capsLock(isOn: true)
        let caps3 = TransientHUD.capsLock(isOn: false)

        XCTAssertEqual(caps1, caps2)
        XCTAssertNotEqual(caps1, caps3)

        let kbHUD1 = TransientHUD.keyboardBrightness(level: 0.75)
        let kbHUD2 = TransientHUD.keyboardBrightness(level: 0.75)
        let kbHUD3 = TransientHUD.keyboardBrightness(level: 0.25)

        XCTAssertEqual(kbHUD1, kbHUD2)
        XCTAssertNotEqual(kbHUD1, kbHUD3)
    }

    func testKeyboardAndScreenBrightnessControls() {
        let hudService = SystemHUDService()
        var receivedKbLevel: Float?
        var receivedScrLevel: Float?

        hudService.onKeyboardBrightnessChange = { level in
            receivedKbLevel = level
        }
        hudService.onScreenBrightnessChange = { level in
            receivedScrLevel = level
        }

        hudService.setKeyboardBrightness(0.8)
        XCTAssertEqual(hudService.keyboardBrightness, 0.8, accuracy: 0.001)
        XCTAssertEqual(receivedKbLevel, 0.8)

        hudService.adjustKeyboardBrightness(delta: -0.2)
        XCTAssertEqual(hudService.keyboardBrightness, 0.6, accuracy: 0.001)

        hudService.setScreenBrightness(0.95)
        XCTAssertEqual(hudService.screenBrightness, 0.95, accuracy: 0.001)
        XCTAssertEqual(receivedScrLevel, 0.95)
    }
}
