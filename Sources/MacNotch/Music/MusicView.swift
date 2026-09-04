import SwiftUI

/// Displays now playing information and playback controls for Apple Music or Spotify.
public struct MusicView: View {
    @ObservedObject var nowPlayingService: SystemNowPlayingService
    public var isCompact: Bool = false

    public init(nowPlayingService: SystemNowPlayingService, isCompact: Bool = false) {
        self.nowPlayingService = nowPlayingService
        self.isCompact = isCompact
    }

    public var body: some View {
        if isCompact {
            compactView
        } else {
            expandedView
        }
    }

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
                    .frame(maxWidth: 140)
            } else {
                Text("Not Playing")
                    .font(.system(size: 11))
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }
        }
    }

    private var expandedView: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                // Album Art / Placeholder
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color.pink.opacity(0.8), Color.purple.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    Image(systemName: "music.note")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                }
                .frame(width: 52, height: 52)
                .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)

                // Track Metadata
                VStack(alignment: .leading, spacing: 3) {
                    Text(nowPlayingService.currentTrack?.title ?? "No Track Playing")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                        .lineLimit(1)

                    Text(nowPlayingService.currentTrack?.artist ?? "Apple Music / Spotify")
                        .font(.system(size: 11))
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                        .lineLimit(1)

                    if let album = nowPlayingService.currentTrack?.album, !album.isEmpty {
                        Text(album)
                            .font(.system(size: 10))
                            .foregroundColor(DesignSystem.Colors.textTertiary)
                            .lineLimit(1)
                    }
                }

                Spacer()
            }

            // Controls
            HStack(spacing: 24) {
                Button(action: {
                    nowPlayingService.previous()
                }) {
                    Image(systemName: "backward.fill")
                        .font(.system(size: 14))
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                }
                .buttonStyle(.plain)

                Button(action: {
                    nowPlayingService.togglePlayPause()
                }) {
                    Image(systemName: nowPlayingService.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.accentColor)
                }
                .buttonStyle(.plain)

                Button(action: {
                    nowPlayingService.next()
                }) {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 14))
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 4)
        }
        .padding(10)
        .macNotchCardStyle()
    }
}
