import SwiftUI
import AppKit

/// Quick-access developer & power user utility suite.
public struct PowerToolsView: View {
    @ObservedObject var appState: AppState
    @ObservedObject var clipboardManager: ClipboardManager

    @State private var qrInputText: String = ""
    @State private var qrImage: NSImage?
    @State private var activeToolTab: PowerToolTab = .colorSampler
    @State private var isProcessing: Bool = false

    public enum PowerToolTab: String, CaseIterable {
        case colorSampler = "Color Dropper"
        case screenOCR = "Screen OCR"
        case qrGenerator = "QR Generator"

        var icon: String {
            switch self {
            case .colorSampler: return "eyedropper.halffull"
            case .screenOCR: return "text.viewfinder"
            case .qrGenerator: return "qrcode"
            }
        }
    }

    public init(appState: AppState, clipboardManager: ClipboardManager) {
        self.appState = appState
        self.clipboardManager = clipboardManager
    }

    public var body: some View {
        VStack(spacing: 10) {
            // Segmented Tool Switcher
            HStack(spacing: 6) {
                ForEach(PowerToolTab.allCases, id: \.self) { tab in
                    Button(action: { activeToolTab = tab }) {
                        HStack(spacing: 4) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 10, weight: .semibold))
                            Text(tab.rawValue)
                                .font(.system(size: 11, weight: .medium))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule().fill(activeToolTab == tab ? Color.accentColor.opacity(0.25) : Color.white.opacity(0.06))
                        )
                        .foregroundColor(activeToolTab == tab ? .accentColor : DesignSystem.Colors.textSecondary)
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }

            Divider()
                .background(DesignSystem.Colors.subtleBorder)

            // Content per tool
            switch activeToolTab {
            case .colorSampler:
                colorSamplerCard
            case .screenOCR:
                screenOCRCard
            case .qrGenerator:
                qrGeneratorCard
            }
        }
        .padding(10)
        .macNotchCardStyle()
        .onAppear {
            if let firstClip = clipboardManager.items.first?.textContent ?? clipboardManager.items.first?.preview, !firstClip.isEmpty {
                qrInputText = firstClip
                qrImage = QRCodeService.shared.generateQRCode(from: firstClip, size: 120)
            }
        }
    }

    // MARK: - Color Sampler Card

    private var colorSamplerCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "eyedropper.halffull")
                .font(.system(size: 26))
                .foregroundColor(.accentColor)
                .frame(width: 44, height: 44)
                .background(Color.accentColor.opacity(0.12))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text("Pixel Color Eyedropper")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                Text("Magnify and pick any pixel color from your screen. Automatically copies Hex code.")
                    .font(.system(size: 10))
                    .foregroundColor(DesignSystem.Colors.textTertiary)
                    .lineLimit(2)
            }

            Spacer()

            Button(action: triggerColorSampler) {
                HStack(spacing: 4) {
                    Image(systemName: "pipette")
                    Text("Pick Color")
                }
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.accentColor)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(8)
        .background(Color.white.opacity(0.03))
        .cornerRadius(8)
    }

    private func triggerColorSampler() {
        ColorSamplerService.shared.sampleColor { hex, color in
            appState.showHUD(
                .notification(title: "Color Copied", subtitle: "\(hex) saved to clipboard", icon: "eyedropper.halffull"),
                duration: 2.5
            )
        }
    }

    // MARK: - Screen OCR Card

    private var screenOCRCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "text.viewfinder")
                .font(.system(size: 24))
                .foregroundColor(.cyan)
                .frame(width: 44, height: 44)
                .background(Color.cyan.opacity(0.12))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text("Screen Text OCR")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                Text("Select any area of your screen with crosshairs to extract and copy text immediately.")
                    .font(.system(size: 10))
                    .foregroundColor(DesignSystem.Colors.textTertiary)
                    .lineLimit(2)
            }

            Spacer()

            Button(action: triggerOCR) {
                HStack(spacing: 4) {
                    if isProcessing {
                        ProgressView()
                            .scaleEffect(0.6)
                            .frame(width: 12, height: 12)
                    } else {
                        Image(systemName: "viewfinder")
                    }
                    Text("Capture Area")
                }
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.black)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.cyan)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .disabled(isProcessing)
        }
        .padding(8)
        .background(Color.white.opacity(0.03))
        .cornerRadius(8)
    }

    private func triggerOCR() {
        isProcessing = true
        ScreenOCRService.shared.captureAndRecognize { recognized in
            isProcessing = false
            if let text = recognized, !text.isEmpty {
                let preview = text.prefix(28) + (text.count > 28 ? "..." : "")
                appState.showHUD(
                    .notification(title: "Text Copied!", subtitle: String(preview), icon: "text.viewfinder"),
                    duration: 3.0
                )
            }
        }
    }

    // MARK: - QR Generator Card

    private var qrGeneratorCard: some View {
        HStack(spacing: 14) {
            // QR Code Preview
            if let img = qrImage {
                Image(nsImage: img)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 72, height: 72)
                    .background(Color.white)
                    .cornerRadius(6)
                    .shadow(radius: 2)
            } else {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.white.opacity(0.06))
                    .frame(width: 72, height: 72)
                    .overlay(
                        Image(systemName: "qrcode")
                            .font(.system(size: 28))
                            .foregroundColor(DesignSystem.Colors.textTertiary)
                    )
            }

            VStack(alignment: .leading, spacing: 6) {
                TextField("Enter text or URL to generate QR code...", text: $qrInputText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11))
                    .padding(6)
                    .background(Color.white.opacity(0.07))
                    .cornerRadius(6)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                    .onChange(of: qrInputText) { newVal in
                        if !newVal.isEmpty {
                            qrImage = QRCodeService.shared.generateQRCode(from: newVal, size: 140)
                        } else {
                            qrImage = nil
                        }
                    }

                HStack(spacing: 8) {
                    Button(action: {
                        if !qrInputText.isEmpty {
                            _ = QRCodeService.shared.copyQRCodeToClipboard(from: qrInputText)
                            appState.showHUD(
                                .notification(title: "QR Code Copied", subtitle: "Image saved to clipboard", icon: "qrcode"),
                                duration: 2.5
                            )
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "doc.on.doc")
                            Text("Copy Image")
                        }
                        .font(.system(size: 10, weight: .semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.08))
                        .cornerRadius(6)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                    }
                    .buttonStyle(.plain)
                    .disabled(qrImage == nil)

                    Button(action: {
                        if let firstClip = clipboardManager.items.first?.textContent ?? clipboardManager.items.first?.preview, !firstClip.isEmpty {
                            qrInputText = firstClip
                            qrImage = QRCodeService.shared.generateQRCode(from: firstClip, size: 140)
                        }
                    }) {
                        Text("Paste Clipboard")
                            .font(.system(size: 10))
                            .foregroundColor(.accentColor)
                    }
                    .buttonStyle(.plain)

                    Spacer()
                }
            }
        }
        .padding(8)
        .background(Color.white.opacity(0.03))
        .cornerRadius(8)
    }
}
