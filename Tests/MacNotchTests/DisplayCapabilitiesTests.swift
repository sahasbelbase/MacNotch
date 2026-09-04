import XCTest
@testable import MacNotch
import AppKit

final class DisplayCapabilitiesTests: XCTestCase {
    func testSimulatedNotchDisplayCapabilities() {
        // Simulated 14-inch MacBook Pro display
        let frame = CGRect(x: 0, y: 0, width: 1800, height: 1169)
        let insets = NSEdgeInsets(top: 38, left: 0, bottom: 0, right: 0)
        let leftAux = CGRect(x: 0, y: 1131, width: 791, height: 38)
        let rightAux = CGRect(x: 1012, y: 1131, width: 788, height: 38)

        let safeArea = CGRect(
            x: frame.minX + insets.left,
            y: frame.minY + insets.bottom,
            width: frame.width - insets.left - insets.right,
            height: frame.height - insets.top - insets.bottom
        )

        let notchWidth = rightAux.minX - leftAux.maxX
        let cameraRect = CGRect(x: leftAux.maxX, y: leftAux.minY, width: notchWidth, height: insets.top)

        let caps = DisplayCapabilities(
            hasCameraNotch: true,
            cameraHousingRect: cameraRect,
            safeArea: safeArea,
            leftAuxiliaryArea: leftAux,
            rightAuxiliaryArea: rightAux,
            backingScaleFactor: 2.0
        )

        XCTAssertTrue(caps.hasCameraNotch)
        XCTAssertEqual(caps.cameraHousingRect?.width, 221)
        XCTAssertEqual(caps.cameraHousingRect?.height, 38)
        XCTAssertEqual(caps.cameraHousingRect?.minX, 791)
        XCTAssertEqual(caps.cameraHousingRect?.minY, 1131)
        XCTAssertEqual(caps.cameraHousingRect?.maxY, 1169)
        XCTAssertEqual(caps.safeArea.height, 1131)
    }

    func testSimulatedNonNotchDisplayCapabilities() {
        // Simulated external 4K monitor or older MacBook without notch
        let frame = CGRect(x: 1800, y: 0, width: 3840, height: 2160)
        let insets = NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)

        let safeArea = CGRect(
            x: frame.minX + insets.left,
            y: frame.minY + insets.bottom,
            width: frame.width - insets.left - insets.right,
            height: frame.height - insets.top - insets.bottom
        )

        let caps = DisplayCapabilities(
            hasCameraNotch: false,
            cameraHousingRect: nil,
            safeArea: safeArea,
            leftAuxiliaryArea: nil,
            rightAuxiliaryArea: nil,
            backingScaleFactor: 2.0
        )

        XCTAssertFalse(caps.hasCameraNotch)
        XCTAssertNil(caps.cameraHousingRect)
        XCTAssertNil(caps.leftAuxiliaryArea)
        XCTAssertNil(caps.rightAuxiliaryArea)
        XCTAssertEqual(caps.safeArea, frame)
    }

    func testZeroOrNegativeNotchGapClassification() {
        // If auxiliary areas touch or overlap, no camera notch exists
        let frame = CGRect(x: 0, y: 0, width: 1440, height: 900)
        let insets = NSEdgeInsets(top: 24, left: 0, bottom: 0, right: 0)
        let leftAux = CGRect(x: 0, y: 876, width: 720, height: 24)
        let rightAux = CGRect(x: 720, y: 876, width: 720, height: 24) // gap is 0

        let safeArea = CGRect(x: 0, y: 0, width: 1440, height: 876)

        let notchWidth = rightAux.minX - leftAux.maxX
        let hasNotch = insets.top > 0 && notchWidth >= 20

        let caps = DisplayCapabilities(
            hasCameraNotch: hasNotch,
            cameraHousingRect: hasNotch ? CGRect(x: leftAux.maxX, y: leftAux.minY, width: notchWidth, height: insets.top) : nil,
            safeArea: safeArea,
            leftAuxiliaryArea: leftAux,
            rightAuxiliaryArea: rightAux,
            backingScaleFactor: 2.0
        )

        XCTAssertFalse(caps.hasCameraNotch)
        XCTAssertNil(caps.cameraHousingRect)
    }

    func testExternalMonitorExplicitlyRejectsNotch() {
        // Even if an external monitor had unusual safeAreaInsets, isBuiltin == false guarantees NO notch
        let frame = CGRect(x: 1800, y: 0, width: 2560, height: 1440)
        let leftAux = CGRect(x: 1800, y: 1400, width: 1100, height: 40)
        let rightAux = CGRect(x: 3000, y: 1400, width: 1360, height: 40)
        let safeArea = CGRect(x: 1800, y: 0, width: 2560, height: 1400)

        let caps = DisplayCapabilities(
            isBuiltin: false,
            hasCameraNotch: false,
            cameraHousingRect: nil,
            safeArea: safeArea,
            leftAuxiliaryArea: leftAux,
            rightAuxiliaryArea: rightAux,
            backingScaleFactor: 2.0
        )

        XCTAssertFalse(caps.isBuiltin)
        XCTAssertFalse(caps.hasCameraNotch)
        XCTAssertNil(caps.cameraHousingRect)

        // NotchGeometry computation must return nil for any external monitor
        let geo = NotchGeometry.compute(from: caps, screenFrame: frame)
        XCTAssertNil(geo, "Notch geometry must NEVER be created for an external monitor")
    }

    func testBuiltinScreenDetectionOnConnectedScreens() {
        // If NSScreen.screens contains the built-in display, verify isBuiltinDisplay works correctly
        for screen in NSScreen.screens {
            let isBuiltin = DisplayCapabilities.isBuiltinDisplay(screen)
            let caps = DisplayCapabilities.evaluate(for: screen)
            XCTAssertEqual(caps.isBuiltin, isBuiltin)
            if !isBuiltin {
                XCTAssertFalse(caps.hasCameraNotch, "External screen must never have camera notch")
                XCTAssertNil(caps.cameraHousingRect, "External screen must never have camera housing rect")
            }
        }
    }
}
