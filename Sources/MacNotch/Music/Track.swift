import Foundation
import AppKit

/// Represents a media track currently being played on the system.
public struct Track: Equatable, Sendable {
    public let id: String
    public let title: String
    public let artist: String
    public let album: String
    public let artworkData: Data?
    public let duration: TimeInterval?
    public let playerPosition: TimeInterval?

    public init(
        id: String = UUID().uuidString,
        title: String,
        artist: String,
        album: String = "",
        artworkData: Data? = nil,
        duration: TimeInterval? = nil,
        playerPosition: TimeInterval? = nil
    ) {
        self.id = id
        self.title = title
        self.artist = artist
        self.album = album
        self.artworkData = artworkData
        self.duration = duration
        self.playerPosition = playerPosition
    }

    public var artworkImage: NSImage? {
        guard let data = artworkData else { return nil }
        return NSImage(data: data)
    }
}
