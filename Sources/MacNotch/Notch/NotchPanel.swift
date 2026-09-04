import AppKit
import SwiftUI

/// Borderless, transparent, non-activating floating panel tailored for the notch interface.
public final class NotchPanel: NSPanel {
    public init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        self.isFloatingPanel = true
        self.level = .statusBar
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = false
        self.ignoresMouseEvents = false
        self.becomesKeyOnlyIfNeeded = true
        self.isMovableByWindowBackground = false
        self.hidesOnDeactivate = false
    }

    override public var canBecomeKey: Bool {
        false
    }

    override public var canBecomeMain: Bool {
        false
    }
}
