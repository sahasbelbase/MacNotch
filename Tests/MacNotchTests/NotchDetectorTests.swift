import XCTest
@testable import MacNotch
import AppKit

final class NotchDetectorTests: XCTestCase {
    func testNotchGeometryCalculations() {
        let screenFrame = NSRect(x: 0, y: 0, width: 1800, height: 1169)
        let visibleFrame = NSRect(x: 0, y: 60, width: 1800, height: 1070)
        let notchRect = NSRect(x: 791, y: 1131, width: 221, height: 38)
        let safeAreaTop: CGFloat = 38
        let topLeft = NSRect(x: 0, y: 1131, width: 791, height: 38)
        let topRight = NSRect(x: 1012, y: 1131, width: 788, height: 38)

        let geometry = NotchGeometry(
            screenFrame: screenFrame,
            screenVisibleFrame: visibleFrame,
            notchRect: notchRect,
            safeAreaTop: safeAreaTop,
            auxiliaryTopLeft: topLeft,
            auxiliaryTopRight: topRight
        )

        // Collapsed Frame sits directly below the camera housing (never covering it)
        let collapsed = geometry.collapsedFrame()
        XCTAssertEqual(collapsed.width, 221 + 16)
        XCTAssertEqual(collapsed.height, 10)
        XCTAssertEqual(collapsed.maxY, 1131, "Collapsed panel top must be at camera bottom (1131) so camera is never covered")
        XCTAssertEqual(collapsed.minY, 1121)

        // Expanded Frame expands downward from immediately below the camera housing
        let expanded = geometry.expandedFrame()
        XCTAssertEqual(expanded.maxY, 1131, "Expanded panel top must be at camera bottom (1131) so camera is never covered")
        XCTAssertEqual(expanded.midX, notchRect.midX)
        XCTAssertGreaterThan(expanded.width, 600, "Expanded width must be wide and spacious")

        // Activation Rect covers camera housing (1131..1169) plus collapsed chin
        let activation = geometry.activationRect()
        XCTAssertEqual(activation.maxY, 1169, "Activation zone extends up to top of screen")
        XCTAssertLessThan(activation.minY, collapsed.minY, "Activation zone extends down past collapsed chin")
    }

    func testNotchDetectionOnCurrentDevice() {
        // If running on a MacBook with a notch, detect(for:) must return a valid NotchGeometry
        if let main = NSScreen.main, main.safeAreaInsets.top > 0, main.auxiliaryTopLeftArea != nil {
            let detector = NotchDetector.shared
            let detected = detector.detect(for: main)
            XCTAssertNotNil(detected)
            XCTAssertGreaterThan(detected!.notchRect.width, 0)
            XCTAssertEqual(detected!.notchRect.height, main.safeAreaInsets.top)
        }
    }
}
