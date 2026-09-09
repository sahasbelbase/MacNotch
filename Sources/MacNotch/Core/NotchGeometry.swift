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

    /// Frame of the transient HUD overlay panel in screen coordinates, flanking the camera notch.
    public let hudRect: CGRect

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
        hudRect: CGRect? = nil,
        backingScaleFactor: CGFloat,
        hasNotch: Bool
    ) {
        self.screenFrame = screenFrame
        self.safeArea = safeArea
        self.cameraExclusionRect = cameraExclusionRect
        self.activationRect = activationRect
        self.collapsedRect = collapsedRect
        self.expandedRect = expandedRect
        self.hudRect = hudRect ?? collapsedRect
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

        // Responsive expanded width: 42% of display width, clamped to ensure camera notch and flanking ears
        // have generous width across all MacBook models (13" Air, 15" Air, 14" Pro, 16" Pro) and scaling modes.
        let calculatedWidth = screenFrame.width * 0.42
        let minWidth = max(680, cameraRect.width + 440)
        let responsiveWidth = min(max(calculatedWidth, minWidth), min(screenFrame.width - 40, 840))

        // Responsive expanded height: ~26% of display height, clamped between 280pt and 340pt
        let calculatedHeight = screenFrame.height * 0.26
        let responsiveHeight = min(max(calculatedHeight, 280), 340)

        // Collapsed chin height: fits the camera housing + subtle 4pt chin
        let collapsedHeight = cameraRect.height + 4
        let collapsedWidth = cameraRect.width + 24

        // ANCHOR POINT: The top of the MacNotch panel sits flush against the top edge of the screen
        // (screenFrame.maxY), seamlessly embracing the physical camera notch like a native island.
        let anchorTopY = screenFrame.maxY

        // Collapsed panel rect (screen coords: bottom-left origin)
        let collapsedX = cameraRect.midX - (collapsedWidth / 2)
        let collapsedY = anchorTopY - collapsedHeight
        let collapsedRect = CGRect(x: collapsedX, y: collapsedY, width: collapsedWidth, height: collapsedHeight)

        // Expanded panel rect (screen coords: bottom-left origin)
        let expandedX = cameraRect.midX - (responsiveWidth / 2)
        let expandedY = anchorTopY - responsiveHeight
        let expandedRect = CGRect(x: expandedX, y: expandedY, width: responsiveWidth, height: responsiveHeight)

        // Transient HUD panel rect (screen coords: bottom-left origin) - sleek wings flanking the notch
        let hudWidth = min(cameraRect.width + 160, min(responsiveWidth, screenFrame.width - 40))
        let hudHeight = cameraRect.height + 6
        let hudX = cameraRect.midX - (hudWidth / 2)
        let hudY = anchorTopY - hudHeight
        let hudRect = CGRect(x: hudX, y: hudY, width: hudWidth, height: hudHeight)

        // Activation hover rect: strictly constrained to the physical camera housing bounds.
        // It NEVER extends into the menu bar to the left/right or into windows below the camera.
        let activationRect = cameraRect

        return NotchGeometry(
            screenFrame: screenFrame,
            safeArea: capabilities.safeArea,
            cameraExclusionRect: cameraRect,
            activationRect: activationRect,
            collapsedRect: collapsedRect,
            expandedRect: expandedRect,
            hudRect: hudRect,
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
