import AppKit
import Combine
import Foundation

/// Integrates with Apple Music and Spotify via macOS DistributedNotificationCenter and AppleScript.
@MainActor
public final class SystemNowPlayingService: ObservableObject, NowPlayingServiceProtocol {
    @Published public private(set) var currentTrack: Track?
    @Published public private(set) var isPlaying: Bool = false
    @Published public private(set) var activePlayerName: String?

    private var musicObserver: NSObjectProtocol?
    private var spotifyObserver: NSObjectProtocol?
    private let scriptQueue = DispatchQueue(label: "com.macnotch.nowplaying.script", qos: .userInitiated)

    public init() {
        setupObservers()
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

    private func setupObservers() {
        // Apple Music notification
        musicObserver = DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("com.apple.Music.playerInfo"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            MainActor.assumeIsolated {
                self?.handlePlayerInfo(notification: notification, source: "Music")
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
        self.isPlaying = (playerState == "Playing")
        self.activePlayerName = source

        if let title = userInfo["Name"] as? String, !title.isEmpty {
            let artist = (userInfo["Artist"] as? String) ?? "Unknown Artist"
            let album = (userInfo["Album"] as? String) ?? ""
            let duration = (userInfo["Total Time"] as? Double).map { $0 / 1000.0 }

            self.currentTrack = Track(
                title: title,
                artist: artist,
                album: album,
                duration: duration
            )
        } else if !isPlaying {
            // Stopped
            self.currentTrack = nil
        }
    }

    public func checkInitialPlaybackState() {
        // Run a lightweight check to see if Music is already running and playing
        scriptQueue.async { [weak self] in
            let script = """
            if application "Music" is running then
                tell application "Music"
                    if player state is playing then
                        set trackName to name of current track
                        set trackArtist to artist of current track
                        set trackAlbum to album of current track
                        return trackName & "||" & trackArtist & "||" & trackAlbum & "||Playing"
                    end if
                end tell
            end if
            if application "Spotify" is running then
                tell application "Spotify"
                    if player state is playing then
                        set trackName to name of current track
                        set trackArtist to artist of current track
                        set trackAlbum to album of current track
                        return trackName & "||" & trackArtist & "||" & trackAlbum & "||Playing"
                    end if
                end tell
            end if
            return ""
            """

            var error: NSDictionary?
            if let appleScript = NSAppleScript(source: script) {
                let result = appleScript.executeAndReturnError(&error).stringValue ?? ""
                let parts = result.components(separatedBy: "||")
                if parts.count >= 4 {
                    let title = parts[0]
                    let artist = parts[1]
                    let album = parts[2]
                    DispatchQueue.main.async {
                        self?.currentTrack = Track(title: title, artist: artist, album: album)
                        self?.isPlaying = true
                        self?.activePlayerName = "Music"
                    }
                }
            }
        }
    }

    // MARK: - Playback Controls

    public func play() {
        executeCommand("play")
        isPlaying = true
    }

    public func pause() {
        executeCommand("pause")
        isPlaying = false
    }

    public func togglePlayPause() {
        executeCommand("playpause")
        isPlaying.toggle()
    }

    public func next() {
        executeCommand("next track")
    }

    public func previous() {
        executeCommand("previous track")
    }

    private func executeCommand(_ command: String) {
        let appName = activePlayerName ?? "Music"
        scriptQueue.async {
            let script = "tell application \"\(appName)\" to \(command)"
            var error: NSDictionary?
            if let appleScript = NSAppleScript(source: script) {
                appleScript.executeAndReturnError(&error)
            }
        }
    }
}
