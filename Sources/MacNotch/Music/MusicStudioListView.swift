import SwiftUI

/// Elegant, responsive track browser for the user's "Music Studio" library and online streaming catalog.
/// Supports search filtering, live playing indicator, track artwork (both local ID3 and remote CDN),
/// keyword function actions (play, pause, forward), and instant online audio streaming.
public struct MusicStudioListView: View {
    @ObservedObject var musicStudioProvider: MusicStudioNowPlayingProvider
    @State private var searchText: String = ""
    @State private var selectedTab: BrowserTab = .library
    @State private var onlineTracks: [MusicStudioTrack] = []
    @State private var isSearchingOnline: Bool = false
    @State private var searchDebounceTask: Task<Void, Never>? = nil
    @State private var trackToDelete: MusicStudioTrack? = nil
    @State private var showDeleteAlert: Bool = false

    public init(musicStudioProvider: MusicStudioNowPlayingProvider) {
        self.musicStudioProvider = musicStudioProvider
    }

    public enum BrowserTab: String, CaseIterable {
        case library = "Library"
        case stream = "Stream Online"
    }

    public enum KeywordAction: Equatable {
        case play
        case pause
        case forward
        case previous
        case playTrack(MusicStudioTrack)

        public var title: String {
            switch self {
            case .play: return "Play"
            case .pause: return "Pause"
            case .forward: return "Forward (Next Song)"
            case .previous: return "Previous (Rewind)"
            case .playTrack(let track): return "Play \"\(track.title)\""
            }
        }

        public var icon: String {
            switch self {
            case .play: return "play.fill"
            case .pause: return "pause.fill"
            case .forward: return "forward.fill"
            case .previous: return "backward.fill"
            case .playTrack: return "play.circle.fill"
            }
        }
    }

    private var detectedKeywordAction: KeywordAction? {
        let trimmed = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        guard !trimmed.isEmpty else { return nil }

        if trimmed == "play" {
            return .play
        } else if trimmed == "pause" {
            return .pause
        } else if trimmed == "forward" || trimmed == "next" {
            return .forward
        } else if trimmed == "backward" || trimmed == "back" || trimmed == "prev" || trimmed == "previous" {
            return .previous
        } else if trimmed.hasPrefix("play ") {
            let query = String(trimmed.dropFirst(5)).trimmingCharacters(in: .whitespaces)
            if let match = musicStudioProvider.libraryTracks.first(where: {
                $0.title.lowercased().contains(query) || $0.artist.lowercased().contains(query)
            }) {
                return .playTrack(match)
            } else {
                return .play
            }
        }
        return nil
    }

    private func executeKeywordAction(_ action: KeywordAction) {
        switch action {
        case .play:
            musicStudioProvider.play()
        case .pause:
            musicStudioProvider.pause()
        case .forward:
            musicStudioProvider.next()
        case .previous:
            musicStudioProvider.previous()
        case .playTrack(let track):
            musicStudioProvider.playTrack(track)
        }
    }

    private var filteredLocalTracks: [MusicStudioTrack] {
        let tracks = musicStudioProvider.libraryTracks
        let query = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        guard !query.isEmpty else {
            return tracks
        }

        // If query is an exact keyword like "play", "pause", "forward", don't overly filter the whole list away
        if query == "play" || query == "pause" || query == "forward" || query == "next" || query == "prev" {
            return tracks
        }

        let searchQuery = query.hasPrefix("play ") ? String(query.dropFirst(5)).trimmingCharacters(in: .whitespaces) : query
        guard !searchQuery.isEmpty else { return tracks }

        return tracks.filter {
            $0.title.lowercased().contains(searchQuery) ||
            $0.artist.lowercased().contains(searchQuery) ||
            $0.album.lowercased().contains(searchQuery)
        }
    }

    private func triggerOnlineSearch() {
        searchDebounceTask?.cancel()
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        searchDebounceTask = Task {
            try? await Task.sleep(nanoseconds: 250_000_000)
            if Task.isCancelled { return }

            await MainActor.run { isSearchingOnline = true }

            let results: [MusicStudioTrack]
            if query.isEmpty {
                results = await musicStudioProvider.fetchTrendingTracks()
            } else {
                results = await musicStudioProvider.searchOnlineTracks(query: query)
            }

            if !Task.isCancelled {
                await MainActor.run {
                    self.onlineTracks = results
                    self.isSearchingOnline = false
                }
            }
        }
    }

    public var body: some View {
        VStack(spacing: 6) {
            // Mode Selector & Quick Controls Bar
            HStack(spacing: 6) {
                // Tab Switcher Pills
                HStack(spacing: 3) {
                    Button(action: {
                        selectedTab = .library
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "music.note.list")
                                .font(.system(size: 9, weight: .semibold))
                            Text("Library (\(musicStudioProvider.libraryTracks.count))")
                                .font(.system(size: 10, weight: selectedTab == .library ? .bold : .medium))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3.5)
                        .background(selectedTab == .library ? Color.accentColor : Color.white.opacity(0.08))
                        .clipShape(Capsule())
                        .foregroundColor(selectedTab == .library ? .white : DesignSystem.Colors.textSecondary)
                    }
                    .buttonStyle(.plain)

                    Button(action: {
                        selectedTab = .stream
                        if onlineTracks.isEmpty {
                            triggerOnlineSearch()
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "globe")
                                .font(.system(size: 9, weight: .semibold))
                            Text("Stream Online")
                                .font(.system(size: 10, weight: selectedTab == .stream ? .bold : .medium))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3.5)
                        .background(selectedTab == .stream ? Color.accentColor : Color.white.opacity(0.08))
                        .clipShape(Capsule())
                        .foregroundColor(selectedTab == .stream ? .white : DesignSystem.Colors.textSecondary)
                    }
                    .buttonStyle(.plain)
                }

                Spacer()

                if selectedTab == .library {
                    // Shuffle Play button
                    Button(action: {
                        if let randomTrack = musicStudioProvider.libraryTracks.randomElement() {
                            musicStudioProvider.playTrack(randomTrack)
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "shuffle")
                                .font(.system(size: 9, weight: .semibold))
                            Text("Shuffle")
                                .font(.system(size: 10, weight: .medium))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3.5)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Capsule())
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                    }
                    .buttonStyle(.plain)
                    .help("Shuffle play local library")
                } else {
                    HStack(spacing: 6) {
                        if isSearchingOnline {
                            ProgressView()
                                .scaleEffect(0.6)
                                .frame(width: 14, height: 14)
                        }

                        if !onlineTracks.isEmpty {
                            Button(action: {
                                if let randomTrack = onlineTracks.randomElement() {
                                    musicStudioProvider.streamTrack(randomTrack)
                                }
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "shuffle")
                                        .font(.system(size: 9, weight: .semibold))
                                    Text("Shuffle Stream")
                                        .font(.system(size: 10, weight: .medium))
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3.5)
                                .background(Color.white.opacity(0.08))
                                .clipShape(Capsule())
                                .foregroundColor(DesignSystem.Colors.textPrimary)
                            }
                            .buttonStyle(.plain)
                            .help("Shuffle play online stream tracks")
                        }
                    }
                }
            }
            .padding(.horizontal, 4)

            // Search Bar
            HStack(spacing: 6) {
                Image(systemName: selectedTab == .stream ? "network" : "magnifyingglass")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(DesignSystem.Colors.textTertiary)

                TextField(
                    selectedTab == .stream
                        ? "Search millions of songs to stream live..."
                        : "Search \(musicStudioProvider.libraryTracks.count) songs or type play, pause, forward...",
                    text: $searchText
                )
                .textFieldStyle(.plain)
                .font(.system(size: 11))
                .foregroundColor(DesignSystem.Colors.textPrimary)
                .onChange(of: searchText) { _ in
                    if selectedTab == .stream {
                        triggerOnlineSearch()
                    }
                }
                .onSubmit {
                    if selectedTab == .library {
                        if let action = detectedKeywordAction {
                            executeKeywordAction(action)
                        } else if let first = filteredLocalTracks.first {
                            musicStudioProvider.playTrack(first)
                        }
                    } else {
                        if let first = onlineTracks.first {
                            musicStudioProvider.streamTrack(first)
                        }
                    }
                }

                if !searchText.isEmpty {
                    Button(action: {
                        searchText = ""
                        if selectedTab == .stream {
                            triggerOnlineSearch()
                        }
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 10))
                            .foregroundColor(DesignSystem.Colors.textTertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4.5)
            .background(Color.white.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .padding(.horizontal, 4)

            // Keyword Action Quick Execution Banner (in library mode)
            if selectedTab == .library, let action = detectedKeywordAction {
                Button(action: {
                    executeKeywordAction(action)
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: action.icon)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 20, height: 20)
                            .background(Color.white.opacity(0.2))
                            .clipShape(Circle())

                        Text("Function: \(action.title)")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.white)

                        Spacer()

                        Text("Press ↵ Return")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.black.opacity(0.25))
                            .clipShape(Capsule())
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        LinearGradient(
                            colors: [Color.accentColor.opacity(0.85), Color.purple.opacity(0.85)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 4)
            }

            // Fallback prompt: If searching in library returns 0, offer to stream online
            if selectedTab == .library && filteredLocalTracks.isEmpty && !searchText.isEmpty {
                Button(action: {
                    selectedTab = .stream
                    triggerOnlineSearch()
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "globe")
                            .font(.system(size: 10))
                        Text("Search & stream \"\(searchText)\" online ➔")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundColor(.accentColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.accentColor.opacity(0.12))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .padding(.vertical, 4)
            }

            // Scrollable Track List
            Group {
                if selectedTab == .library {
                    libraryListView
                } else {
                    onlineStreamListView
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            if musicStudioProvider.libraryTracks.isEmpty {
                musicStudioProvider.fetchLibrary()
            }
        }
        .onKeyPress(.space) {
            if searchText.isEmpty {
                musicStudioProvider.togglePlayPause()
                return .handled
            }
            return .ignored
        }
        .onKeyPress(.rightArrow) {
            musicStudioProvider.next()
            return .handled
        }
        .onKeyPress(.leftArrow) {
            musicStudioProvider.previous()
            return .handled
        }
        .alert("Delete Track?", isPresented: $showDeleteAlert, presenting: trackToDelete) { track in
            Button("Cancel", role: .cancel) {
                trackToDelete = nil
            }
            Button("Delete", role: .destructive) {
                Task {
                    _ = await musicStudioProvider.deleteTrack(track)
                    trackToDelete = nil
                }
            }
        } message: { track in
            Text("Are you sure you want to delete \"\(track.title)\" by \(track.artist)? This will permanently remove the audio file from your library and computer.")
        }
    }

    // MARK: - Library List View
    private var libraryListView: some View {
        Group {
            if filteredLocalTracks.isEmpty {
                VStack(spacing: 6) {
                    Spacer()
                    Image(systemName: "music.note.list")
                        .font(.system(size: 24))
                        .foregroundColor(DesignSystem.Colors.textTertiary)
                    if musicStudioProvider.isAvailable {
                        Text(searchText.isEmpty ? "No tracks in Music Studio library" : "No matching local tracks")
                            .font(.system(size: 11))
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    } else {
                        Text("Music Studio Not Running")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                        Text("Smart Audio active: playing via Spotify, Apple Music, or system media.")
                            .font(.system(size: 10))
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }
                    Spacer()
                }
            } else {
                ScrollView(.vertical, showsIndicators: true) {
                    LazyVStack(spacing: 2) {
                        ForEach(Array(filteredLocalTracks.enumerated()), id: \.element.id) { index, track in
                            trackRow(track: track, index: index, isOnline: false)
                        }
                    }
                    .padding(.horizontal, 2)
                    .padding(.vertical, 2)
                }
            }
        }
    }

    // MARK: - Online Stream List View
    private var onlineStreamListView: some View {
        Group {
            if isSearchingOnline && onlineTracks.isEmpty {
                VStack(spacing: 8) {
                    Spacer()
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Searching online streams...")
                        .font(.system(size: 11))
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                    Spacer()
                }
            } else if onlineTracks.isEmpty {
                VStack(spacing: 6) {
                    Spacer()
                    Image(systemName: "waveform.badge.magnifyingglass")
                        .font(.system(size: 24))
                        .foregroundColor(DesignSystem.Colors.textTertiary)
                    Text(searchText.isEmpty ? "Search for any artist, song, or album" : "No online results found for \"\(searchText)\"")
                        .font(.system(size: 11))
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                    Spacer()
                }
            } else {
                ScrollView(.vertical, showsIndicators: true) {
                    LazyVStack(spacing: 2) {
                        ForEach(Array(onlineTracks.enumerated()), id: \.element.id) { index, track in
                            trackRow(track: track, index: index, isOnline: true)
                        }
                    }
                    .padding(.horizontal, 2)
                    .padding(.vertical, 2)
                }
            }
        }
    }

    @ViewBuilder
    private func trackRow(track: MusicStudioTrack, index: Int, isOnline: Bool) -> some View {
        let isCurrent = isTrackCurrent(track)

        Button(action: {
            if isOnline || track.isStream {
                musicStudioProvider.streamTrack(track)
            } else {
                musicStudioProvider.playTrack(track)
            }
        }) {
            HStack(spacing: 10) {
                // Index / Live Equalizer Icon
                ZStack {
                    if isCurrent && musicStudioProvider.isPlaying {
                        Image(systemName: "waveform")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.accentColor)
                    } else {
                        Text("\(index + 1)")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(isCurrent ? .accentColor : DesignSystem.Colors.textTertiary)
                    }
                }
                .frame(width: 20, alignment: .center)

                // Track Artwork Thumbnail
                TrackArtworkThumbnail(track: track, isPlaying: isCurrent)

                // Title & Artist
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(track.title)
                            .font(.system(size: 11, weight: isCurrent ? .bold : .medium))
                            .foregroundColor(isCurrent ? .accentColor : DesignSystem.Colors.textPrimary)
                            .lineLimit(1)
                            .truncationMode(.tail)

                        if isOnline || track.isStream {
                            Text("STREAM")
                                .font(.system(size: 7, weight: .heavy))
                                .foregroundColor(.white)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(Color.accentColor.opacity(0.8))
                                .clipShape(Capsule())
                        }
                    }

                    Text(track.artist.isEmpty ? "Music Studio" : track.artist)
                        .font(.system(size: 9))
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // Duration
                if let dur = track.duration, dur > 0 {
                    Text(formatDuration(dur))
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(DesignSystem.Colors.textTertiary)
                }

                // Play / Stream Mini Action Button
                Image(systemName: isCurrent && musicStudioProvider.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 9))
                    .foregroundColor(isCurrent ? .accentColor : DesignSystem.Colors.textTertiary)
                    .frame(width: 18, height: 18)

                // Delete Mini Action Button (for downloaded library songs)
                if !isOnline && !track.isStream {
                    Button(action: {
                        trackToDelete = track
                        showDeleteAlert = true
                    }) {
                        Image(systemName: "trash")
                            .font(.system(size: 9))
                            .foregroundColor(DesignSystem.Colors.textTertiary.opacity(0.75))
                            .frame(width: 18, height: 18)
                    }
                    .buttonStyle(.plain)
                    .help("Delete \"\(track.title)\" from Library")
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isCurrent ? Color.accentColor.opacity(0.12) : Color.white.opacity(0.03))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            if !isOnline && !track.isStream {
                Button(role: .destructive, action: {
                    trackToDelete = track
                    showDeleteAlert = true
                }) {
                    Label("Delete from Library", systemImage: "trash")
                }
            }
        }
    }

    private func isTrackCurrent(_ track: MusicStudioTrack) -> Bool {
        guard let current = musicStudioProvider.currentTrack else { return false }
        return current.title.lowercased() == track.title.lowercased()
    }

    private func formatDuration(_ seconds: Double) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

/// Thumbnail view for a Music Studio track artwork supporting both local ID3 and remote CDN covers
private struct TrackArtworkThumbnail: View {
    let track: MusicStudioTrack
    let isPlaying: Bool
    @State private var image: NSImage?

    var body: some View {
        ZStack {
            if let img = image {
                Image(nsImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                LinearGradient(
                    colors: [Color.pink.opacity(0.7), Color.purple.opacity(0.7)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                Image(systemName: track.isStream ? "waveform.badge.magnifyingglass" : "music.note")
                    .font(.system(size: 9))
                    .foregroundColor(.white)
            }
        }
        .frame(width: 26, height: 26)
        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
        .onAppear {
            loadArtwork()
        }
    }

    private func loadArtwork() {
        // 1. Direct remote cover URL (for streamed songs)
        if let cover = track.cover_url, cover.hasPrefix("http") {
            guard let url = URL(string: cover) else { return }
            Task {
                if let (data, _) = try? await URLSession.shared.data(from: url),
                   let img = NSImage(data: data) {
                    await MainActor.run {
                        self.image = img
                    }
                }
            }
            return
        }

        // 2. Local Music Studio library ID3 extraction
        if !track.filename.isEmpty {
            let localFileURL = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Music/Music Studio")
                .appendingPathComponent(track.filename)
            if let img = MusicStudioNowPlayingProvider.extractArtwork(from: localFileURL) {
                self.image = img
                return
            }

            guard let encoded = track.filename.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
                  let url = URL(string: "http://127.0.0.1:5050/api/songs/artwork/\(encoded)") else { return }

            Task {
                if let (data, _) = try? await URLSession.shared.data(from: url),
                   let img = NSImage(data: data) {
                    await MainActor.run {
                        self.image = img
                    }
                }
            }
        }
    }
}
