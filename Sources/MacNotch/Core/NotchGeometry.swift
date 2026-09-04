import Foundation
import AppKit

/// Represents the geometric layout of the camera notch and related screen areas.
public struct NotchGeometry: Equatable, Sendable {
    /// The screen hosting the camera notch.
    public let screenFrame: NSRect
    public let screenVisibleFrame: NSRect
    
    /// The physical camera housing bounding rect in screen coordinates.
    public let notchRect: NSRect
    
    /// Top safe area inset (notch height).
    public let safeAreaTop: CGFloat
    
    /// The auxiliary area to the left of the notch (menu bar left).
    public let auxiliaryTopLeft: NSRect?
    
    /// The auxiliary area to the right of the notch (menu bar right).
    public let auxiliaryTopRight: NSRect?

    public init(
        screenFrame: NSRect,
        screenVisibleFrame: NSRect,
        notchRect: NSRect,
        safeAreaTop: CGFloat,
        auxiliaryTopLeft: NSRect?,
        auxiliaryTopRight: NSRect?
    ) {
        self.screenFrame = screenFrame
        self.screenVisibleFrame = screenVisibleFrame
        self.notchRect = notchRect
        self.safeAreaTop = safeAreaTop
        self.auxiliaryTopLeft = auxiliaryTopLeft
        self.auxiliaryTopRight = auxiliaryTopRight
    }

    /// The collapsed panel frame in screen coordinates.
    public func collapsedFrame(paddingX: CGFloat = 8, extraHeight: CGFloat = 8) -> NSRect {
        let width = notchRect.width + (paddingX * 2)
        let height = notchRect.height + extraHeight
        let x = notchRect.midX - (width / 2)
        let y = screenFrame.maxY - height
        return NSRect(x: x, y: y, width: width, height: height)
    }

    /// The expanded panel frame in screen coordinates.
    public func expandedFrame(width: CGFloat = DesignSystem.Dimensions.expandedWidth, height: CGFloat = DesignSystem.Dimensions.expandedHeight) -> NSRect {
        let x = notchRect.midX - (width / 2)
        let y = screenFrame.maxY - height
        return NSRect(x: x, y: y, width: width, height: height)
    }

    /// Activation hover trigger area in screen coordinates.
    public func activationRect(extraBottomPadding: CGFloat = 12) -> NSRect {
        let width = notchRect.width + 24
        let height = notchRect.height + extraBottomPadding
        let x = notchRect.midX - (width / 2)
        let y = screenFrame.maxY - height
        return NSRect(x: x, y: y, width: width, height: height)
    }
}
