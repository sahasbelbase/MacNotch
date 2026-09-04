import XCTest
@testable import MacNotch
import CoreGraphics

final class CoordinateConverterTests: XCTestCase {
    func testScreenPointToWindowPoint() {
        let windowFrame = CGRect(x: 500, y: 800, width: 700, height: 300)
        let screenPoint = CGPoint(x: 550, y: 850)

        let windowPoint = CoordinateConverter.convertScreenPointToWindowPoint(screenPoint, windowFrame: windowFrame)
        XCTAssertEqual(windowPoint.x, 50)
        XCTAssertEqual(windowPoint.y, 50)
    }

    func testScreenRectToWindowRect() {
        let windowFrame = CGRect(x: 500, y: 800, width: 700, height: 300)
        let screenRect = CGRect(x: 520, y: 810, width: 100, height: 50)

        let windowRect = CoordinateConverter.convertScreenRectToWindowRect(screenRect, windowFrame: windowFrame)
        XCTAssertEqual(windowRect.origin.x, 20)
        XCTAssertEqual(windowRect.origin.y, 10)
        XCTAssertEqual(windowRect.size.width, 100)
        XCTAssertEqual(windowRect.size.height, 50)
    }

    func testWindowRectToSwiftUIRect() {
        let windowHeight: CGFloat = 300
        // A rect at the top of the window in AppKit (Y-up)
        // Its bottom edge is at y=250, height=50, so its top edge is at y=300 (the very top)
        let windowRect = CGRect(x: 10, y: 250, width: 200, height: 50)

        let swiftUIRect = CoordinateConverter.convertWindowRectToSwiftUIRect(windowRect, windowHeight: windowHeight)
        // In SwiftUI (Y-down), the top edge of this rect is at y=0
        XCTAssertEqual(swiftUIRect.origin.x, 10)
        XCTAssertEqual(swiftUIRect.origin.y, 0)
        XCTAssertEqual(swiftUIRect.size.width, 200)
        XCTAssertEqual(swiftUIRect.size.height, 50)
    }

    func testSwiftUIRectToWindowRect() {
        let windowHeight: CGFloat = 300
        let swiftUIRect = CGRect(x: 10, y: 0, width: 200, height: 50)

        let windowRect = CoordinateConverter.convertSwiftUIRectToWindowRect(swiftUIRect, windowHeight: windowHeight)
        XCTAssertEqual(windowRect.origin.x, 10)
        XCTAssertEqual(windowRect.origin.y, 250)
        XCTAssertEqual(windowRect.size.width, 200)
        XCTAssertEqual(windowRect.size.height, 50)
    }

    func testRoundTripInvariance() {
        let windowHeight: CGFloat = 400
        let initialWindowRect = CGRect(x: 45, y: 120, width: 150, height: 80)

        let swiftUIRect = CoordinateConverter.convertWindowRectToSwiftUIRect(initialWindowRect, windowHeight: windowHeight)
        let roundTripWindowRect = CoordinateConverter.convertSwiftUIRectToWindowRect(swiftUIRect, windowHeight: windowHeight)

        XCTAssertEqual(roundTripWindowRect, initialWindowRect)
    }

    func testDirectScreenToSwiftUIRect() {
        let windowFrame = CGRect(x: 100, y: 500, width: 600, height: 200)
        // A screen rect at the top-left of the window: x=100, y=650..700
        let screenRect = CGRect(x: 100, y: 650, width: 300, height: 50)

        let swiftUIRect = CoordinateConverter.convertScreenRectToSwiftUIRect(screenRect, windowFrame: windowFrame)
        XCTAssertEqual(swiftUIRect.origin.x, 0)
        XCTAssertEqual(swiftUIRect.origin.y, 0)
        XCTAssertEqual(swiftUIRect.size.width, 300)
        XCTAssertEqual(swiftUIRect.size.height, 50)
    }
}
