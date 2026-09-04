import AppKit
import Combine
import Foundation

/// Standard protocol abstracting a now-playing audio source.
@MainActor
public protocol NowPlayingProvider: AnyObject {
    var isPlaying: Bool { get }
    var currentTrack: Track? { get }
    var artwork: NSImage? { get }
    var providerName: String { get }

    func play()
    func pause()
    func togglePlayPause()
    func next()
    func previous()
}

/// Protocol abstracting the application-level Now Playing observable service.
@MainActor
public protocol NowPlayingServiceProtocol: AnyObject, ObservableObject {
    var currentTrack: Track? { get }
    var isPlaying: Bool { get }
    var artwork: NSImage? { get }
    var activePlayerName: String? { get }

    func play()
    func pause()
    func togglePlayPause()
    func next()
    func previous()
}
