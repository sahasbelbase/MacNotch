import AppKit
import SwiftUI

/// Visual diagnostic overlay window rendering exact geometry regions:
/// - RED: Camera / Notch Exclusion Rect
/// - BLUE: Mouse Activation Hover Rect
/// - GREEN: Collapsed Panel Rect
/// - PURPLE: Expanded Panel Rect
@MainActor
public final class GeometryOverlayWindow: NSPanel {
    public static let shared = GeometryOverlayWindow()

    public init() {
        super.init(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        self.isFloatingPanel = true
        self.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.maximumWindow)))
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = false
        self.ignoresMouseEvents = true
        self.becomesKeyOnlyIfNeeded = false
    }

    public func update(geometry: NotchGeometry?, isVisible: Bool) {
        guard isVisible, let geometry = geometry else {
            self.orderOut(nil)
            return
        }

        let screenFrame = geometry.screenFrame
        self.setFrame(screenFrame, display: true)

        let overlayView = GeometryOverlayView(geometry: geometry)
        let hostingView = NSHostingView(rootView: overlayView)
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = .clear
        self.contentView = hostingView

        if !self.isVisible {
            self.orderFrontRegardless()
        }
    }
}

public struct GeometryOverlayView: View {
    public let geometry: NotchGeometry

    public init(geometry: NotchGeometry) {
        self.geometry = geometry
    }

    public var body: some View {
        Canvas { context, size in
            let windowFrame = geometry.screenFrame

            // 1. BLUE: Activation Rect
            let activationViewRect = CoordinateConverter.convertScreenRectToSwiftUIRect(
                geometry.activationRect,
                windowFrame: windowFrame
            )
            context.fill(Path(activationViewRect), with: .color(Color.blue.opacity(0.18)))
            context.stroke(Path(activationViewRect), with: .color(Color.blue.opacity(0.8)), lineWidth: 2)

            // 2. PURPLE: Expanded Rect
            let expandedViewRect = CoordinateConverter.convertScreenRectToSwiftUIRect(
                geometry.expandedRect,
                windowFrame: windowFrame
            )
            context.fill(Path(expandedViewRect), with: .color(Color.purple.opacity(0.18)))
            context.stroke(Path(expandedViewRect), with: .color(Color.purple.opacity(0.85)), lineWidth: 2)

            // 3. GREEN: Collapsed Rect
            let collapsedViewRect = CoordinateConverter.convertScreenRectToSwiftUIRect(
                geometry.collapsedRect,
                windowFrame: windowFrame
            )
            context.fill(Path(collapsedViewRect), with: .color(Color.green.opacity(0.25)))
            context.stroke(Path(collapsedViewRect), with: .color(Color.green.opacity(0.9)), lineWidth: 2)

            // 4. RED: Camera Exclusion Rect
            if let cameraRect = geometry.cameraExclusionRect {
                let cameraViewRect = CoordinateConverter.convertScreenRectToSwiftUIRect(
                    cameraRect,
                    windowFrame: windowFrame
                )
                context.fill(Path(cameraViewRect), with: .color(Color.red.opacity(0.35)))
                context.stroke(Path(cameraViewRect), with: .color(Color.red), lineWidth: 2.5)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(
            VStack {
                HStack(spacing: 12) {
                    legendItem(color: .red, label: "Camera Exclusion")
                    legendItem(color: .blue, label: "Activation Hover")
                    legendItem(color: .green, label: "Collapsed Panel")
                    legendItem(color: .purple, label: "Expanded Panel")
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.black.opacity(0.85))
                .clipShape(Capsule())
                .padding(.top, 50)
                Spacer()
            }
        )
        .ignoresSafeArea()
    }

    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.white)
        }
    }
}
