import Foundation
import CoreGraphics

/// Provides explicit, verified coordinate space transformations between macOS screen, window, and SwiftUI coordinates.
///
/// Coordinate Space Characteristics:
/// 1. **NSScreen / Global Display Space**:
///    - Origin `(0, 0)` is at the bottom-left corner of the primary display.
///    - Positive X extends to the right.
///    - Positive Y extends upwards towards the top of the display.
///    - All window frames (`NSWindow.frame`), mouse locations (`NSEvent.mouseLocation`), and screen geometries are defined here.
///
/// 2. **NSWindow / NSPanel Content Space**:
///    - Origin `(0, 0)` is at the bottom-left corner of the window's content view.
///    - Positive X extends to the right.
///    - Positive Y extends upwards towards the top edge of the window.
///
/// 3. **SwiftUI Local View Space**:
///    - Origin `(0, 0)` is at the top-left corner of the hosting view/canvas.
///    - Positive X extends to the right.
///    - Positive Y extends downwards towards the bottom of the view.
public enum CoordinateConverter {
    /// Converts a point from global `NSScreen` coordinates to local `NSWindow` content coordinates.
    ///
    /// Since both systems have bottom-left origins and positive-Y pointing upwards,
    /// this is a pure translation by the window's origin:
    /// `windowX = screenX - windowOriginX`
    /// `windowY = screenY - windowOriginY`
    public static func convertScreenPointToWindowPoint(
        _ screenPoint: CGPoint,
        windowFrame: CGRect
    ) -> CGPoint {
        CGPoint(
            x: screenPoint.x - windowFrame.minX,
            y: screenPoint.y - windowFrame.minY
        )
    }

    /// Converts a rectangle from global `NSScreen` coordinates to local `NSWindow` content coordinates.
    public static func convertScreenRectToWindowRect(
        _ screenRect: CGRect,
        windowFrame: CGRect
    ) -> CGRect {
        CGRect(
            x: screenRect.minX - windowFrame.minX,
            y: screenRect.minY - windowFrame.minY,
            width: screenRect.width,
            height: screenRect.height
        )
    }

    /// Converts a rectangle from `NSWindow` content coordinates (bottom-left origin, Y-up)
    /// to `SwiftUI` view coordinates (top-left origin, Y-down).
    ///
    /// Derivation:
    /// In the window coordinate space, the top edge of the rect is at `windowRect.maxY`.
    /// The distance from the top of the window (`windowHeight`) down to the top edge of the rect is:
    /// `swiftUIY = windowHeight - windowRect.maxY`
    /// The width, height, and X coordinate remain unchanged.
    public static func convertWindowRectToSwiftUIRect(
        _ windowRect: CGRect,
        windowHeight: CGFloat
    ) -> CGRect {
        CGRect(
            x: windowRect.minX,
            y: windowHeight - windowRect.maxY,
            width: windowRect.width,
            height: windowRect.height
        )
    }

    /// Converts a rectangle from `SwiftUI` view coordinates (top-left origin, Y-down)
    /// to `NSWindow` content coordinates (bottom-left origin, Y-up).
    public static func convertSwiftUIRectToWindowRect(
        _ swiftUIRect: CGRect,
        windowHeight: CGFloat
    ) -> CGRect {
        CGRect(
            x: swiftUIRect.minX,
            y: windowHeight - swiftUIRect.maxY,
            width: swiftUIRect.width,
            height: swiftUIRect.height
        )
    }

    /// Converts directly from global `NSScreen` coordinates to local `SwiftUI` coordinates.
    public static func convertScreenRectToSwiftUIRect(
        _ screenRect: CGRect,
        windowFrame: CGRect
    ) -> CGRect {
        let windowRect = convertScreenRectToWindowRect(screenRect, windowFrame: windowFrame)
        return convertWindowRectToSwiftUIRect(windowRect, windowHeight: windowFrame.height)
    }
}
