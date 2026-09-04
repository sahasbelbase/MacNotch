import AppKit
import Foundation

/// Native provider that communicates directly with the local "Music Studio" engine (port 5050).
/// Supports live metadata (title, artist, album, duration, elapsed time) and transport actions.
@MainActor
public final class MusicStudioNowPlayingProvider: NowPlayingProvider, ObservableObject {
    public let providerName: String = "Music Studio"

    @Published public private(set) var isPlaying: Bool = false
    @Published public private(set) var currentTrack: Track?
    @Published public private(set) var artwork: NSImage?
    @Published public private(set) var isAvailable: Bool = false
    @Published public private(set) var currentTime: Double = 0
    @Published public private(set) var duration: Double = 0

    public var onUpdate: (() -> Void)?

    private let baseURL = "http://127.0.0.1:5050"
    private var pollTimer: Timer?
    private var lastCoverURL: String?
    private let session: URLSession

    public init() {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 1.0
        config.timeoutIntervalForResource = 1.5
        self.session = URLSession(configuration: config)

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

    // MARK: - Playback Actions

    public func play() {
        sendAction("play")
        isPlaying = true
    }

    public func pause() {
        sendAction("pause")
        isPlaying = false
    }

    public func togglePlayPause() {
        sendAction("toggle")
        isPlaying.toggle()
    }

    public func next() {
        sendAction("next")
    }

    public func previous() {
        sendAction("prev")
    }

    private func sendAction(_ action: String) {
        guard let url = URL(string: "\(baseURL)/api/playback/action") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["action": action])

        Task {
            _ = try? await session.data(for: request)
            // Refresh state immediately following action
            try? await Task.sleep(nanoseconds: 200_000_000)
            self.fetchPlaybackState()
        }
    }
}
