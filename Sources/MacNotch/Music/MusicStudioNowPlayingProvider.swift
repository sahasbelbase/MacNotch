import AppKit
import AVFoundation
import Foundation

/// Represents a song in the user's local "Music Studio" library or an online stream.
public struct MusicStudioTrack: Identifiable, Codable, Hashable, Sendable {
    public var id: String { filename.isEmpty ? "\(artist)-\(title)" : filename }
    public let filename: String
    public let title: String
    public let artist: String
    public let album: String
    public let year: String?
    public let genre: String?
    public let duration: Double?
    public let size_mb: Double?
    public let bitrate: String?
    public let cover_url: String?
    public let query: String?

    public var isStream: Bool {
        filename.isEmpty || cover_url?.hasPrefix("http") == true || query != nil
    }

    public init(
        filename: String,
        title: String,
        artist: String,
        album: String,
        year: String? = nil,
        genre: String? = nil,
        duration: Double? = nil,
        size_mb: Double? = nil,
        bitrate: String? = nil,
        cover_url: String? = nil,
        query: String? = nil
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
        self.cover_url = cover_url
        self.query = query
    }
}

/// Native provider that communicates directly with the local "Music Studio" engine (port 5050).
/// Supports live metadata (title, artist, album, duration, elapsed time), library browsing, and transport actions.
///
/// NOTE: MacNotch acts purely as a remote HUD and controller. All audio decoding and playback is handled
/// exclusively by Music Studio's audio engine to prevent duplicate or conflicting audio streams.
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
    private var sseTask: Task<Void, Never>?
    private var lastCoverURL: String?
    private let session: URLSession
    private let imageCache = NSCache<NSURL, NSImage>()

    public init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 2.0
        config.timeoutIntervalForResource = 3.0
        self.session = URLSession(configuration: config)

        fetchLibrary()
        startPolling()
        startEventListener()
    }

    deinit {
        pollTimer?.invalidate()
        sseTask?.cancel()
    }

    // MARK: - Real-Time Synchronization & Polling

    public func startPolling() {
        stopPolling()
        fetchPlaybackState()

        // Schedule timer in .common mode so mouse tracking / notch hover does not freeze updates
        let timer = Timer(timeInterval: 0.4, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.fetchPlaybackState()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.pollTimer = timer
    }

    public func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    /// Connects to Music Studio SSE events stream (http://127.0.0.1:5050/api/events)
    /// for zero-latency real-time playback synchronization.
    public func startEventListener() {
        sseTask?.cancel()
        guard let url = URL(string: "\(baseURL)/api/events") else { return }

        sseTask = Task { [weak self] in
            while !Task.isCancelled {
                do {
                    let (bytes, response) = try await URLSession.shared.bytes(from: url)
                    guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                        try await Task.sleep(nanoseconds: 2_000_000_000)
                        continue
                    }

                    for try await line in bytes.lines {
                        if Task.isCancelled { break }
                        guard line.hasPrefix("data: ") else { continue }
                        let jsonStr = String(line.dropFirst(6))
                        guard let data = jsonStr.data(using: .utf8),
                              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                              let eventType = obj["type"] as? String else { continue }

                        if eventType == "playback", let playbackData = obj["data"] as? [String: Any] {
                            await MainActor.run { [weak self] in
                                self?.processPlaybackJSON(playbackData)
                            }
                        }
                    }
                } catch {
                    // Retry connection after brief backoff
                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                }
            }
        }
    }

    /// Queries http://127.0.0.1:5050/api/playback asynchronously.
    public func fetchPlaybackState() {
        guard let url = URL(string: "\(baseURL)/api/playback") else { return }

        Task {
            do {
                let (data, response) = try await session.data(from: url)
                guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                    return
                }

                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    self.processPlaybackJSON(json)
                }
            } catch {
                // Server temporarily unreachable
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

        if !title.isEmpty {
            self.isAvailable = true
            self.currentTrack = Track(
                title: title,
                artist: artist.isEmpty ? "Music Studio" : artist,
                album: album,
                duration: dur > 0 ? dur : nil
            )
        } else if playing {
            self.isAvailable = true
        }

        // Fetch cover artwork if available and changed
        if !coverURL.isEmpty && coverURL != lastCoverURL {
            self.lastCoverURL = coverURL
            fetchCoverArtwork(coverURL: coverURL)
        } else if coverURL.isEmpty && self.currentTrack == nil {
            self.lastCoverURL = nil
            self.artwork = nil
        }

        self.onUpdate?()
    }

    private func fetchCoverArtwork(coverURL: String) {
        if coverURL.isEmpty || coverURL.contains("placeholder.svg") {
            self.artwork = nil
            self.onUpdate?()
            return
        }

        // 1. Direct remote URL (from streaming services Deezer/iTunes)
        if coverURL.hasPrefix("http://") || coverURL.hasPrefix("https://") {
            guard let url = URL(string: coverURL) else { return }
            if let cached = imageCache.object(forKey: url as NSURL) {
                self.artwork = cached
                self.onUpdate?()
                return
            }
            Task {
                if let (data, _) = try? await session.data(from: url), let img = NSImage(data: data) {
                    await MainActor.run {
                        self.imageCache.setObject(img, forKey: url as NSURL)
                        self.artwork = img
                        self.onUpdate?()
                    }
                }
            }
            return
        }

        // 2. Check if artwork can be extracted locally from Music Studio library folder
        let musicDir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Music/Music Studio")
        if let current = currentTrack {
            let possibleFilenames = [
                "\(current.artist) - \(current.title).mp3",
                "\(current.title).mp3"
            ]
            for name in possibleFilenames {
                let fileURL = musicDir.appendingPathComponent(name)
                if let img = Self.extractArtwork(from: fileURL) {
                    self.artwork = img
                    self.onUpdate?()
                    return
                }
            }
        }

        // 3. Fallback to Music Studio local artwork API
        let path = coverURL.hasPrefix("/") ? coverURL : "/\(coverURL)"
        let fullURLStr = "\(baseURL)\(path)"
        guard let url = URL(string: fullURLStr) else { return }
        if let cached = imageCache.object(forKey: url as NSURL) {
            self.artwork = cached
            self.onUpdate?()
            return
        }

        Task {
            if let (data, _) = try? await session.data(from: url), let img = NSImage(data: data) {
                await MainActor.run {
                    self.imageCache.setObject(img, forKey: url as NSURL)
                    self.artwork = img
                    self.onUpdate?()
                }
            }
        }
    }

    // MARK: - Artwork Extraction

    /// Synchronously extracts embedded ID3 APIC cover artwork from a local audio file.
    public static func extractArtwork(from fileURL: URL) -> NSImage? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        let asset = AVURLAsset(url: fileURL)
        let items = AVMetadataItem.metadataItems(from: asset.metadata, filteredByIdentifier: .commonIdentifierArtwork)
        if let first = items.first, let data = first.dataValue, let img = NSImage(data: data) {
            return img
        }
        return nil
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
                            if self.currentTrack == nil, let first = songs.first {
                                self.currentTrack = Track(
                                    title: first.title,
                                    artist: first.artist,
                                    album: first.album,
                                    duration: first.duration
                                )
                                let localFileURL = FileManager.default.homeDirectoryForCurrentUser
                                    .appendingPathComponent("Music/Music Studio")
                                    .appendingPathComponent(first.filename)
                                if let img = Self.extractArtwork(from: localFileURL) {
                                    self.artwork = img
                                } else {
                                    let encoded = first.filename.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? first.filename
                                    self.fetchCoverArtwork(coverURL: "/api/songs/artwork/\(encoded)")
                                }
                            }
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
            if self.currentTrack == nil, let first = self.libraryTracks.first {
                self.currentTrack = Track(
                    title: first.title,
                    artist: first.artist,
                    album: first.album,
                    duration: first.duration
                )
                let localFileURL = musicDir.appendingPathComponent(first.filename)
                if let img = Self.extractArtwork(from: localFileURL) {
                    self.artwork = img
                }
            }
        }
        self.onUpdate?()
    }

    // MARK: - Playback Actions (Dispatched Exclusively to Music Studio)

    /// Plays a specific track selected from the Music Studio library or streams it online.
    public func playTrack(_ track: MusicStudioTrack) {
        if track.isStream {
            streamTrack(track)
            return
        }

        self.currentTrack = Track(
            title: track.title,
            artist: track.artist,
            album: track.album,
            duration: track.duration
        )
        self.isPlaying = true
        self.isAvailable = true
        self.currentTime = 0
        self.duration = track.duration ?? 0

        // Extract cover artwork immediately from local file or fetch from server
        let localFileURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Music/Music Studio")
            .appendingPathComponent(track.filename)
        if let img = Self.extractArtwork(from: localFileURL) {
            self.artwork = img
        } else {
            let encoded = track.filename.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? track.filename
            fetchCoverArtwork(coverURL: "/api/songs/artwork/\(encoded)")
        }

        // Dispatch play_track command to Music Studio engine (auto-launching app if closed)
        sendAction("play_track", additionalFields: [
            "filename": track.filename,
            "title": track.title
        ])

        self.onUpdate?()
    }

    // MARK: - Library Management

    /// Deletes a track permanently from the Music Studio library and disk.
    @discardableResult
    public func deleteTrack(_ track: MusicStudioTrack) async -> Bool {
        guard !track.filename.isEmpty else { return false }
        let encoded = track.filename.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? track.filename

        var success = false
        if let url = URL(string: "\(baseURL)/api/songs/\(encoded)") {
            var request = URLRequest(url: url)
            request.httpMethod = "DELETE"
            if let (_, response) = try? await session.data(for: request),
               let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) {
                success = true
            }
        }

        // Fallback to direct file removal on disk if server is offline or unreachable
        let localFileURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Music/Music Studio")
            .appendingPathComponent(track.filename)
        if FileManager.default.fileExists(atPath: localFileURL.path) {
            try? FileManager.default.removeItem(at: localFileURL)
            success = true
        }

        if success {
            self.libraryTracks.removeAll { $0.filename == track.filename }
            if self.currentTrack?.title == track.title && self.currentTrack?.artist == track.artist {
                self.isPlaying = false
                self.currentTrack = nil
                self.artwork = nil
                self.currentTime = 0
                self.duration = 0
            }
            self.onUpdate?()
            self.fetchLibrary()
        }

        return success
    }

    /// Streams an online song on-the-fly via Music Studio audio engine.
    public func streamTrack(_ track: MusicStudioTrack) {
        self.currentTrack = Track(
            title: track.title,
            artist: track.artist,
            album: track.album,
            duration: track.duration
        )
        self.isPlaying = true
        self.isAvailable = true
        self.currentTime = 0
        self.duration = track.duration ?? 0

        if let cover = track.cover_url, !cover.isEmpty {
            self.lastCoverURL = cover
            fetchCoverArtwork(coverURL: cover)
        }

        let payloadDict: [String: Any] = [
            "title": track.title,
            "artist": track.artist,
            "album": track.album,
            "duration": track.duration ?? 0,
            "cover_url": track.cover_url ?? "",
            "query": track.query ?? "\(track.artist) - \(track.title)"
        ]

        var jsonString = ""
        if let data = try? JSONSerialization.data(withJSONObject: payloadDict),
           let str = String(data: data, encoding: .utf8) {
            jsonString = str
        }

        sendAction("stream_track", additionalFields: [
            "title": track.title,
            "filename": jsonString,
            "query": track.query ?? "\(track.artist) - \(track.title)"
        ])

        self.onUpdate?()
    }

    // MARK: - Online Music Discovery & Search

    /// Searches millions of songs online via Music Studio's explore API.
    public func searchOnlineTracks(query: String) async -> [MusicStudioTrack] {
        let clean = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty,
              let encoded = clean.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "\(baseURL)/api/explore/search?q=\(encoded)&type=tracks") else {
            return []
        }

        do {
            let (data, response) = try await session.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                return []
            }

            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return []
            }

            let rawTracks = (json["tracks"] as? [[String: Any]]) ?? (json["results"] as? [[String: Any]]) ?? []
            return rawTracks.compactMap { dict in
                guard let title = dict["title"] as? String, !title.isEmpty else { return nil }
                let artist = (dict["artist"] as? String) ?? "Music Studio"
                let album = (dict["album"] as? String) ?? "Online Stream"
                let dur = (dict["duration"] as? Double) ?? Double((dict["duration"] as? Int) ?? 0)
                let cover = (dict["cover_url"] as? String) ?? ""
                let q = (dict["query"] as? String) ?? "\(artist) - \(title)"

                return MusicStudioTrack(
                    filename: "",
                    title: title,
                    artist: artist,
                    album: album,
                    duration: dur > 0 ? dur : nil,
                    cover_url: cover,
                    query: q
                )
            }
        } catch {
            return []
        }
    }

    /// Fetches trending/popular hits online when no query is entered.
    public func fetchTrendingTracks() async -> [MusicStudioTrack] {
        let results = await searchOnlineTracks(query: "Top Hits 2026")
        if !results.isEmpty { return results }
        return await searchOnlineTracks(query: "Billboard Hits")
    }

    public func play() {
        self.isPlaying = true
        self.isAvailable = true

        if currentTrack != nil {
            // Resume playback of current track from its paused position without resetting to 0:00
            sendAction("play")
        } else if let first = libraryTracks.first {
            // First-time play when no track was loaded
            playTrack(first)
            return
        } else {
            sendAction("play")
        }
        self.onUpdate?()
    }

    public func pause() {
        self.isPlaying = false
        sendAction("pause")
        self.onUpdate?()
    }

    public func togglePlayPause() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }

    public func next() {
        sendAction("next")
        // If track is in library, predictively advance current track display
        if let current = currentTrack,
           let currentIndex = libraryTracks.firstIndex(where: { $0.title.lowercased() == current.title.lowercased() }) {
            let nextIndex = (currentIndex + 1) % libraryTracks.count
            let nextTrack = libraryTracks[nextIndex]
            self.currentTrack = Track(
                title: nextTrack.title,
                artist: nextTrack.artist,
                album: nextTrack.album,
                duration: nextTrack.duration
            )
            let localFileURL = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Music/Music Studio")
                .appendingPathComponent(nextTrack.filename)
            if let img = Self.extractArtwork(from: localFileURL) {
                self.artwork = img
            }
        }
        self.onUpdate?()
    }

    public func previous() {
        sendAction("prev")
        // If track is in library, predictively rewind current track display
        if let current = currentTrack,
           let currentIndex = libraryTracks.firstIndex(where: { $0.title.lowercased() == current.title.lowercased() }) {
            let prevIndex = (currentIndex - 1 + libraryTracks.count) % libraryTracks.count
            let prevTrack = libraryTracks[prevIndex]
            self.currentTrack = Track(
                title: prevTrack.title,
                artist: prevTrack.artist,
                album: prevTrack.album,
                duration: prevTrack.duration
            )
            let localFileURL = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Music/Music Studio")
                .appendingPathComponent(prevTrack.filename)
            if let img = Self.extractArtwork(from: localFileURL) {
                self.artwork = img
            }
        }
        self.onUpdate?()
    }

    public func seek(to seconds: Double) {
        self.currentTime = seconds
        sendAction("seek", additionalFields: ["time": seconds])
        self.onUpdate?()
    }

    /// Brings the running Music Studio window to the foreground or launches the app if not running.
    public func bringMusicStudioToFront() {
        let running = NSRunningApplication.runningApplications(withBundleIdentifier: "com.musicstudio.app")
        if let app = running.first {
            app.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
            return
        }

        let appURL = URL(fileURLWithPath: "/Applications/Music Studio.app")
        if FileManager.default.fileExists(atPath: appURL.path) {
            let config = NSWorkspace.OpenConfiguration()
            config.activates = true
            NSWorkspace.shared.openApplication(at: appURL, configuration: config, completionHandler: nil)
        } else {
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: "/usr/bin/open")
            proc.arguments = ["-a", "Music Studio"]
            try? proc.run()
        }
    }

    // MARK: - Process Lifecycle & Background Auto-Launch

    /// Checks whether Music Studio is running and responding; if closed, launches it in the background
    /// and waits until the local API server on port 5050 is online before dispatching playback actions.
    public func ensureMusicStudioRunning(completion: @escaping (Bool) -> Void) {
        let isAppRunning = !NSRunningApplication.runningApplications(withBundleIdentifier: "com.musicstudio.app").isEmpty

        if isAppRunning {
            pingServer { [weak self] isResponding in
                if isResponding {
                    completion(true)
                } else {
                    self?.waitForServerToComeOnline(maxAttempts: 25, delayMs: 200, completion: completion)
                }
            }
        } else {
            // App is not running (e.g. was quit or force quit). Launch silently in background.
            launchMusicStudioInBackground { [weak self] launched in
                guard launched else {
                    completion(false)
                    return
                }

                self?.waitForServerToComeOnline(maxAttempts: 35, delayMs: 200) { online in
                    if online {
                        self?.startEventListener()
                        self?.fetchLibrary()
                        // Brief pause to allow WebKit to finish loading HTML/JS and establish SSE connection
                        Task { @MainActor in
                            try? await Task.sleep(nanoseconds: 600_000_000)
                            completion(true)
                        }
                    } else {
                        completion(false)
                    }
                }
            }
        }
    }

    private func pingServer(completion: @escaping (Bool) -> Void) {
        guard let url = URL(string: "\(baseURL)/api/playback") else {
            completion(false)
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 0.8

        Task {
            do {
                let (_, response) = try await session.data(for: request)
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                    await MainActor.run { completion(true) }
                    return
                }
            } catch {
                // Server offline
            }
            await MainActor.run { completion(false) }
        }
    }

    private func launchMusicStudioInBackground(completion: @escaping (Bool) -> Void) {
        let appURL = URL(fileURLWithPath: "/Applications/Music Studio.app")
        guard FileManager.default.fileExists(atPath: appURL.path) else {
            completion(false)
            return
        }

        let config = NSWorkspace.OpenConfiguration()
        config.activates = false // Launch in background without stealing focus
        config.addsToRecentItems = false

        NSWorkspace.shared.openApplication(at: appURL, configuration: config) { app, error in
            Task { @MainActor in
                if error == nil || app != nil {
                    completion(true)
                } else {
                    // Fallback to command line open -g -a "Music Studio"
                    let proc = Process()
                    proc.executableURL = URL(fileURLWithPath: "/usr/bin/open")
                    proc.arguments = ["-g", "-a", "Music Studio"]
                    try? proc.run()
                    proc.waitUntilExit()
                    completion(proc.terminationStatus == 0)
                }
            }
        }
    }

    private func waitForServerToComeOnline(maxAttempts: Int, delayMs: UInt64, completion: @escaping (Bool) -> Void) {
        Task {
            for _ in 0..<maxAttempts {
                if await checkServerRespondingAsync() {
                    await MainActor.run {
                        completion(true)
                    }
                    return
                }
                try? await Task.sleep(nanoseconds: delayMs * 1_000_000)
            }
            await MainActor.run {
                completion(false)
            }
        }
    }

    private func checkServerRespondingAsync() async -> Bool {
        guard let url = URL(string: "\(baseURL)/api/playback") else { return false }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 0.5
        do {
            let (_, response) = try await session.data(for: request)
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                return true
            }
        } catch {
            return false
        }
        return false
    }

    private func sendAction(_ action: String, additionalFields: [String: Any]? = nil) {
        ensureMusicStudioRunning { [weak self] ready in
            guard let self = self, ready else { return }
            self.dispatchActionPayloadWithRetry(action, additionalFields: additionalFields)
        }
    }

    private func dispatchActionPayloadWithRetry(
        _ action: String,
        additionalFields: [String: Any]? = nil,
        attemptsLeft: Int = 3
    ) {
        dispatchActionPayload(action, additionalFields: additionalFields)

        // For play / play_track commands, verify playback begins.
        // If Music Studio was just launched in the background, WebKit may take ~0.8-1.2s to connect its SSE stream.
        if (action == "play" || action == "play_track" || action == "stream_track") && attemptsLeft > 0 {
            Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: 700_000_000)
                guard let self = self else { return }
                if !self.isPlaying {
                    self.dispatchActionPayloadWithRetry(
                        action,
                        additionalFields: additionalFields,
                        attemptsLeft: attemptsLeft - 1
                    )
                }
            }
        }
    }

    private func dispatchActionPayload(_ action: String, additionalFields: [String: Any]? = nil) {
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
            // Query fresh playback state shortly after dispatching action
            try? await Task.sleep(nanoseconds: 200_000_000)
            self.fetchPlaybackState()
        }
    }
}
