import AppKit
import Foundation
import Vision

/// Instant Optical Character Recognition tool extracting text from any screen region.
@MainActor
public final class ScreenOCRService {
    public static let shared = ScreenOCRService()

    public var onTextRecognized: ((String) -> Void)?

    public init() {}

    /// Triggers interactive screen selection crosshairs, captures the image, and extracts text.
    public func captureAndRecognize(completion: ((String?) -> Void)? = nil) {
        let tempPath = "/tmp/macnotch_ocr_\(UUID().uuidString).png"

        // Execute screencapture in background thread
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
            process.arguments = ["-i", "-s", tempPath]

            do {
                try process.run()
                process.waitUntilExit()
            } catch {
                Task { @MainActor in
                    completion?(nil)
                }
                return
            }

            guard FileManager.default.fileExists(atPath: tempPath),
                  let image = NSImage(contentsOfFile: tempPath),
                  let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
                // User cancelled selection or error
                try? FileManager.default.removeItem(atPath: tempPath)
                Task { @MainActor in
                    completion?(nil)
                }
                return
            }

            // Cleanup temp file
            defer {
                try? FileManager.default.removeItem(atPath: tempPath)
            }

            // Run Vision OCR
            let request = VNRecognizeTextRequest { req, err in
                guard err == nil, let observations = req.results as? [VNRecognizedTextObservation] else {
                    Task { @MainActor in
                        completion?(nil)
                    }
                    return
                }

                let lines = observations.compactMap { $0.topCandidates(1).first?.string }
                let recognizedText = lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)

                guard !recognizedText.isEmpty else {
                    Task { @MainActor in
                        completion?(nil)
                    }
                    return
                }

                // Copy to clipboard
                DispatchQueue.main.async {
                    let pasteboard = NSPasteboard.general
                    pasteboard.clearContents()
                    pasteboard.setString(recognizedText, forType: .string)
                }

                Task { @MainActor [weak self] in
                    self?.onTextRecognized?(recognizedText)
                    completion?(recognizedText)
                }
            }

            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                Task { @MainActor in
                    completion?(nil)
                }
            }
        }
    }
}
