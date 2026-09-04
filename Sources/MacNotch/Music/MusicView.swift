import SwiftUI

/// Displays now playing information and playback controls for Apple Music, Spotify, or any system media player.
public struct MusicView: View {
    @ObservedObject var nowPlayingService: SystemNowPlayingService
    public var isCompact: Bool = false
    public var isFullTab: Bool = false

    public init(nowPlayingService: SystemNowPlayingService, isCompact: Bool = false, isFullTab: Bool = false) {
        self.nowPlayingService = nowPlayingService
        self.isCompact = isCompact
        self.isFullTab = isFullTab
    }

    public var body: some View {
        if isCompact {
            compactView
        } else if isFullTab {
            fullTabView
        } else {
            horizontalBarView
        }
    }

    // MARK: - Compact View (Header status pill)
    private var compactView: some View {
        HStack(spacing: 5) {
            Image(systemName: nowPlayingService.isPlaying ? "waveform" : "music.note")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.pink)

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

    // MARK: - Horizontal Bar View (Used in Overview row - guaranteed zero text/icon overlap)
    private var horizontalBarView: some View {
        HStack(spacing: 12) {
            // Left: Album Art or Music Gradient Icon
            if let artwork = nowPlayingService.artwork {
                Image(nsImage: artwork)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 38, height: 38)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .shadow(color: .black.opacity(0.2), radius: 3, x: 0, y: 1)
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color.pink.opacity(0.8), Color.purple.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    Image(systemName: "music.note")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                }
                .frame(width: 38, height: 38)
                .shadow(color: .black.opacity(0.15), radius: 2, x: 0, y: 1)
            }

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
            // Large Album Art
            if let artwork = nowPlayingService.artwork {
                Image(nsImage: artwork)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 90, height: 90)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color.pink.opacity(0.8), Color.purple.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    Image(systemName: "music.note")
                        .font(.system(size: 36, weight: .semibold))
                        .foregroundColor(.white)
                }
                .frame(width: 90, height: 90)
                .shadow(color: .black.opacity(0.2), radius: 6, x: 0, y: 3)
            }

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
}
