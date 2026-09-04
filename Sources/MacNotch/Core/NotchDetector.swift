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
    /// Strictly filters to only physical built-in displays with a camera notch, ignoring all external monitors.
    public func findNotchScreen(in screens: [NSScreen] = NSScreen.screens) -> (screen: NSScreen, geometry: NotchGeometry)? {
        for screen in screens {
            let capabilities = capabilities(for: screen)
            guard capabilities.isBuiltin && capabilities.hasCameraNotch else {
                continue
            }
            if let geometry = NotchGeometry.compute(from: capabilities, screenFrame: screen.frame) {
                return (screen, geometry)
            }
        }
        return nil
    }
}
