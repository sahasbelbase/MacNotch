import SwiftUI

/// Elegant, responsive track browser for the user's local "Music Studio" library.
/// Supports search filtering, live playing indicator, track artwork, keyword function actions (play, pause, forward),
/// and instant playback.
public struct MusicStudioListView: View {
    @ObservedObject var musicStudioProvider: MusicStudioNowPlayingProvider
    @State private var searchText: String = ""

    public init(musicStudioProvider: MusicStudioNowPlayingProvider) {
        self.musicStudioProvider = musicStudioProvider
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

    private var filteredTracks: [MusicStudioTrack] {
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

    public var body: some View {
        VStack(spacing: 6) {
            // Search Bar & Track Count Header
            HStack(spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(DesignSystem.Colors.textTertiary)

                    TextField("Search \(musicStudioProvider.libraryTracks.count) songs or type play, pause, forward...", text: $searchText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 11))
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                        .onSubmit {
                            if let action = detectedKeywordAction {
                                executeKeywordAction(action)
                            } else if let first = filteredTracks.first {
                                musicStudioProvider.playTrack(first)
                            }
                        }

                    if !searchText.isEmpty {
                        Button(action: { searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 10))
                                .foregroundColor(DesignSystem.Colors.textTertiary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.white.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

                // Shuffle Play button
                Button(action: {
                    if let randomTrack = musicStudioProvider.libraryTracks.randomElement() {
                        musicStudioProvider.playTrack(randomTrack)
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "shuffle")
                            .font(.system(size: 10, weight: .semibold))
                        Text("Shuffle")
                            .font(.system(size: 10, weight: .medium))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Capsule())
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                }
                .buttonStyle(.plain)
                .help("Shuffle play Music Studio library")
            }
            .padding(.horizontal, 4)

            // Keyword Action Quick Execution Banner
            if let action = detectedKeywordAction {
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

            // Scrollable Track List
            if filteredTracks.isEmpty {
                VStack(spacing: 6) {
                    Spacer()
                    Image(systemName: "music.note.list")
                        .font(.system(size: 24))
                        .foregroundColor(DesignSystem.Colors.textTertiary)
                    Text(searchText.isEmpty ? "Loading Music Studio tracks..." : "No matching tracks found")
                        .font(.system(size: 11))
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView(.vertical, showsIndicators: true) {
                    LazyVStack(spacing: 2) {
                        ForEach(Array(filteredTracks.enumerated()), id: \.element.id) { index, track in
                            trackRow(track: track, index: index)
                        }
                    }
                    .padding(.horizontal, 2)
                    .padding(.vertical, 2)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
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
    }

    @ViewBuilder
    private func trackRow(track: MusicStudioTrack, index: Int) -> some View {
        let isCurrent = isTrackCurrent(track)

        Button(action: {
            musicStudioProvider.playTrack(track)
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
                TrackArtworkThumbnail(filename: track.filename, isPlaying: isCurrent)

                // Title & Artist
                VStack(alignment: .leading, spacing: 2) {
                    Text(track.title)
                        .font(.system(size: 11, weight: isCurrent ? .bold : .medium))
                        .foregroundColor(isCurrent ? .accentColor : DesignSystem.Colors.textPrimary)
                        .lineLimit(1)
                        .truncationMode(.tail)

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

                // Play / Pause Mini Button
                Image(systemName: isCurrent && musicStudioProvider.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 9))
                    .foregroundColor(isCurrent ? .accentColor : DesignSystem.Colors.textTertiary)
                    .frame(width: 18, height: 18)
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

/// Thumbnail view for a Music Studio track artwork
private struct TrackArtworkThumbnail: View {
    let filename: String
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
                Image(systemName: "music.note")
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
        let localFileURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Music/Music Studio")
            .appendingPathComponent(filename)
        if let img = MusicStudioNowPlayingProvider.extractArtwork(from: localFileURL) {
            self.image = img
            return
        }

        guard let encoded = filename.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
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
