import AppKit
import Foundation

/// Detects the presence and exact geometry of a MacBook camera housing/notch
/// using official macOS display APIs without hardcoding model names or dimensions.
public final class NotchDetector: Sendable {
    public static let shared = NotchDetector()

    public init() {}

    /// Detects camera notch geometry for a specific `NSScreen`.
    /// Returns `nil` if the screen does not feature a camera notch.
    public func detect(for screen: NSScreen) -> NotchGeometry? {
        let safeAreaInsets = screen.safeAreaInsets
        
        // Displays with a notch have safeAreaInsets.top > 0 and auxiliary areas defined.
        guard safeAreaInsets.top > 0,
              let topLeft = screen.auxiliaryTopLeftArea,
              let topRight = screen.auxiliaryTopRightArea else {
            return nil
        }
        
        // The notch sits between the right edge of auxiliaryTopLeftArea
        // and the left edge of auxiliaryTopRightArea.
        let notchWidth = topRight.minX - topLeft.maxX
        guard notchWidth > 0 else {
            return nil
        }
        
        let notchHeight = safeAreaInsets.top
        let notchOriginY = topLeft.minY
        let notchOriginX = topLeft.maxX
        
        let notchRect = NSRect(
            x: notchOriginX,
            y: notchOriginY,
            width: notchWidth,
            height: notchHeight
        )
        
        return NotchGeometry(
            screenFrame: screen.frame,
            screenVisibleFrame: screen.visibleFrame,
            notchRect: notchRect,
            safeAreaTop: notchHeight,
            auxiliaryTopLeft: topLeft,
            auxiliaryTopRight: topRight
        )
    }

    /// Finds the screen containing a camera notch among all connected screens.
    public func findNotchScreen(in screens: [NSScreen] = NSScreen.screens) -> (screen: NSScreen, geometry: NotchGeometry)? {
        for screen in screens {
            if let geometry = detect(for: screen) {
                return (screen, geometry)
            }
        }
        return nil
    }
}
