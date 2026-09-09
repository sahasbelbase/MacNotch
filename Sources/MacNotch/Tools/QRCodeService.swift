import AppKit
import CoreImage
import Foundation

/// Fast offline QR Code generator using CoreImage CIFilter.
public final class QRCodeService {
    public static let shared = QRCodeService()

    private let context = CIContext()

    public init() {}

    /// Generates a crisp, high-resolution NSImage QR code from arbitrary text or URL string.
    public func generateQRCode(from string: String, size: CGFloat = 240) -> NSImage? {
        guard let filter = CIFilter(name: "CIQRCodeGenerator") else { return nil }
        guard let data = string.data(using: .utf8) else { return nil }

        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("M", forKey: "inputCorrectionLevel")

        guard let outputImage = filter.outputImage else { return nil }

        // Scale up crisply with nearest neighbor
        let extent = outputImage.extent
        let scale = size / extent.width
        let scaledImage = outputImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))

        guard let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) else {
            return nil
        }

        return NSImage(cgImage: cgImage, size: NSSize(width: size, height: size))
    }

    /// Copies generated QR Code image to system clipboard.
    public func copyQRCodeToClipboard(from string: String) -> Bool {
        guard let image = generateQRCode(from: string) else { return false }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        return pasteboard.writeObjects([image])
    }
}
