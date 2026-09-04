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
        self.becomesKeyOnlyIfNeeded = false
        self.isMovableByWindowBackground = false
        self.hidesOnDeactivate = false
    }

    override public var canBecomeKey: Bool {
        true
    }

    override public var canBecomeMain: Bool {
        true
    }

    override public var acceptsFirstResponder: Bool {
        true
    }

    override public func sendEvent(_ event: NSEvent) {
        if event.type == .leftMouseDown && !isKeyWindow {
            makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
        super.sendEvent(event)
    }

    override public func mouseDown(with event: NSEvent) {
        if !isKeyWindow {
            makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
        super.mouseDown(with: event)
    }
}
