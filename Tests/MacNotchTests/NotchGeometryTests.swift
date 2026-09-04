import XCTest
@testable import MacNotch
import AppKit

final class NotchGeometryTests: XCTestCase {
    func testGeometryComputationOnNotchDisplay() {
        let frame = CGRect(x: 0, y: 0, width: 1800, height: 1169)
        let leftAux = CGRect(x: 0, y: 1131, width: 791, height: 38)
        let rightAux = CGRect(x: 1012, y: 1131, width: 788, height: 38)
        let cameraRect = CGRect(x: 791, y: 1131, width: 221, height: 38)
        let safeArea = CGRect(x: 0, y: 0, width: 1800, height: 1131)

        let caps = DisplayCapabilities(
            hasCameraNotch: true,
            cameraHousingRect: cameraRect,
            safeArea: safeArea,
            leftAuxiliaryArea: leftAux,
            rightAuxiliaryArea: rightAux,
            backingScaleFactor: 2.0
        )

        guard let geo = NotchGeometry.compute(from: caps, screenFrame: frame) else {
            XCTFail("Geometry computation failed for valid notch capabilities")
            return
        }

        XCTAssertTrue(geo.hasNotch)
        XCTAssertEqual(geo.cameraExclusionRect, cameraRect)

        // CRITICAL: Notch Embracing Invariant
        // The top of the collapsed panel and expanded panel sits flush at screenFrame.maxY
        // seamlessly embracing the physical camera notch like a native island.
        XCTAssertEqual(geo.collapsedRect.maxY, frame.maxY, "Collapsed panel embraces the notch from the top bezel")
        XCTAssertEqual(geo.expandedRect.maxY, frame.maxY, "Expanded panel embraces the notch from the top bezel")
        XCTAssertEqual(geo.collapsedRect.height, 42, "Collapsed chin height fits camera + 4pt padding")
        XCTAssertEqual(geo.collapsedRect.midX, cameraRect.midX, "Collapsed panel must be centered with camera")
        XCTAssertEqual(geo.expandedRect.midX, cameraRect.midX, "Expanded panel must be centered with camera")

        // Responsive Sizing: 1800 * 0.42 = 756
        XCTAssertEqual(geo.expandedRect.width, 756, accuracy: 1.0)
        XCTAssertGreaterThanOrEqual(geo.expandedRect.width, 680)
        XCTAssertLessThanOrEqual(geo.expandedRect.width, 840)

        // Activation Rect is strictly constrained to hardware camera bounds
        XCTAssertEqual(geo.activationRect, cameraRect)
    }

    func testResponsiveWidthOn16InchScreen() {
        // Simulated 16-inch MacBook Pro (typically 1728 wide in logical points)
        let frame = CGRect(x: 0, y: 0, width: 1728, height: 1117)
        let cameraRect = CGRect(x: 753, y: 1079, width: 222, height: 38)
        let caps = DisplayCapabilities(
            hasCameraNotch: true,
            cameraHousingRect: cameraRect,
            safeArea: CGRect(x: 0, y: 0, width: 1728, height: 1079),
            leftAuxiliaryArea: CGRect(x: 0, y: 1079, width: 753, height: 38),
            rightAuxiliaryArea: CGRect(x: 975, y: 1079, width: 753, height: 38),
            backingScaleFactor: 2.0
        )

        let geo = NotchGeometry.compute(from: caps, screenFrame: frame)!
        // 1728 * 0.42 = 725.76
        XCTAssertEqual(geo.expandedRect.width, 725.76, accuracy: 1.0)
        XCTAssertEqual(geo.expandedRect.maxY, 1117)
    }

    func testNonNotchDisplayReturnsNil() {
        let frame = CGRect(x: 0, y: 0, width: 1920, height: 1080)
        let caps = DisplayCapabilities(
            hasCameraNotch: false,
            cameraHousingRect: nil,
            safeArea: frame,
            leftAuxiliaryArea: nil,
            rightAuxiliaryArea: nil,
            backingScaleFactor: 1.0
        )

        let geo = NotchGeometry.compute(from: caps, screenFrame: frame)
        XCTAssertNil(geo, "Non-notch screen must return nil geometry so no fake notch is ever drawn")
    }
}
