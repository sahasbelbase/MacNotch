import SwiftUI

/// Displays now playing information and playback controls for Apple Music, Spotify, or any system media player.
public struct MusicView: View {
    @ObservedObject var nowPlayingService: SystemNowPlayingService
    public var isCompact: Bool = false
    public var isFullTab: Bool = false
    public var isHero: Bool = false
    public var onOpenLibrary: (() -> Void)? = nil

    public init(
        nowPlayingService: SystemNowPlayingService,
        isCompact: Bool = false,
        isFullTab: Bool = false,
        isHero: Bool = false,
        onOpenLibrary: (() -> Void)? = nil
    ) {
        self.nowPlayingService = nowPlayingService
        self.isCompact = isCompact
        self.isFullTab = isFullTab
        self.isHero = isHero
        self.onOpenLibrary = onOpenLibrary
    }

    public var body: some View {
        if isCompact {
            compactView
        } else if isHero {
            heroCardView
        } else if isFullTab {
            fullTabView
        } else {
            horizontalBarView
        }
    }

    // MARK: - Compact View (Header status pill)
    private var compactView: some View {
        HStack(spacing: 5) {
            if nowPlayingService.isPlaying {
                WaveformVisualizerView(isPlaying: true, color: .pink, barCount: 4, maxHeight: 10)
            } else {
                Image(systemName: "music.note")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.pink)
            }

            if let track = nowPlayingService.currentTrack {
                Text(track.title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: 140)
            } else {
                Text("Not Playing")
                    .font(.system(size: 11))
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }
        }
    }

    // MARK: - Hero Card View (Used as Main Hero in Overview tab)
    private var heroCardView: some View {
        HStack(spacing: 14) {
            // Album Art or Music Gradient Icon (Click to open Music Studio)
            coverArtButton(size: 52, cornerRadius: 10)

            // Track Details & Player Badge
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(nowPlayingService.currentTrack?.title ?? "No Track Playing")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                        .lineLimit(1)
                        .truncationMode(.tail)

                    if nowPlayingService.isPlaying {
                        WaveformVisualizerView(isPlaying: true, color: DesignSystem.Colors.emerald, barCount: 4, maxHeight: 10)
                    }

                    if let player = nowPlayingService.activePlayerName {
                        Button(action: { openActivePlayer() }) {
                            Text(player)
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.accentColor)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(Color.accentColor.opacity(0.15))
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .pointingHandCursor()
                        .help("Open \(player)")
                    }

                    if !nowPlayingService.musicStudioProvider.libraryTracks.isEmpty {
                        Button(action: { onOpenLibrary?() }) {
                            HStack(spacing: 3) {
                                Image(systemName: "music.note.list")
                                    .font(.system(size: 8))
                                Text("\(nowPlayingService.musicStudioProvider.libraryTracks.count) Songs")
                                    .font(.system(size: 9, weight: .semibold))
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1.5)
                            .background(Color.white.opacity(0.1))
                            .clipShape(Capsule())
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                        }
                        .buttonStyle(.plain)
                        .help("Browse Music Studio Library")
                    }
                }

                Text(nowPlayingService.currentTrack?.artist ?? (nowPlayingService.activePlayerName ?? "System Audio"))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .lineLimit(1)
                    .truncationMode(.tail)

                if let album = nowPlayingService.currentTrack?.album, !album.isEmpty {
                    Text(album)
                        .font(.system(size: 10))
                        .foregroundColor(DesignSystem.Colors.textTertiary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .layoutPriority(0)

            // Transport Controls with large click targets
            HStack(spacing: 10) {
                Button(action: { nowPlayingService.previous() }) {
                    Image(systemName: "backward.fill")
                        .font(.system(size: 12))
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                        .frame(width: 28, height: 28)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)

                Button(action: { nowPlayingService.togglePlayPause() }) {
                    Image(systemName: nowPlayingService.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.white)
                        .frame(width: 34, height: 34)
                        .background(Color.accentColor)
                        .clipShape(Circle())
                        .shadow(color: Color.accentColor.opacity(0.4), radius: 4, x: 0, y: 2)
                }
                .buttonStyle(.plain)

                Button(action: { nowPlayingService.next() }) {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 12))
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                        .frame(width: 28, height: 28)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .layoutPriority(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .macNotchCardStyle()
    }

    // MARK: - Horizontal Bar View (Used in Overview row - guaranteed zero text/icon overlap)
    private var horizontalBarView: some View {
        HStack(spacing: 12) {
            // Left: Album Art (Click to open Music Studio)
            coverArtButton(size: 38, cornerRadius: 8)

            // Center: Track Title & Artist (with tail truncation and layoutPriority(0))
            VStack(alignment: .leading, spacing: 2) {
                Text(nowPlayingService.currentTrack?.title ?? "No Track Playing")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.tail)

                HStack(spacing: 4) {
                    Text(nowPlayingService.currentTrack?.artist ?? (nowPlayingService.activePlayerName ?? "System Audio"))
                        .font(.system(size: 10))
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                        .lineLimit(1)
                        .truncationMode(.tail)

                    if let album = nowPlayingService.currentTrack?.album, !album.isEmpty {
                        Text("•")
                            .font(.system(size: 8))
                            .foregroundColor(DesignSystem.Colors.textTertiary)
                        Text(album)
                            .font(.system(size: 10))
                            .foregroundColor(DesignSystem.Colors.textTertiary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .layoutPriority(0)

            // Right: Dedicated transport controls with fixed hit targets (layoutPriority(1))
            HStack(spacing: 8) {
                Button(action: { nowPlayingService.previous() }) {
                    Image(systemName: "backward.fill")
                        .font(.system(size: 12))
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Button(action: { nowPlayingService.togglePlayPause() }) {
                    Image(systemName: nowPlayingService.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 26))
                        .foregroundColor(.accentColor)
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Button(action: { nowPlayingService.next() }) {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 12))
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .layoutPriority(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .macNotchCardStyle()
    }

    // MARK: - Full Tab View (Expanded dedicated Music tab)
    private var fullTabView: some View {
        VStack(spacing: 16) {
            // Large Album Art (Click to open Music Studio)
            coverArtButton(size: 90, cornerRadius: 14)

            // Track details
            VStack(spacing: 4) {
                Text(nowPlayingService.currentTrack?.title ?? "No Track Playing")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Text(nowPlayingService.currentTrack?.artist ?? "Apple Music / Spotify / System")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .lineLimit(1)

                if let album = nowPlayingService.currentTrack?.album, !album.isEmpty {
                    Text(album)
                        .font(.system(size: 11))
                        .foregroundColor(DesignSystem.Colors.textTertiary)
                        .lineLimit(1)
                }
            }

            // Controls
            HStack(spacing: 32) {
                Button(action: { nowPlayingService.previous() }) {
                    Image(systemName: "backward.fill")
                        .font(.system(size: 18))
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                        .frame(width: 36, height: 36)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Button(action: { nowPlayingService.togglePlayPause() }) {
                    Image(systemName: nowPlayingService.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.accentColor)
                        .frame(width: 48, height: 48)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Button(action: { nowPlayingService.next() }) {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 18))
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                        .frame(width: 36, height: 36)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Interactive Cover Art Button
    @ViewBuilder
    private func coverArtButton(size: CGFloat, cornerRadius: CGFloat) -> some View {
        Button(action: {
            openActivePlayer()
        }) {
            ZStack {
                if let artwork = nowPlayingService.artwork {
                    Image(nsImage: artwork)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: size, height: size)
                        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                } else {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color.pink.opacity(0.85), Color.purple.opacity(0.85)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: size, height: size)

                    Image(systemName: nowPlayingService.isPlaying ? "waveform" : "music.note")
                        .font(.system(size: size * 0.4, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
            .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(0.18), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .pointingHandCursor()
        .help("Click cover artwork to open \(nowPlayingService.activePlayerName ?? "Music Player")")
    }

    /// Brings the active audio player (Music Studio, Spotify, Apple Music) to foreground.
    private func openActivePlayer() {
        nowPlayingService.openActivePlayer()
    }
}
