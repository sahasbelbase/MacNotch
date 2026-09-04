import AppKit
import Foundation

/// Encapsulates the hardware display capabilities and camera obstruction characteristics of an `NSScreen`.
///
/// Differentiates between:
/// - Category A: Displays with a physical camera housing/notch creating a display obstruction.
/// - Category B: Laptops with cameras in the bezel that do NOT obstruct the display.
/// - Category C & D: Desktop Macs and external displays with no camera notch.
public struct DisplayCapabilities: Equatable, Sendable {
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
        hasCameraNotch: Bool,
        cameraHousingRect: CGRect?,
        safeArea: CGRect,
        leftAuxiliaryArea: CGRect?,
        rightAuxiliaryArea: CGRect?,
        backingScaleFactor: CGFloat
    ) {
        self.hasCameraNotch = hasCameraNotch
        self.cameraHousingRect = cameraHousingRect
        self.safeArea = safeArea
        self.leftAuxiliaryArea = leftAuxiliaryArea
        self.rightAuxiliaryArea = rightAuxiliaryArea
        self.backingScaleFactor = backingScaleFactor
    }

    /// Evaluates display geometry directly from Apple's official `NSScreen` APIs without hardcoded model names.
    public static func evaluate(for screen: NSScreen) -> DisplayCapabilities {
        let frame = screen.frame
        let insets = screen.safeAreaInsets
        let scale = screen.backingScaleFactor

        // Calculate safe area rectangle
        let safeArea = CGRect(
            x: frame.minX + insets.left,
            y: frame.minY + insets.bottom,
            width: max(0, frame.width - insets.left - insets.right),
            height: max(0, frame.height - insets.top - insets.bottom)
        )

        let auxLeft = screen.auxiliaryTopLeftArea
        let auxRight = screen.auxiliaryTopRightArea

        // A screen has a genuine physical camera notch if and only if:
        // 1. safeAreaInsets.top > 0 (menu bar is split around an obstruction)
        // 2. Both auxiliary top-left and top-right areas exist
        // 3. The auxiliary areas leave a positive, realistic gap between them (> 20pt)
        guard insets.top > 0,
              let left = auxLeft,
              let right = auxRight,
              right.minX > left.maxX else {
            return DisplayCapabilities(
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
            hasCameraNotch: true,
            cameraHousingRect: cameraRect,
            safeArea: safeArea,
            leftAuxiliaryArea: left,
            rightAuxiliaryArea: right,
            backingScaleFactor: scale
        )
    }
}
