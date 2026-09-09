import SwiftUI

/// Sleek Dynamic Island HUD overlay displayed in the notch wings
/// for Volume adjustments, MagSafe/Battery charging events, and Caps Lock toggles.
public struct NotchHUDView: View {
    let hud: TransientHUD
    let cameraWidth: CGFloat
    let cameraHeight: CGFloat

    public init(hud: TransientHUD, cameraWidth: CGFloat = 200, cameraHeight: CGFloat = 34) {
        self.hud = hud
        self.cameraWidth = cameraWidth
        self.cameraHeight = cameraHeight
    }

    public var body: some View {
        HStack(spacing: 0) {
            // Left Wing: Icon & Status Indicator
            leftWingView
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.trailing, 8)

            // Center Notch Exclusion Area
            Color.clear
                .frame(width: max(cameraWidth, 160), height: cameraHeight)

            // Right Wing: Level Gauge / State Text
            rightWingView
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 8)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(Color.black.opacity(0.88))
                .overlay(
                    Capsule()
                        .stroke(hudBorderColor, lineWidth: 1)
                )
                .shadow(color: hudGlowColor, radius: 10, x: 0, y: 2)
        )
        .transition(.asymmetric(
            insertion: .scale(scale: 0.92, anchor: .top).combined(with: .opacity),
            removal: .scale(scale: 0.95, anchor: .top).combined(with: .opacity)
        ))
    }

    // MARK: - Left Wing (Icon)

    @ViewBuilder
    private var leftWingView: some View {
        switch hud {
        case .battery(let percentage, let isCharging, _):
            HStack(spacing: 5) {
                if isCharging {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(DesignSystem.Colors.emerald)
                } else if percentage <= 20 {
                    Image(systemName: "battery.25")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(percentage <= 10 ? .red : .orange)
                } else {
                    Image(systemName: "battery.100")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white.opacity(0.9))
                }
            }

        case .volume(let level, let isMuted):
            HStack(spacing: 4) {
                if isMuted || level <= 0.001 {
                    Image(systemName: "speaker.slash.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.red.opacity(0.9))
                } else if level > 0.6 {
                    Image(systemName: "speaker.wave.3.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                } else if level > 0.25 {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                } else {
                    Image(systemName: "speaker.wave.1.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                }
            }

        case .brightness:
            Image(systemName: "sun.max.fill")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.yellow)

        case .keyboardBrightness:
            Image(systemName: "keyboard.fill")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(Color.cyan)

        case .capsLock(let isOn):
            Image(systemName: "capslock.fill")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(isOn ? .orange : .white.opacity(0.6))

        case .accessory(_, let icon, _):
            Image(systemName: icon)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(DesignSystem.Colors.emerald)

        case .notification(_, _, let icon):
            Image(systemName: icon)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(Color.cyan)

        case .music:
            HStack(spacing: 5) {
                Image(systemName: "music.note")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(DesignSystem.Colors.emerald)

                WaveformVisualizerView(
                    isPlaying: true,
                    color: DesignSystem.Colors.emerald,
                    barCount: 4,
                    maxHeight: 10
                )
            }
        }
    }

    // MARK: - Right Wing (Gauge / Text)

    @ViewBuilder
    private var rightWingView: some View {
        switch hud {
        case .battery(let percentage, let isCharging, let timeRemaining):
            HStack(spacing: 6) {
                Text("\(percentage)%")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                if isCharging {
                    Text(timeRemaining ?? "Charging")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(DesignSystem.Colors.emerald)
                } else if percentage <= 20 {
                    Text(percentage <= 10 ? "Critical" : "Low Power")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(percentage <= 10 ? .red : .orange)
                } else {
                    Text("Battery")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                }
            }

        case .volume(let level, let isMuted):
            HStack(spacing: 6) {
                // Fluid volume level bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.2))
                        Capsule()
                            .fill(isMuted ? Color.red.opacity(0.8) : Color.white)
                            .frame(width: max(0, min(geo.size.width, geo.size.width * CGFloat(level))))
                    }
                }
                .frame(width: 54, height: 6)

                Text(isMuted ? "Mute" : "\(Int(level * 100))%")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(isMuted ? .red : .white)
                    .frame(width: 32, alignment: .leading)
            }

        case .brightness(let level):
            HStack(spacing: 6) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.2))
                        Capsule()
                            .fill(Color.yellow.opacity(0.9))
                            .frame(width: max(0, min(geo.size.width, geo.size.width * CGFloat(level))))
                    }
                }
                .frame(width: 54, height: 6)

                Text("\(Int(level * 100))%")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
            }

        case .keyboardBrightness(let level):
            HStack(spacing: 6) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.2))
                        Capsule()
                            .fill(Color.cyan.opacity(0.9))
                            .frame(width: max(0, min(geo.size.width, geo.size.width * CGFloat(level))))
                    }
                }
                .frame(width: 54, height: 6)

                Text("\(Int(level * 100))%")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
            }

        case .capsLock(let isOn):
            Text(isOn ? "CAPS LOCK ON" : "CAPS LOCK OFF")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundColor(isOn ? .orange : .white.opacity(0.6))

        case .accessory(let name, _, let battery):
            HStack(spacing: 4) {
                Text(name)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)

                if let bat = battery {
                    Text("\(bat)%")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(DesignSystem.Colors.emerald)
                }
            }

        case .notification(let title, let subtitle, _):
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                if let sub = subtitle {
                    Text(sub)
                        .font(.system(size: 9))
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                        .lineLimit(1)
                }
            }

        case .music(let title, let artist):
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .truncationMode(.tail)
                if let art = artist, !art.isEmpty {
                    Text(art)
                        .font(.system(size: 9))
                        .foregroundColor(DesignSystem.Colors.emerald.opacity(0.85))
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
        }
    }

    // MARK: - Dynamic Colors & Aura

    private var hudBorderColor: Color {
        switch hud {
        case .battery(_, let isCharging, _):
            return isCharging ? DesignSystem.Colors.emerald.opacity(0.6) : Color.white.opacity(0.2)
        case .capsLock(let isOn):
            return isOn ? Color.orange.opacity(0.6) : Color.white.opacity(0.2)
        case .volume(_, let isMuted):
            return isMuted ? Color.red.opacity(0.5) : Color.white.opacity(0.2)
        case .brightness:
            return Color.yellow.opacity(0.5)
        case .keyboardBrightness:
            return Color.cyan.opacity(0.5)
        case .accessory:
            return DesignSystem.Colors.emerald.opacity(0.6)
        case .notification:
            return Color.cyan.opacity(0.6)
        case .music:
            return DesignSystem.Colors.emerald.opacity(0.6)
        }
    }

    private var hudGlowColor: Color {
        switch hud {
        case .battery(_, let isCharging, _):
            return isCharging ? DesignSystem.Colors.emerald.opacity(0.35) : Color.black.opacity(0.4)
        case .capsLock(let isOn):
            return isOn ? Color.orange.opacity(0.35) : Color.black.opacity(0.4)
        case .volume(_, let isMuted):
            return isMuted ? Color.red.opacity(0.3) : Color.black.opacity(0.4)
        case .brightness:
            return Color.yellow.opacity(0.25)
        case .keyboardBrightness:
            return Color.cyan.opacity(0.25)
        case .accessory:
            return DesignSystem.Colors.emerald.opacity(0.35)
        case .notification:
            return Color.cyan.opacity(0.35)
        case .music:
            return DesignSystem.Colors.emerald.opacity(0.35)
        }
    }
}
