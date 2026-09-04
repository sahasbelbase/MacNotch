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
    private var musicObserver: NSObjectProtocol?
    private var spotifyObserver: NSObjectProtocol?
    private let scriptQueue = DispatchQueue(label: "com.macnotch.nowplaying.script", qos: .userInitiated)

    public init() {
        self.mediaRemoteProvider = MediaRemoteNowPlayingProvider()
        setupMediaRemoteProvider()
        setupDistributedObservers()
        checkInitialPlaybackState()
    }

    deinit {
        if let obs = musicObserver {
            DistributedNotificationCenter.default().removeObserver(obs)
        }
        if let obs = spotifyObserver {
            DistributedNotificationCenter.default().removeObserver(obs)
        }
    }

    private func setupMediaRemoteProvider() {
        mediaRemoteProvider.onUpdate = { [weak self] in
            MainActor.assumeIsolated {
                guard let self = self else { return }
                if let track = self.mediaRemoteProvider.currentTrack {
                    self.currentTrack = track
                    self.isPlaying = self.mediaRemoteProvider.isPlaying
                    self.artwork = self.mediaRemoteProvider.artwork
                    self.activePlayerName = self.mediaRemoteProvider.providerName
                } else if !self.mediaRemoteProvider.isPlaying && self.activePlayerName == self.mediaRemoteProvider.providerName {
                    self.isPlaying = false
                    self.currentTrack = nil
                    self.artwork = nil
                }
            }
        }

        if let track = mediaRemoteProvider.currentTrack {
            self.currentTrack = track
            self.isPlaying = mediaRemoteProvider.isPlaying
            self.artwork = mediaRemoteProvider.artwork
            self.activePlayerName = mediaRemoteProvider.providerName
        }
    }

    private func setupDistributedObservers() {
        // Apple Music notification
        musicObserver = DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("com.apple.Music.playerInfo"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            MainActor.assumeIsolated {
                self?.handlePlayerInfo(notification: notification, source: "Apple Music")
            }
        }

        // Spotify notification
        spotifyObserver = DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("com.spotify.client.PlaybackStateChanged"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            MainActor.assumeIsolated {
                self?.handlePlayerInfo(notification: notification, source: "Spotify")
            }
        }
    }

    private func handlePlayerInfo(notification: Notification, source: String) {
        guard let userInfo = notification.userInfo else { return }

        let playerState = userInfo["Player State"] as? String
        let playing = (playerState == "Playing")

        if let title = userInfo["Name"] as? String, !title.isEmpty {
            let artist = (userInfo["Artist"] as? String) ?? "Unknown Artist"
            let album = (userInfo["Album"] as? String) ?? ""
            let duration = (userInfo["Total Time"] as? Double).map { $0 / 1000.0 }

            self.isPlaying = playing
            self.activePlayerName = source
            self.currentTrack = Track(
                title: title,
                artist: artist,
                album: album,
                duration: duration
            )
        } else if !playing && self.activePlayerName == source {
            self.isPlaying = false
            self.currentTrack = nil
        }
    }

    public func checkInitialPlaybackState() {
        if mediaRemoteProvider.currentTrack != nil {
            return
        }

        scriptQueue.async { [weak self] in
            let script = """
            if application "Music" is running then
                tell application "Music"
                    if player state is playing then
                        set trackName to name of current track
                        set trackArtist to artist of current track
                        set trackAlbum to album of current track
                        return trackName & "||" & trackArtist & "||" & trackAlbum & "||Playing||Music"
                    end if
                end tell
            end if
            if application "Spotify" is running then
                tell application "Spotify"
                    if player state is playing then
                        set trackName to name of current track
                        set trackArtist to artist of current track
                        set trackAlbum to album of current track
                        return trackName & "||" & trackArtist & "||" & trackAlbum & "||Playing||Spotify"
                    end if
                end tell
            end if
            return ""
            """

            var error: NSDictionary?
            if let appleScript = NSAppleScript(source: script) {
                let result = appleScript.executeAndReturnError(&error).stringValue ?? ""
                let parts = result.components(separatedBy: "||")
                if parts.count >= 5 {
                    let title = parts[0]
                    let artist = parts[1]
                    let album = parts[2]
                    let app = parts[4]
                    DispatchQueue.main.async {
                        self?.currentTrack = Track(title: title, artist: artist, album: album)
                        self?.isPlaying = true
                        self?.activePlayerName = app
                    }
                }
            }
        }
    }

    // MARK: - Playback Controls

    public func play() {
        if mediaRemoteProvider.isAvailable {
            mediaRemoteProvider.play()
        } else {
            executeAppleScriptCommand("play")
        }
        isPlaying = true
    }

    public func pause() {
        if mediaRemoteProvider.isAvailable {
            mediaRemoteProvider.pause()
        } else {
            executeAppleScriptCommand("pause")
        }
        isPlaying = false
    }

    public func togglePlayPause() {
        if mediaRemoteProvider.isAvailable {
            mediaRemoteProvider.togglePlayPause()
        } else {
            executeAppleScriptCommand("playpause")
        }
        isPlaying.toggle()
    }

    public func next() {
        if mediaRemoteProvider.isAvailable {
            mediaRemoteProvider.next()
        } else {
            executeAppleScriptCommand("next track")
        }
    }

    public func previous() {
        if mediaRemoteProvider.isAvailable {
            mediaRemoteProvider.previous()
        } else {
            executeAppleScriptCommand("previous track")
        }
    }

    private func executeAppleScriptCommand(_ command: String) {
        let appName = (activePlayerName == "Spotify") ? "Spotify" : "Music"
        scriptQueue.async {
            let script = "tell application \"\(appName)\" to \(command)"
            var error: NSDictionary?
            if let appleScript = NSAppleScript(source: script) {
                appleScript.executeAndReturnError(&error)
            }
        }
    }
}
