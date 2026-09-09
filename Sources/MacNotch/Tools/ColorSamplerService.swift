import AppKit
import Foundation

/// System Color Eyedropper leveraging native NSColorSampler.
@MainActor
public final class ColorSamplerService {
    public static let shared = ColorSamplerService()

    public var onColorSampled: ((String, NSColor) -> Void)?

    public init() {}

    /// Initiates the native screen magnifying loupe to sample any pixel.
    public func sampleColor(completion: ((String, NSColor) -> Void)? = nil) {
        NSColorSampler().show { [weak self] sampledColor in
            guard let color = sampledColor?.usingColorSpace(NSColorSpace.sRGB) else { return }

            let r = Int(round(color.redComponent * 255))
            let g = Int(round(color.greenComponent * 255))
            let b = Int(round(color.blueComponent * 255))
            let hex = String(format: "#%02X%02X%02X", r, g, b)

            // Copy to general clipboard
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(hex, forType: .string)

            Task { @MainActor [weak self] in
                self?.onColorSampled?(hex, color)
                completion?(hex, color)
            }
        }
    }
}
