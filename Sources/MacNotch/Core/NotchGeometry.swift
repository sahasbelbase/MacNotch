import Foundation
import AppKit

/// Centralized geometric model defining display bounds, camera housing exclusion,
/// mouse activation regions, and dynamic responsive panel dimensions.
public struct NotchGeometry: Equatable, Sendable {
    /// Full screen frame in global AppKit coordinates (bottom-left origin).
    public let screenFrame: CGRect

    /// Unobstructed safe area in global AppKit coordinates.
    public let safeArea: CGRect

    /// Physical camera housing exclusion rectangle in screen coordinates (nil if no notch exists).
    public let cameraExclusionRect: CGRect?

    /// Mouse hover activation region in screen coordinates.
    public let activationRect: CGRect

    /// Frame of the collapsed panel in screen coordinates, anchored cleanly below the camera housing.
    public let collapsedRect: CGRect

    /// Frame of the expanded utility panel in screen coordinates, anchored cleanly below the camera housing.
    public let expandedRect: CGRect

    /// Display backing scale factor (e.g. 2.0 for Retina).
    public let backingScaleFactor: CGFloat

    /// Whether this display actually has a physical camera notch.
    public let hasNotch: Bool

    public init(
        screenFrame: CGRect,
        safeArea: CGRect,
        cameraExclusionRect: CGRect?,
        activationRect: CGRect,
        collapsedRect: CGRect,
        expandedRect: CGRect,
        backingScaleFactor: CGFloat,
        hasNotch: Bool
    ) {
        self.screenFrame = screenFrame
        self.safeArea = safeArea
        self.cameraExclusionRect = cameraExclusionRect
        self.activationRect = activationRect
        self.collapsedRect = collapsedRect
        self.expandedRect = expandedRect
        self.backingScaleFactor = backingScaleFactor
        self.hasNotch = hasNotch
    }

    /// Backward-compatible initializer for legacy tests.
    public init(
        screenFrame: NSRect,
        screenVisibleFrame: NSRect = .zero,
        notchRect: NSRect,
        safeAreaTop: CGFloat,
        auxiliaryTopLeft: NSRect? = nil,
        auxiliaryTopRight: NSRect? = nil
    ) {
        let safeArea = CGRect(x: screenFrame.minX, y: screenFrame.minY, width: screenFrame.width, height: screenFrame.height - safeAreaTop)
        let capabilities = DisplayCapabilities(
            hasCameraNotch: true,
            cameraHousingRect: notchRect,
            safeArea: safeArea,
            leftAuxiliaryArea: auxiliaryTopLeft,
            rightAuxiliaryArea: auxiliaryTopRight,
            backingScaleFactor: 2.0
        )
        if let computed = NotchGeometry.compute(from: capabilities, screenFrame: screenFrame) {
            self = computed
        } else {
            self.init(
                screenFrame: screenFrame,
                safeArea: safeArea,
                cameraExclusionRect: notchRect,
                activationRect: notchRect,
                collapsedRect: notchRect,
                expandedRect: notchRect,
                backingScaleFactor: 2.0,
                hasNotch: true
            )
        }
    }

    /// Computes notch geometry from evaluated display capabilities.
    public static func compute(from capabilities: DisplayCapabilities, screenFrame: CGRect) -> NotchGeometry? {
        guard capabilities.hasCameraNotch, let cameraRect = capabilities.cameraHousingRect else {
            return nil
        }

        // Responsive expanded width: 40% to 45% of display width, clamped between 680pt and 840pt
        let calculatedWidth = screenFrame.width * 0.42
        let responsiveWidth = min(max(calculatedWidth, 680), min(screenFrame.width - 80, 840))

        // Responsive expanded height: ~26% of display height, clamped between 280pt and 330pt
        let calculatedHeight = screenFrame.height * 0.26
        let responsiveHeight = min(max(calculatedHeight, 280), 330)

        // Collapsed chin height: 10pt subtle tab sitting directly below the camera housing
        let collapsedHeight: CGFloat = 10
        let collapsedWidth: CGFloat = cameraRect.width + 16

        // ANCHOR POINT: The top of the MacNotch panel sits flush immediately below the camera housing
        // (i.e. at cameraRect.minY). This GUARANTEES the camera lens/housing is NEVER covered.
        let anchorTopY = cameraRect.minY

        // Collapsed panel rect (screen coords: bottom-left origin)
        let collapsedX = cameraRect.midX - (collapsedWidth / 2)
        let collapsedY = anchorTopY - collapsedHeight
        let collapsedRect = CGRect(x: collapsedX, y: collapsedY, width: collapsedWidth, height: collapsedHeight)

        // Expanded panel rect (screen coords: bottom-left origin)
        let expandedX = cameraRect.midX - (responsiveWidth / 2)
        let expandedY = anchorTopY - responsiveHeight
        let expandedRect = CGRect(x: expandedX, y: expandedY, width: responsiveWidth, height: responsiveHeight)

        // Activation hover rect: covers the physical camera area plus the collapsed chin + safety margin
        let activationExtraPadding: CGFloat = 12
        let activationX = cameraRect.midX - (cameraRect.width / 2 + 16)
        let activationWidth = cameraRect.width + 32
        let activationMinY = collapsedY - activationExtraPadding
        let activationMaxY = screenFrame.maxY
        let activationHeight = activationMaxY - activationMinY
        let activationRect = CGRect(x: activationX, y: activationMinY, width: activationWidth, height: activationHeight)

        return NotchGeometry(
            screenFrame: screenFrame,
            safeArea: capabilities.safeArea,
            cameraExclusionRect: cameraRect,
            activationRect: activationRect,
            collapsedRect: collapsedRect,
            expandedRect: expandedRect,
            backingScaleFactor: capabilities.backingScaleFactor,
            hasNotch: true
        )
    }

    // MARK: - Backward Compatibility & Convenience Accessors

    /// The physical camera housing bounding rect in screen coordinates (non-optional alias).
    public var notchRect: CGRect {
        cameraExclusionRect ?? .zero
    }

    public var safeAreaTop: CGFloat {
        cameraExclusionRect?.height ?? 0
    }

    public func collapsedFrame(paddingX: CGFloat = 8, extraHeight: CGFloat = 8) -> CGRect {
        collapsedRect
    }

    public func expandedFrame(width: CGFloat? = nil, height: CGFloat? = nil) -> CGRect {
        guard let width = width, let height = height else {
            return expandedRect
        }
        let topY = cameraExclusionRect?.minY ?? (screenFrame.maxY - (height))
        let midX = cameraExclusionRect?.midX ?? screenFrame.midX
        let x = midX - (width / 2)
        let y = topY - height
        return CGRect(x: x, y: y, width: width, height: height)
    }

    public func activationRect(extraBottomPadding: CGFloat = 12) -> CGRect {
        activationRect
    }
}
