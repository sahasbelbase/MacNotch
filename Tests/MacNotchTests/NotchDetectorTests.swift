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

        // Collapsed Frame
        let collapsed = geometry.collapsedFrame(paddingX: 8, extraHeight: 8)
        XCTAssertEqual(collapsed.width, 221 + 16)
        XCTAssertEqual(collapsed.height, 38 + 8)
        XCTAssertEqual(collapsed.maxY, 1169)

        // Expanded Frame
        let expanded = geometry.expandedFrame(width: 580, height: 240)
        XCTAssertEqual(expanded.width, 580)
        XCTAssertEqual(expanded.height, 240)
        XCTAssertEqual(expanded.maxY, 1169)
        XCTAssertEqual(expanded.midX, notchRect.midX)

        // Activation Rect
        let activation = geometry.activationRect(extraBottomPadding: 12)
        XCTAssertEqual(activation.height, 38 + 12)
        XCTAssertEqual(activation.maxY, 1169)
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
