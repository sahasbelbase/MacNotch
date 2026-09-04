import AppKit
import Foundation

/// Encapsulates the hardware display capabilities and camera obstruction characteristics of an `NSScreen`.
///
/// Differentiates between:
/// - Category A: Displays with a physical camera housing/notch creating a display obstruction.
/// - Category B: Laptops with cameras in the bezel that do NOT obstruct the display.
/// - Category C & D: Desktop Macs and external displays with no camera notch.
public struct DisplayCapabilities: Equatable, Sendable {
    /// Whether this display is the physical built-in MacBook screen (as opposed to an external monitor).
    public let isBuiltin: Bool

    /// Whether this display possesses a physical camera notch obstructing the display surface.
    public let hasCameraNotch: Bool

    /// The exact bounding rectangle of the physical camera housing in screen coordinates (if present).
    public let cameraHousingRect: CGRect?

    /// The unobstructed safe area of the screen.
    public let safeArea: CGRect

    /// The menu bar area to the left of the camera notch (if present).
    public let leftAuxiliaryArea: CGRect?

    /// The menu bar area to the right of the camera notch (if present).
    public let rightAuxiliaryArea: CGRect?

    /// The Retina backing scale factor of the screen (typically 2.0 for built-in Retina).
    public let backingScaleFactor: CGFloat

    public init(
        isBuiltin: Bool = true,
        hasCameraNotch: Bool,
        cameraHousingRect: CGRect?,
        safeArea: CGRect,
        leftAuxiliaryArea: CGRect?,
        rightAuxiliaryArea: CGRect?,
        backingScaleFactor: CGFloat
    ) {
        self.isBuiltin = isBuiltin
        self.hasCameraNotch = hasCameraNotch
        self.cameraHousingRect = cameraHousingRect
        self.safeArea = safeArea
        self.leftAuxiliaryArea = leftAuxiliaryArea
        self.rightAuxiliaryArea = rightAuxiliaryArea
        self.backingScaleFactor = backingScaleFactor
    }

    /// Determines whether the given screen is the physical built-in display of a Mac laptop.
    /// External monitors (HDMI, DisplayPort, Thunderbolt, AirPlay, Sidecar, etc.) return `false`.
    public static func isBuiltinDisplay(_ screen: NSScreen) -> Bool {
        if let num = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber {
            return CGDisplayIsBuiltin(CGDirectDisplayID(num.uint32Value)) != 0
        }
        if let displayID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID {
            return CGDisplayIsBuiltin(displayID) != 0
        }
        return false
    }

    /// Evaluates display geometry directly from Apple's official `NSScreen` APIs without hardcoded model names.
    public static func evaluate(for screen: NSScreen) -> DisplayCapabilities {
        let frame = screen.frame
        let insets = screen.safeAreaInsets
        let scale = screen.backingScaleFactor
        let isBuiltin = isBuiltinDisplay(screen)

        // Calculate safe area rectangle
        let safeArea = CGRect(
            x: frame.minX + insets.left,
            y: frame.minY + insets.bottom,
            width: max(0, frame.width - insets.left - insets.right),
            height: max(0, frame.height - insets.top - insets.bottom)
        )

        let auxLeft = screen.auxiliaryTopLeftArea
        let auxRight = screen.auxiliaryTopRightArea

        // CRITICAL PRODUCT REQUIREMENT:
        // An external monitor MUST NEVER host the notch UI.
        // A screen has a genuine physical camera notch if and only if:
        // 1. It is the physical built-in display of a portable Mac (isBuiltin == true)
        // 2. safeAreaInsets.top > 0 (menu bar is split around an obstruction)
        // 3. Both auxiliary top-left and top-right areas exist
        // 4. The auxiliary areas leave a positive, realistic gap between them (> 20pt)
        guard isBuiltin,
              insets.top > 0,
              let left = auxLeft,
              let right = auxRight,
              right.minX > left.maxX else {
            return DisplayCapabilities(
                isBuiltin: isBuiltin,
                hasCameraNotch: false,
                cameraHousingRect: nil,
                safeArea: safeArea,
                leftAuxiliaryArea: auxLeft,
                rightAuxiliaryArea: auxRight,
                backingScaleFactor: scale
            )
        }

        let notchWidth = right.minX - left.maxX
        guard notchWidth >= 20 else {
            return DisplayCapabilities(
                isBuiltin: isBuiltin,
                hasCameraNotch: false,
                cameraHousingRect: nil,
                safeArea: safeArea,
                leftAuxiliaryArea: auxLeft,
                rightAuxiliaryArea: auxRight,
                backingScaleFactor: scale
            )
        }

        let notchHeight = insets.top
        let notchOriginX = left.maxX
        let notchOriginY = left.minY

        let cameraRect = CGRect(
            x: notchOriginX,
            y: notchOriginY,
            width: notchWidth,
            height: notchHeight
        )

        return DisplayCapabilities(
            isBuiltin: isBuiltin,
            hasCameraNotch: true,
            cameraHousingRect: cameraRect,
            safeArea: safeArea,
            leftAuxiliaryArea: left,
            rightAuxiliaryArea: right,
            backingScaleFactor: scale
        )
    }
}
