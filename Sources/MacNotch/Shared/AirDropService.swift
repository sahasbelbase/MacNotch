import AppKit
import Foundation
import UniformTypeIdentifiers

/// Native macOS service providing seamless AirDrop sharing and Drag & Drop file handling.
public struct AirDropService {
    /// Shares files using macOS's built-in AirDrop sharing service.
    @MainActor
    public static func share(urls: [URL]) {
        guard !urls.isEmpty else { return }
        let sharingService = NSSharingService(named: .sendViaAirDrop)
        if sharingService?.canPerform(withItems: urls) == true {
            sharingService?.perform(withItems: urls)
        } else {
            // Fallback to standard sharing picker if direct AirDrop is restricted
            let picker = NSSharingServicePicker(items: urls)
            if let window = NSApp.keyWindow, let view = window.contentView {
                picker.show(relativeTo: view.bounds, of: view, preferredEdge: .maxY)
            }
        }
    }

    /// Extracts file URLs from drop NSItemProviders and initiates AirDrop.
    @MainActor
    public static func handleDroppedProviders(_ providers: [NSItemProvider], completion: (([URL]) -> Void)? = nil) {
        var collectedURLs: [URL] = []
        let group = DispatchGroup()

        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                group.enter()
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                    defer { group.leave() }
                    if let data = item as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) {
                        collectedURLs.append(url)
                    } else if let url = item as? URL {
                        collectedURLs.append(url)
                    }
                }
            }
        }

        group.notify(queue: .main) {
            guard !collectedURLs.isEmpty else { return }
            completion?(collectedURLs)
            self.share(urls: collectedURLs)
        }
    }
}
