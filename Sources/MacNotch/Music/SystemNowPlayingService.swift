import AppKit
import Combine
import Foundation

/// Active audio player source type
public enum ActiveAudioPlayer: String, CaseIterable {
    case musicStudio = "Music Studio"
    case spotify = "Spotify"
    case appleMusic = "Apple Music"
    case youtubeMusic = "YouTube Music"
    case mediaRemote = "Media Player"
}

/// Composite Now Playing service with smart fallback hierarchy based on what is DOWNLOADED, RUNNING, and PLAYING:
/// 1. Music Studio (local engine at port 5050 / local app)
/// 2. Spotify (running application / notifications / AppleScript)
/// 3. YouTube Music (desktop app / PWA / browser streaming)
/// 4. Apple Music (macOS system Music.app)
/// 5. System MediaRemote (browsers, YouTube, podcasts, video players)
@MainActor
public final class SystemNowPlayingService: ObservableObject, NowPlayingServiceProtocol {
    @Published public private(set) var currentTrack: Track?
    @Published public private(set) var isPlaying: Bool = false
    @Published public private(set) var artwork: NSImage?
    @Published public private(set) var activePlayerName: String?
    @Published public private(set) var activePlayer: ActiveAudioPlayer = .musicStudio

    public let mediaRemoteProvider: MediaRemoteNowPlayingProvider
    public let musicStudioProvider: MusicStudioNowPlayingProvider

    // State from external players
    private var spotifyTrack: Track?
    private var spotifyIsPlaying: Bool = false

    private var appleMusicTrack: Track?
    private var appleMusicIsPlaying: Bool = false

    private var musicObserver: NSObjectProtocol?
    private var spotifyObserver: NSObjectProtocol?
    private let scriptQueue = DispatchQueue(label: "com.macnotch.nowplaying.script", qos: .userInitiated)

    public init() {
        self.mediaRemoteProvider = MediaRemoteNowPlayingProvider()
        self.musicStudioProvider = MusicStudioNowPlayingProvider()

        setupProviders()
        setupDistributedNotifications()
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

    // MARK: - App Installation & Download Verification

    /// Returns true if Music Studio is downloaded/installed or running.
    public var isMusicStudioDownloaded: Bool {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.musicstudio.app") != nil
            || FileManager.default.fileExists(atPath: "/Applications/Music Studio.app")
            || FileManager.default.fileExists(atPath: ("~/Applications/Music Studio.app" as NSString).expandingTildeInPath)
            || musicStudioProvider.isAvailable
            || !musicStudioProvider.libraryTracks.isEmpty
    }

    /// Returns true if Spotify desktop app is downloaded and installed.
    public var isSpotifyDownloaded: Bool {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.spotify.client") != nil
            || FileManager.default.fileExists(atPath: "/Applications/Spotify.app")
            || FileManager.default.fileExists(atPath: ("~/Applications/Spotify.app" as NSString).expandingTildeInPath)
    }

    /// Returns true if Apple Music is installed (pre-installed on macOS).
    public var isAppleMusicDownloaded: Bool {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Music") != nil
            || FileManager.default.fileExists(atPath: "/System/Applications/Music.app")
    }

    /// Returns true if YouTube Music desktop app is downloaded/installed.
    public var isYouTubeMusicDownloaded: Bool {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.github.th-ch.youtube-music") != nil
            || NSWorkspace.shared.urlForApplication(withBundleIdentifier: "app.ytmdesktop.ytmdesktop") != nil
            || FileManager.default.fileExists(atPath: "/Applications/YouTube Music.app")
            || FileManager.default.fileExists(atPath: ("~/Applications/YouTube Music.app" as NSString).expandingTildeInPath)
    }

    // MARK: - Running App State

    public var isMusicStudioRunning: Bool {
        !NSRunningApplication.runningApplications(withBundleIdentifier: "com.musicstudio.app").isEmpty
            || musicStudioProvider.isAvailable
    }

    public var isSpotifyRunning: Bool {
        !NSRunningApplication.runningApplications(withBundleIdentifier: "com.spotify.client").isEmpty
    }

    public var isAppleMusicRunning: Bool {
        !NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.Music").isEmpty
    }

    public var isYouTubeMusicRunning: Bool {
        !NSRunningApplication.runningApplications(withBundleIdentifier: "com.github.th-ch.youtube-music").isEmpty
            || !NSRunningApplication.runningApplications(withBundleIdentifier: "app.ytmdesktop.ytmdesktop").isEmpty
    }

    // MARK: - Setup & Synchronization

    private func setupProviders() {
        musicStudioProvider.onUpdate = { [weak self] in
            MainActor.assumeIsolated {
                self?.evaluateActiveSource()
            }
        }

        mediaRemoteProvider.onUpdate = { [weak self] in
            MainActor.assumeIsolated {
                self?.evaluateActiveSource()
            }
        }
    }

    private func setupDistributedNotifications() {
        // Apple Music notification
        musicObserver = DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("com.apple.Music.playerInfo"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            MainActor.assumeIsolated {
                self?.handleAppleMusicInfo(notification: notification)
            }
        }

        // Spotify notification
        spotifyObserver = DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("com.spotify.client.PlaybackStateChanged"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            MainActor.assumeIsolated {
                self?.handleSpotifyInfo(notification: notification)
            }
        }
    }

    private func handleAppleMusicInfo(notification: Notification) {
        guard let userInfo = notification.userInfo else { return }
        let playerState = (userInfo["Player State"] as? String) ?? ""
        self.appleMusicIsPlaying = (playerState == "Playing")

        if let title = userInfo["Name"] as? String, !title.isEmpty {
            let artist = (userInfo["Artist"] as? String) ?? "Apple Music"
            let album = (userInfo["Album"] as? String) ?? ""
            let duration = (userInfo["Total Time"] as? Double).map { $0 / 1000.0 }
            self.appleMusicTrack = Track(
                title: title,
                artist: artist,
                album: album,
                duration: duration
            )
        } else if !self.appleMusicIsPlaying {
            self.appleMusicTrack = nil
        }

        evaluateActiveSource()
    }

    private func handleSpotifyInfo(notification: Notification) {
        guard let userInfo = notification.userInfo else { return }
        let playerState = (userInfo["Player State"] as? String) ?? ""
        self.spotifyIsPlaying = (playerState == "Playing")

        if let title = userInfo["Name"] as? String, !title.isEmpty {
            let artist = (userInfo["Artist"] as? String) ?? "Spotify"
            let album = (userInfo["Album"] as? String) ?? ""
            let duration = (userInfo["Duration"] as? Double).map { $0 / 1000.0 }
            self.spotifyTrack = Track(
                title: title,
                artist: artist,
                album: album,
                duration: duration
            )
        } else if !self.spotifyIsPlaying {
            self.spotifyTrack = nil
        }

        evaluateActiveSource()
    }

    public func checkInitialPlaybackState() {
        mediaRemoteProvider.refreshNowPlaying()

        scriptQueue.async { [weak self] in
            let script = """
            if application "Spotify" is running then
                tell application "Spotify"
                    if player state is playing then
                        set tName to name of current track
                        set tArtist to artist of current track
                        set tAlbum to album of current track
                        return "Spotify||" & tName & "||" & tArtist & "||" & tAlbum
                    end if
                end tell
            end if
            if application "Music" is running then
                tell application "Music"
                    if player state is playing then
                        set tName to name of current track
                        set tArtist to artist of current track
                        set tAlbum to album of current track
                        return "Apple Music||" & tName & "||" & tArtist & "||" & tAlbum
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
                    let source = parts[0]
                    let title = parts[1]
                    let artist = parts[2]
                    let album = parts[3]
                    DispatchQueue.main.async {
                        guard let self = self else { return }
                        if source == "Spotify" {
                            self.spotifyTrack = Track(title: title, artist: artist, album: album)
                            self.spotifyIsPlaying = true
                        } else if source == "Apple Music" {
                            self.appleMusicTrack = Track(title: title, artist: artist, album: album)
                            self.appleMusicIsPlaying = true
                        }
                        self.evaluateActiveSource()
                    }
                }
            }
        }
    }

    // MARK: - Smart Source Evaluation

    public func evaluateActiveSource() {
        let prefSource = SettingsStore.shared.musicSource

        // 1. If user explicitly locked source in Settings
        if prefSource == "MusicStudio" {
            selectMusicStudio()
            return
        } else if prefSource == "Spotify" {
            selectSpotify()
            return
        } else if prefSource == "Music" {
            selectAppleMusic()
            return
        } else if prefSource == "YouTubeMusic" {
            selectYouTubeMusic()
            return
        }

        // 2. Automatic Smart Fallback Chain (Music Studio -> Spotify -> YouTube Music -> Apple Music -> MediaRemote)

        // A. Music Studio is actively playing
        if musicStudioProvider.isPlaying {
            selectMusicStudio()
            return
        }

        // B. Spotify is actively playing
        if spotifyIsPlaying || (mediaRemoteProvider.isPlaying && isSpotifyRunning) {
            selectSpotify()
            return
        }

        // C. Apple Music is actively playing
        if appleMusicIsPlaying || (mediaRemoteProvider.isPlaying && isAppleMusicRunning) {
            selectAppleMusic()
            return
        }

        // D. YouTube Music is actively playing (via app or browser stream)
        if mediaRemoteProvider.isPlaying, let track = mediaRemoteProvider.currentTrack {
            let isYTM = isYouTubeMusicRunning
                || track.album.localizedCaseInsensitiveContains("YouTube")
                || track.artist.localizedCaseInsensitiveContains("YouTube")
            if isYTM {
                selectYouTubeMusic()
                return
            }
        }

        // E. Other Generic MediaRemote is playing (YouTube video, Podcasts, Safari/Chrome, etc.)
        if mediaRemoteProvider.isPlaying && mediaRemoteProvider.currentTrack != nil {
            selectMediaRemote()
            return
        }

        // F. Idle States (Nothing actively playing right now)
        // Check running apps first:
        if musicStudioProvider.isAvailable, musicStudioProvider.currentTrack != nil {
            selectMusicStudio(playing: false)
            return
        }

        if let track = spotifyTrack {
            self.activePlayer = .spotify
            self.activePlayerName = "Spotify"
            self.currentTrack = track
            self.isPlaying = false
            self.artwork = mediaRemoteProvider.artwork
            return
        }

        if let track = appleMusicTrack {
            self.activePlayer = .appleMusic
            self.activePlayerName = "Apple Music"
            self.currentTrack = track
            self.isPlaying = false
            self.artwork = mediaRemoteProvider.artwork
            return
        }

        if mediaRemoteProvider.currentTrack != nil {
            selectMediaRemote(playing: false)
            return
        }

        // Check downloaded / installed music apps in hierarchy:
        if isMusicStudioDownloaded && !musicStudioProvider.libraryTracks.isEmpty {
            selectMusicStudio(playing: false)
            return
        }

        if isSpotifyRunning || (isSpotifyDownloaded && !isMusicStudioDownloaded) {
            self.activePlayer = .spotify
            self.activePlayerName = "Spotify"
            self.currentTrack = nil
            self.isPlaying = false
            self.artwork = nil
            return
        }

        if isYouTubeMusicRunning || (isYouTubeMusicDownloaded && !isMusicStudioDownloaded && !isSpotifyDownloaded) {
            self.activePlayer = .youtubeMusic
            self.activePlayerName = "YouTube Music"
            self.currentTrack = nil
            self.isPlaying = false
            self.artwork = nil
            return
        }

        if isAppleMusicRunning || (!isMusicStudioDownloaded && !isSpotifyDownloaded) {
            self.activePlayer = .appleMusic
            self.activePlayerName = "Apple Music"
            self.currentTrack = nil
            self.isPlaying = false
            self.artwork = nil
            return
        }

        // Default to whichever is available, or Music Studio if present
        if isMusicStudioDownloaded {
            self.activePlayer = .musicStudio
            self.activePlayerName = "Music Studio"
        } else if isSpotifyDownloaded {
            self.activePlayer = .spotify
            self.activePlayerName = "Spotify"
        } else {
            self.activePlayer = .appleMusic
            self.activePlayerName = "Apple Music"
        }
        self.currentTrack = nil
        self.isPlaying = false
        self.artwork = nil
    }

    private func selectMusicStudio(playing: Bool? = nil) {
        let newPlayer: ActiveAudioPlayer = .musicStudio
        let newName = "Music Studio"
        let newTrack = musicStudioProvider.currentTrack
        let newPlaying = playing ?? musicStudioProvider.isPlaying
        let newArtwork = musicStudioProvider.artwork

        if self.activePlayer != newPlayer { self.activePlayer = newPlayer }
        if self.activePlayerName != newName { self.activePlayerName = newName }
        if self.currentTrack != newTrack { self.currentTrack = newTrack }
        if self.isPlaying != newPlaying { self.isPlaying = newPlaying }
        if self.artwork != newArtwork { self.artwork = newArtwork }
    }

    private func selectSpotify(playing: Bool? = nil) {
        let newPlayer: ActiveAudioPlayer = .spotify
        let newName = "Spotify"
        let newTrack = spotifyTrack ?? mediaRemoteProvider.currentTrack
        let newPlaying = playing ?? (spotifyIsPlaying || mediaRemoteProvider.isPlaying)
        let newArtwork = mediaRemoteProvider.artwork

        if self.activePlayer != newPlayer { self.activePlayer = newPlayer }
        if self.activePlayerName != newName { self.activePlayerName = newName }
        if self.currentTrack != newTrack { self.currentTrack = newTrack }
        if self.isPlaying != newPlaying { self.isPlaying = newPlaying }
        if self.artwork != newArtwork { self.artwork = newArtwork }
    }

    private func selectAppleMusic(playing: Bool? = nil) {
        let newPlayer: ActiveAudioPlayer = .appleMusic
        let newName = "Apple Music"
        let newTrack = appleMusicTrack ?? mediaRemoteProvider.currentTrack
        let newPlaying = playing ?? (appleMusicIsPlaying || mediaRemoteProvider.isPlaying)
        let newArtwork = mediaRemoteProvider.artwork

        if self.activePlayer != newPlayer { self.activePlayer = newPlayer }
        if self.activePlayerName != newName { self.activePlayerName = newName }
        if self.currentTrack != newTrack { self.currentTrack = newTrack }
        if self.isPlaying != newPlaying { self.isPlaying = newPlaying }
        if self.artwork != newArtwork { self.artwork = newArtwork }
    }

    private func selectYouTubeMusic(playing: Bool? = nil) {
        let newPlayer: ActiveAudioPlayer = .youtubeMusic
        let newName = "YouTube Music"
        let newTrack = mediaRemoteProvider.currentTrack
        let newPlaying = playing ?? mediaRemoteProvider.isPlaying
        let newArtwork = mediaRemoteProvider.artwork

        if self.activePlayer != newPlayer { self.activePlayer = newPlayer }
        if self.activePlayerName != newName { self.activePlayerName = newName }
        if self.currentTrack != newTrack { self.currentTrack = newTrack }
        if self.isPlaying != newPlaying { self.isPlaying = newPlaying }
        if self.artwork != newArtwork { self.artwork = newArtwork }
    }

    private func selectMediaRemote(playing: Bool? = nil) {
        let newPlayer: ActiveAudioPlayer = .mediaRemote
        let newName = "Media Player"
        let newTrack = mediaRemoteProvider.currentTrack
        let newPlaying = playing ?? mediaRemoteProvider.isPlaying
        let newArtwork = mediaRemoteProvider.artwork

        if self.activePlayer != newPlayer { self.activePlayer = newPlayer }
        if self.activePlayerName != newName { self.activePlayerName = newName }
        if self.currentTrack != newTrack { self.currentTrack = newTrack }
        if self.isPlaying != newPlaying { self.isPlaying = newPlaying }
        if self.artwork != newArtwork { self.artwork = newArtwork }
    }

    // MARK: - Open Active Player

    public func openActivePlayer() {
        switch activePlayer {
        case .musicStudio:
            if isMusicStudioDownloaded {
                musicStudioProvider.bringMusicStudioToFront()
            } else if let url = URL(string: "https://github.com/sahasbelbase/MusicDownloder") {
                NSWorkspace.shared.open(url)
            }
        case .spotify:
            if isSpotifyDownloaded {
                openApplication(bundleId: "com.spotify.client", defaultPath: "/Applications/Spotify.app")
            } else if let url = URL(string: "https://www.spotify.com/download") {
                NSWorkspace.shared.open(url)
            }
        case .appleMusic:
            openApplication(bundleId: "com.apple.Music", defaultPath: "/System/Applications/Music.app")
        case .youtubeMusic:
            if isYouTubeMusicDownloaded {
                if let app = NSRunningApplication.runningApplications(withBundleIdentifier: "com.github.th-ch.youtube-music").first {
                    app.activate(options: [.activateAllWindows])
                } else if let app = NSRunningApplication.runningApplications(withBundleIdentifier: "app.ytmdesktop.ytmdesktop").first {
                    app.activate(options: [.activateAllWindows])
                } else if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.github.th-ch.youtube-music") ?? NSWorkspace.shared.urlForApplication(withBundleIdentifier: "app.ytmdesktop.ytmdesktop") {
                    NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration(), completionHandler: nil)
                }
            } else if let url = URL(string: "https://music.youtube.com") {
                NSWorkspace.shared.open(url)
            }
        case .mediaRemote:
            if isSpotifyRunning {
                openApplication(bundleId: "com.spotify.client", defaultPath: "/Applications/Spotify.app")
            } else if isAppleMusicRunning {
                openApplication(bundleId: "com.apple.Music", defaultPath: "/System/Applications/Music.app")
            } else if isYouTubeMusicRunning {
                if let url = URL(string: "https://music.youtube.com") {
                    NSWorkspace.shared.open(url)
                }
            } else {
                musicStudioProvider.bringMusicStudioToFront()
            }
        }
    }

    private func openApplication(bundleId: String, defaultPath: String? = nil) {
        if let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleId).first {
            app.activate(options: [.activateAllWindows])
            return
        }
        if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
            let config = NSWorkspace.OpenConfiguration()
            config.activates = true
            NSWorkspace.shared.openApplication(at: appURL, configuration: config, completionHandler: nil)
            return
        }
        if let path = defaultPath, FileManager.default.fileExists(atPath: path) {
            let config = NSWorkspace.OpenConfiguration()
            config.activates = true
            NSWorkspace.shared.openApplication(at: URL(fileURLWithPath: path), configuration: config, completionHandler: nil)
        }
    }

    // MARK: - Transport Controls

    public func play() {
        switch activePlayer {
        case .musicStudio:
            musicStudioProvider.play()
            self.isPlaying = musicStudioProvider.isPlaying
            self.currentTrack = musicStudioProvider.currentTrack
            self.artwork = musicStudioProvider.artwork
        case .spotify:
            executeAppleScript("tell application \"Spotify\" to play")
            self.isPlaying = true
        case .appleMusic:
            executeAppleScript("tell application \"Music\" to play")
            self.isPlaying = true
        case .youtubeMusic, .mediaRemote:
            mediaRemoteProvider.play()
            self.isPlaying = true
        }
    }

    public func pause() {
        switch activePlayer {
        case .musicStudio:
            musicStudioProvider.pause()
            self.isPlaying = musicStudioProvider.isPlaying
        case .spotify:
            executeAppleScript("tell application \"Spotify\" to pause")
            self.isPlaying = false
        case .appleMusic:
            executeAppleScript("tell application \"Music\" to pause")
            self.isPlaying = false
        case .youtubeMusic, .mediaRemote:
            mediaRemoteProvider.pause()
            self.isPlaying = false
        }
    }

    public func togglePlayPause() {
        // If completely idle, smart start whichever player is downloaded / running
        if currentTrack == nil && !isPlaying {
            if isMusicStudioRunning {
                activePlayer = .musicStudio
                activePlayerName = "Music Studio"
                musicStudioProvider.play()
                return
            } else if isSpotifyRunning || (isSpotifyDownloaded && !isMusicStudioDownloaded) {
                activePlayer = .spotify
                activePlayerName = "Spotify"
                executeAppleScript("tell application \"Spotify\" to play")
                isPlaying = true
                return
            } else if isAppleMusicRunning || (!isMusicStudioDownloaded && !isSpotifyDownloaded) {
                activePlayer = .appleMusic
                activePlayerName = "Apple Music"
                executeAppleScript("tell application \"Music\" to play")
                isPlaying = true
                return
            } else if isYouTubeMusicRunning {
                activePlayer = .youtubeMusic
                activePlayerName = "YouTube Music"
                mediaRemoteProvider.togglePlayPause()
                return
            }
        }

        switch activePlayer {
        case .musicStudio:
            musicStudioProvider.togglePlayPause()
            self.isPlaying = musicStudioProvider.isPlaying
            self.currentTrack = musicStudioProvider.currentTrack
            self.artwork = musicStudioProvider.artwork
        case .spotify:
            executeAppleScript("tell application \"Spotify\" to playpause")
            self.isPlaying.toggle()
        case .appleMusic:
            executeAppleScript("tell application \"Music\" to playpause")
            self.isPlaying.toggle()
        case .youtubeMusic, .mediaRemote:
            mediaRemoteProvider.togglePlayPause()
            self.isPlaying.toggle()
        }
    }

    public func next() {
        switch activePlayer {
        case .musicStudio:
            musicStudioProvider.next()
            self.currentTrack = musicStudioProvider.currentTrack
            self.isPlaying = musicStudioProvider.isPlaying
            self.artwork = musicStudioProvider.artwork
        case .spotify:
            executeAppleScript("tell application \"Spotify\" to next track")
        case .appleMusic:
            executeAppleScript("tell application \"Music\" to next track")
        case .youtubeMusic, .mediaRemote:
            mediaRemoteProvider.next()
        }
    }

    public func previous() {
        switch activePlayer {
        case .musicStudio:
            musicStudioProvider.previous()
            self.currentTrack = musicStudioProvider.currentTrack
            self.isPlaying = musicStudioProvider.isPlaying
            self.artwork = musicStudioProvider.artwork
        case .spotify:
            executeAppleScript("tell application \"Spotify\" to previous track")
        case .appleMusic:
            executeAppleScript("tell application \"Music\" to previous track")
        case .youtubeMusic, .mediaRemote:
            mediaRemoteProvider.previous()
        }
    }

    private func executeAppleScript(_ command: String) {
        scriptQueue.async {
            var error: NSDictionary?
            if let appleScript = NSAppleScript(source: command) {
                appleScript.executeAndReturnError(&error)
            }
        }
    }
}
