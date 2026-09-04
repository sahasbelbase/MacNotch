import Combine
import Foundation

/// Protocol abstracting now-playing audio providers.
@MainActor
public protocol NowPlayingServiceProtocol: AnyObject, ObservableObject {
    var currentTrack: Track? { get }
    var isPlaying: Bool { get }

    func play()
    func pause()
    func togglePlayPause()
    func next()
    func previous()
}
