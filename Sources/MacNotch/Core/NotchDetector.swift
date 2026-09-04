import AppKit
import Foundation

/// Detects the presence, capabilities, and exact geometry of a MacBook camera housing/notch
/// using official macOS display APIs without hardcoding model names, dimensions, or resolutions.
public final class NotchDetector: Sendable {
    public static let shared = NotchDetector()

    public init() {}

    /// Evaluates display capabilities for a specific `NSScreen`.
    public func capabilities(for screen: NSScreen) -> DisplayCapabilities {
        DisplayCapabilities.evaluate(for: screen)
    }

    /// Detects camera notch geometry for a specific `NSScreen`.
    /// Returns `nil` if the screen does not feature a camera notch.
    public func detect(for screen: NSScreen) -> NotchGeometry? {
        let displayCapabilities = capabilities(for: screen)
        return NotchGeometry.compute(from: displayCapabilities, screenFrame: screen.frame)
    }

    /// Finds the screen containing a physical camera notch among all connected screens.
    /// In multi-monitor setups, this prioritizes the internal display with a notch.
    public func findNotchScreen(in screens: [NSScreen] = NSScreen.screens) -> (screen: NSScreen, geometry: NotchGeometry)? {
        for screen in screens {
            if let geometry = detect(for: screen) {
                return (screen, geometry)
            }
        }
        return nil
    }
}
