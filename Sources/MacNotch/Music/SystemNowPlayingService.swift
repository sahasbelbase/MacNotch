import AppKit
import Combine
import Foundation

/// Composite Now Playing service integrating generic macOS MediaRemote system-wide playback
/// with AppleScript fallbacks for Apple Music and Spotify.
@MainActor
public final class SystemNowPlayingService: ObservableObject, NowPlayingServiceProtocol {
    @Published public private(set) var currentTrack: Track?
    @Published public private(set) var isPlaying: Bool = false
    @Published public private(set) var artwork: NSImage?
    @Published public private(set) var activePlayerName: String?

    public let mediaRemoteProvider: MediaRemoteNowPlayingProvider
    public let musicStudioProvider: MusicStudioNowPlayingProvider

    public init() {
        self.mediaRemoteProvider = MediaRemoteNowPlayingProvider()
        self.musicStudioProvider = MusicStudioNowPlayingProvider()
        setupMusicStudioProvider()
    }

    private func setupMusicStudioProvider() {
        musicStudioProvider.onUpdate = { [weak self] in
            MainActor.assumeIsolated {
                guard let self = self else { return }
                self.currentTrack = self.musicStudioProvider.currentTrack
                self.isPlaying = self.musicStudioProvider.isPlaying
                self.artwork = self.musicStudioProvider.artwork
                self.activePlayerName = "Music Studio"
            }
        }

        if let track = musicStudioProvider.currentTrack {
            self.currentTrack = track
            self.isPlaying = musicStudioProvider.isPlaying
            self.artwork = musicStudioProvider.artwork
            self.activePlayerName = "Music Studio"
        }
    }

    // MARK: - Playback Controls (Exclusively Dedicated to Music Studio)

    public func play() {
        musicStudioProvider.play()
        self.isPlaying = musicStudioProvider.isPlaying
        self.currentTrack = musicStudioProvider.currentTrack
        self.artwork = musicStudioProvider.artwork
    }

    public func pause() {
        musicStudioProvider.pause()
        self.isPlaying = musicStudioProvider.isPlaying
    }

    public func togglePlayPause() {
        musicStudioProvider.togglePlayPause()
        self.isPlaying = musicStudioProvider.isPlaying
        self.currentTrack = musicStudioProvider.currentTrack
        self.artwork = musicStudioProvider.artwork
    }

    public func next() {
        musicStudioProvider.next()
        self.currentTrack = musicStudioProvider.currentTrack
        self.isPlaying = musicStudioProvider.isPlaying
        self.artwork = musicStudioProvider.artwork
    }

    public func previous() {
        musicStudioProvider.previous()
        self.currentTrack = musicStudioProvider.currentTrack
        self.isPlaying = musicStudioProvider.isPlaying
        self.artwork = musicStudioProvider.artwork
    }
}
