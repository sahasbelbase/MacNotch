import AppKit
import AVFoundation
import Foundation

/// Represents a song in the user's local "Music Studio" library.
public struct MusicStudioTrack: Identifiable, Codable, Hashable, Sendable {
    public var id: String { filename }
    public let filename: String
    public let title: String
    public let artist: String
    public let album: String
    public let year: String?
    public let genre: String?
    public let duration: Double?
    public let size_mb: Double?
    public let bitrate: String?

    public init(
        filename: String,
        title: String,
        artist: String,
        album: String,
        year: String? = nil,
        genre: String? = nil,
        duration: Double? = nil,
        size_mb: Double? = nil,
        bitrate: String? = nil
    ) {
        self.filename = filename
        self.title = title
        self.artist = artist
        self.album = album
        self.year = year
        self.genre = genre
        self.duration = duration
        self.size_mb = size_mb
        self.bitrate = bitrate
    }
}

/// Native provider that communicates directly with the local "Music Studio" engine (port 5050).
/// Supports live metadata (title, artist, album, duration, elapsed time), library browsing, and transport actions.
@MainActor
public final class MusicStudioNowPlayingProvider: NowPlayingProvider, ObservableObject {
    public let providerName: String = "Music Studio"

    @Published public private(set) var isPlaying: Bool = false
    @Published public private(set) var currentTrack: Track?
    @Published public private(set) var artwork: NSImage?
    @Published public private(set) var isAvailable: Bool = false
    @Published public private(set) var currentTime: Double = 0
    @Published public private(set) var duration: Double = 0
    @Published public private(set) var libraryTracks: [MusicStudioTrack] = []

    public var onUpdate: (() -> Void)?

    private let baseURL = "http://127.0.0.1:5050"
    private var pollTimer: Timer?
    private var lastCoverURL: String?
    private let session: URLSession
    private var localPlayer: AVPlayer?

    public init() {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 1.0
        config.timeoutIntervalForResource = 1.5
        self.session = URLSession(configuration: config)

        fetchLibrary()
        startPolling()
    }

    deinit {
        pollTimer?.invalidate()
    }

    public func startPolling() {
        stopPolling()
        // Poll immediately, then every 1.5 seconds
        fetchPlaybackState()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.fetchPlaybackState()
            }
        }
    }

    public func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    /// Queries http://127.0.0.1:5050/api/playback asynchronously.
    public func fetchPlaybackState() {
        guard let url = URL(string: "\(baseURL)/api/playback") else { return }

        Task {
            do {
                let (data, response) = try await session.data(from: url)
                guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                    await MainActor.run {
                        if self.isAvailable {
                            self.isAvailable = false
                            self.onUpdate?()
                        }
                    }
                    return
                }

                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    await self.processPlaybackJSON(json)
                }
            } catch {
                await MainActor.run {
                    if self.isAvailable {
                        self.isAvailable = false
                        self.onUpdate?()
                    }
                }
            }
        }
    }

    private func processPlaybackJSON(_ json: [String: Any]) {
        let playing = (json["is_playing"] as? Bool) ?? false
        let title = (json["title"] as? String) ?? ""
        let artist = (json["artist"] as? String) ?? "Music Studio"
        let album = (json["album"] as? String) ?? ""
        let curTime = (json["current_time"] as? Double) ?? 0.0
        let dur = (json["duration"] as? Double) ?? 0.0
        let coverURL = (json["cover_url"] as? String) ?? ""

        self.isPlaying = playing
        self.currentTime = curTime
        self.duration = dur
        self.isAvailable = !title.isEmpty || playing

        if !title.isEmpty {
            self.currentTrack = Track(
                title: title,
                artist: artist,
                album: album,
                duration: dur > 0 ? dur : nil
            )
        } else {
            self.currentTrack = nil
        }

        // Fetch cover artwork if available and changed
        if !coverURL.isEmpty && coverURL != lastCoverURL {
            self.lastCoverURL = coverURL
            fetchCoverArtwork(coverURL: coverURL)
        } else if coverURL.isEmpty {
            self.lastCoverURL = nil
            self.artwork = nil
        }

        self.onUpdate?()
    }

    private func fetchCoverArtwork(coverURL: String) {
        let fullURLStr: String
        if coverURL.hasPrefix("http://") || coverURL.hasPrefix("https://") {
            fullURLStr = coverURL
        } else {
            let path = coverURL.hasPrefix("/") ? coverURL : "/\(coverURL)"
            fullURLStr = "\(baseURL)\(path)"
        }

        guard let url = URL(string: fullURLStr) else { return }

        Task {
            if let (data, _) = try? await session.data(from: url), let img = NSImage(data: data) {
                await MainActor.run {
                    self.artwork = img
                    self.onUpdate?()
                }
            }
        }
    }

    // MARK: - Library Management

    /// Fetches all songs from http://127.0.0.1:5050/api/songs with local folder fallback.
    public func fetchLibrary() {
        guard let url = URL(string: "\(baseURL)/api/songs") else {
            scanLocalMusicFolder()
            return
        }

        Task {
            do {
                let (data, response) = try await session.data(from: url)
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                    let decoder = JSONDecoder()
                    if let songs = try? decoder.decode([MusicStudioTrack].self, from: data) {
                        await MainActor.run {
                            self.libraryTracks = songs
                            self.isAvailable = true
                            self.onUpdate?()
                        }
                        return
                    }
                }
            } catch {
                // Fallback to local files
            }

            await MainActor.run {
                self.scanLocalMusicFolder()
            }
        }
    }

    /// Fallback scan of ~/Music/Music Studio for .mp3 files when local server is offline.
    private func scanLocalMusicFolder() {
        let musicDir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Music/Music Studio")
        guard let files = try? FileManager.default.contentsOfDirectory(at: musicDir, includingPropertiesForKeys: nil) else { return }

        let mp3Files = files.filter { $0.pathExtension.lowercased() == "mp3" }
        var scanned: [MusicStudioTrack] = []
        for file in mp3Files {
            let filename = file.lastPathComponent
            let baseName = file.deletingPathExtension().lastPathComponent
            let parts = baseName.components(separatedBy: " - ")
            let title = parts.count > 1 ? parts[1].trimmingCharacters(in: .whitespaces) : baseName
            let artist = parts.count > 1 ? parts[0].trimmingCharacters(in: .whitespaces) : "Music Studio"

            scanned.append(MusicStudioTrack(
                filename: filename,
                title: title,
                artist: artist,
                album: "Music Studio Library"
            ))
        }

        self.libraryTracks = scanned.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        if !self.libraryTracks.isEmpty {
            self.isAvailable = true
        }
        self.onUpdate?()
    }

    /// Plays a specific track selected from the Music Studio library.
    public func playTrack(_ track: MusicStudioTrack) {
        self.currentTrack = Track(
            title: track.title,
            artist: track.artist,
            album: track.album,
            duration: track.duration
        )
        self.isPlaying = true
        self.isAvailable = true

        // 1. Dispatch play_track command to local Music Studio server
        sendAction("play_track", additionalFields: [
            "filename": track.filename,
            "title": track.title
        ])

        // 2. Fetch track artwork
        let encoded = track.filename.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? track.filename
        fetchCoverArtwork(coverURL: "/api/songs/artwork/\(encoded)")

        // 3. Native audio fallback for instant audio playback
        let localFileURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Music/Music Studio")
            .appendingPathComponent(track.filename)
        if FileManager.default.fileExists(atPath: localFileURL.path) {
            let item = AVPlayerItem(url: localFileURL)
            if self.localPlayer == nil {
                self.localPlayer = AVPlayer(playerItem: item)
            } else {
                self.localPlayer?.replaceCurrentItem(with: item)
            }
            self.localPlayer?.play()
        }

        self.onUpdate?()
    }

    // MARK: - Playback Actions

    public func play() {
        sendAction("play")
        localPlayer?.play()
        isPlaying = true
    }

    public func pause() {
        sendAction("pause")
        localPlayer?.pause()
        isPlaying = false
    }

    public func togglePlayPause() {
        sendAction("toggle")
        if isPlaying {
            localPlayer?.pause()
        } else {
            localPlayer?.play()
        }
        isPlaying.toggle()
    }

    public func next() {
        sendAction("next")
        localPlayer?.pause()
    }

    public func previous() {
        sendAction("prev")
        localPlayer?.pause()
    }

    private func sendAction(_ action: String, additionalFields: [String: Any]? = nil) {
        guard let url = URL(string: "\(baseURL)/api/playback/action") else { return }

        var payload: [String: Any] = ["action": action]
        if let extras = additionalFields {
            for (key, val) in extras {
                payload[key] = val
            }
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)

        Task {
            _ = try? await session.data(for: request)
            // Refresh state immediately following action
            try? await Task.sleep(nanoseconds: 200_000_000)
            self.fetchPlaybackState()
        }
    }
}
