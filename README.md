# MacNotch

> **A native, fluid, privacy-first macOS utility seamlessly integrated into the MacBook camera notch.**

![macOS](https://img.shields.io/badge/macOS-14.0%2B-black?style=flat&logo=apple)
![Swift](https://img.shields.io/badge/Swift-6.0-F05138?style=flat&logo=swift)
![SwiftUI](https://img.shields.io/badge/SwiftUI-Native-blue?style=flat)
![AppKit](https://img.shields.io/badge/AppKit-NSPanel-purple?style=flat)
![Architecture](https://img.shields.io/badge/Architecture-Universal%20(arm64%20%2B%20x86__64)-darkgreen?style=flat)
![Tests](https://img.shields.io/badge/Tests-90%20passing-brightgreen?style=flat)
![License](https://img.shields.io/badge/License-MIT-orange?style=flat)

**MacNotch** transforms the physical camera housing of modern MacBook laptops into an intelligent, interactive workspace. Completely invisible during normal workflows, it expands smoothly into a dual-ear command center when you move your cursor to the notch—giving you immediate access to your music, clipboard history, file shelf, quick notes, focus timer, system power tools, and live weather.

---

## 📦 Download & Installation

Ready-to-use release disk images are available directly in this repository:
- **Root Download**: [`./MacNotch.dmg`](MacNotch.dmg)
- **Releases Folder**: [`./releases/MacNotch.dmg`](releases/MacNotch.dmg)

### Quick Start:
1. Double-click `MacNotch.dmg` to mount the disk image.
2. Drag `MacNotch.app` into your **Applications** folder.
3. Launch `MacNotch` from Applications or Spotlight.
4. Move your mouse to the top center of your screen (over the camera notch) to activate.

> **Note on Permissions**: For Screenshot Studio and Screen Text OCR, grant Screen Recording permission in **System Settings → Privacy & Security → Screen Recording**. MacNotch uses stable bundle-identifier code signing (`-r='designated => identifier "com.sahasbelbase.MacNotch"'`) to ensure permissions persist across launches and updates.

---

## ✨ Features & Highlights

### 🎵 Music Studio & Universal Audio Controller
- **Smart Fallback Chain**: Automatically detects active playback across **Music Studio**, **Spotify**, **Apple Music**, **YouTube Music**, and system **MediaRemote** (browsers, podcasts, video players).
- **In-Place Pause & Resume**: Pausing and resuming from the notch cleanly preserves your exact track position and metadata without restarting from the beginning.
- **2-Second Notch Glimpse**: When a track starts or advances, a subtle, non-intrusive animated music pill appears on the right wing of the collapsed notch for 2 seconds and automatically dismisses.
- **Built-in Music Studio**:
  - Library browser with 170+ tracks and album cover artwork.
  - Live online streaming search across millions of tracks with instant preview playback.
  - Keyboard shortcuts (`Space` to toggle, `Right/Left Arrows` for track navigation, `Shuffle`).
  - Search filter supporting keyword commands like `play`, `pause`, `next`, `forward`, `prev`.

### 📋 Rich Visual Clipboard History
- Real-time pasteboard observation via `NSPasteboard.general` change counting.
- Heuristic classification: Plain text, URLs (with domain badges), Code snippets (monospace syntax box), Images (thumbnail previews), and File paths.
- Consecutive duplicate detection and sensitive credential filtering (API keys, tokens, 1Password / Bitwarden / Keychain transient entries).
- One-click copy with visual confirmation and haptic feedback.

### 📁 File Shelf & AirDrop Staging Zone
- **Drag-to-Notch Staging**: Drag files directly from Finder, Desktop, or Safari and drop them into the notch.
- **AirDrop with One Click**: Send staged files immediately to nearby devices without opening extra Finder windows.
- Quick Look preview, file opening, and selective removal.

### ✍️ Jotter Scratchpad & Quick To-Dos
- Instant floating scratchpad for thoughts, meeting notes, code snippets, and to-do checklists.
- Interactive checkboxes with completed-item strike-through styling.
- Local persistence so notes survive app relaunches.

### ⏱️ Focus Timer & Calendar Event Hub
- **Focus / Pomodoro Timer**: Preset durations (15m, 25m, 45m, 60m) with customized chime upon completion.
- **Live Collapsed Pill**: While a timer is active, an orange countdown pill stays visible in the collapsed notch so you can track time at a glance.
- **Today's Calendar**: Syncs with EventKit to display your upcoming schedule and meetings.

### 🛠️ Power Tools Suite
- **Screenshot Studio**: Capture full screen, selected window, or custom rectangle directly to clipboard and disk in high-DPI quality.
- **Screen Text OCR**: Marquee-select any region of your screen to extract text into your clipboard using Apple Vision.
- **QR Code Generator**: On-the-fly QR code generator for URLs or text snippets (clean, empty-by-default design).
- **Screen Recorder & Camera Mirror**: Quick shortcuts for macOS recording and low-latency camera HUD preview.

### ☀️ Weather Engine
- Real-time meteorological forecast with current temperature, condition icon, feels-like, and daily highs/lows.
- Interactive city search supporting global locations (Kathmandu, London, Tokyo, New York, etc.).
- Instant **°C / °F** unit toggle with immediate UI refresh and preference persistence.

### 🔆 Hardware Dynamic Controls
- Integrated screen brightness slider and audio volume control.
- **Keyboard Backlight Brightness Control**: Direct hardware adjustment via native Apple DisplayServices / IOKit APIs.

### 📐 Adaptive Dual-Ear Notch Geometry
- Derived strictly from `NSScreen.safeAreaInsets` and hardware screen geometry—zero hardcoded device models.
- Balanced dual-ear layout preventing letter wrapping and UI clutter.
- Responsive width (clamped to sleek 740pt max) and comfortable height (370–400pt) with safety mouse-tracking margins to avoid accidental collapse while clicking buttons.

---

## ⌨️ Keyboard Shortcuts

| Shortcut | Action |
|---|---|
| `Cmd + 1` | Switch to **Overview** tab (Music Hero, Library & Clips) |
| `Cmd + 2` | Switch to **Clipboard** history |
| `Cmd + 3` | Switch to **File Shelf** & AirDrop |
| `Cmd + 4` | Switch to **Jotter** scratchpad & to-dos |
| `Cmd + 5` | Switch to **Calendar** & Focus Timer |
| `Cmd + 6` | Switch to **Weather** forecast |
| `Space` | Play / Pause active track (when Music tab is focused) |
| `Right Arrow` | Skip to next track |
| `Left Arrow` | Rewind to previous track |

---

## 🏗️ Architecture Overview

```text
MacNotch/
├── MacNotch.dmg                     # Release disk image installer
├── MacNotch.xcodeproj/              # Xcode project for production app bundle
├── Package.swift                    # SwiftPM configuration for testing and CI
├── scripts/
│   └── build_dmg.sh                 # Release build, signing & packaging script
├── Sources/
│   └── MacNotch/
│       ├── App/
│       │   ├── AppDelegate.swift    # App lifecycle, NSApp.setActivationPolicy(.accessory)
│       │   └── MacNotchApp.swift    # @main SwiftUI entry point
│       ├── Calendar/
│       │   └── CalendarSyncService.swift # EventKit calendar integration
│       ├── Clipboard/
│       │   ├── ClipboardCardView.swift  # Carousel card presentation
│       │   ├── ClipboardItem.swift  # Model for text, code, URLs, images, files
│       │   ├── ClipboardManager.swift # System pasteboard listener & filter
│       │   ├── ClipboardStore.swift # Local atomic persistence
│       │   └── ClipboardView.swift  # Horizontal scrollable carousel
│       ├── Core/
│       │   ├── AppState.swift       # Finite state machine (hidden, collapsed, activating, expanded)
│       │   ├── MouseTracker.swift   # Cursor hover tracking with debouncing & hysteresis
│       │   ├── NotchDetector.swift  # Hardware notch geometry calculator
│       │   ├── NotchGeometry.swift  # Coordinate math in global screen coordinates
│       │   ├── ScreenManager.swift  # Multi-display observation & resolution adaptation
│       │   └── WindowManager.swift  # AppKit NSPanel lifecycle and positioning
│       ├── Jotter/
│       │   ├── JotterManager.swift  # Notes and to-do item management & storage
│       │   └── JotterView.swift     # Note-taking and checklist view
│       ├── MenuBar/
│       │   └── MenuBarManager.swift # Native NSStatusItem & menu hierarchy
│       ├── Music/
│       │   ├── MediaRemoteNowPlayingProvider.swift # System-wide media observer
│       │   ├── MusicStudioListView.swift # Music Studio tracks & streaming list
│       │   ├── MusicStudioNowPlayingProvider.swift # Music Studio playback engine
│       │   ├── MusicView.swift      # Now playing cards & playback controls
│       │   ├── NowPlayingService.swift # Abstract audio provider protocol
│       │   ├── SystemNowPlayingService.swift # Multi-player smart coordinator
│       │   ├── Track.swift          # Metadata model
│       │   └── WaveformVisualizerView.swift # Live animated waveform
│       ├── Notch/
│       │   ├── CollapsedNotchView.swift # Minimal notch footprint & active timer pill
│       │   ├── ExpandedNotchView.swift  # Dual-ear tabbed command center
│       │   ├── NotchHUDView.swift   # Music glimpse and transient system HUDs
│       │   ├── NotchPanel.swift     # Non-activating floating NSPanel
│       │   ├── NotchShape.swift     # Continuous-corner curve matching MacBook notch
│       │   └── NotchView.swift      # Root view with fluid spring animations
│       ├── Settings/
│       │   ├── SettingsStore.swift  # Preferences storage & location persistence
│       │   └── SettingsView.swift   # Multi-tab native macOS preferences
│       ├── Shared/
│       │   ├── AirDropService.swift # NSSharingService AirDrop integration
│       │   ├── DesignSystem.swift   # Colors, dimensions, typography & spring curves
│       │   └── Extensions.swift     # AppKit and SwiftUI utility helpers
│       ├── Shelf/
│       │   ├── FileShelfManager.swift # Staged file storage & AirDrop handler
│       │   └── FileShelfView.swift  # Shelf view with drag-and-drop
│       ├── Time/
│       │   ├── TimeService.swift    # Minute-boundary timer
│       │   ├── TimerService.swift   # Focus / Pomodoro countdown engine
│       │   ├── TimerWidgetView.swift # Focus timer UI controls
│       │   └── TimeView.swift       # Digital clock presentation
│       ├── Tools/
│       │   ├── ColorSamplerService.swift # Eyedropper color picker
│       │   ├── PowerToolsView.swift # Power tools interface (Screenshot, OCR, QR, Mirror)
│       │   ├── QRCodeService.swift  # CIFilter-based QR code generator
│       │   ├── ScreenCapturePermissionHelper.swift # TCC screen recording check & deep link
│       │   └── ScreenOCRService.swift # Apple Vision text recognition
│       └── Weather/
│           ├── HardwareBrightnessService.swift # Screen & Keyboard backlight hardware control
│           ├── WeatherModel.swift   # Forecast conditions, cities & units
│           ├── WeatherService.swift # Open-Meteo REST client with caching
│           └── WeatherView.swift    # Current conditions and city search
├── SupportingFiles/
│   ├── AppIcon.icns                 # High-resolution universal Retina icon
│   ├── Info.plist                   # LSUIElement=YES, Privacy descriptions
│   └── MacNotch.entitlements        # Sandboxing, Apple Events & Network access
└── Tests/
    └── MacNotchTests/
        ├── AppStateTests.swift      # State machine transition & debounce tests
        ├── ClipboardManagerTests.swift # Classification, deduplication & retention tests
        ├── HardwareDynamicsTests.swift # Brightness & HUD transient tests
        ├── NotchDetectorTests.swift # Hardware display geometry tests
        ├── NotchGeometryTests.swift # Screen geometry computation tests
        ├── NowPlayingProviderTests.swift # Playback controls & pause/resume tests
        ├── ProductivityShelfTests.swift # Shelf & Jotter mutation tests
        └── SettingsStoreTests.swift # Preferences persistence tests
```

---

## 🛠️ Building from Source

### Prerequisites
- macOS 14.0 (Sonoma) or macOS 15.0+ (Sequoia)
- Xcode 15.0+ or Command Line Tools with Swift 6.0

### Build Release DMG Installer
```bash
./scripts/build_dmg.sh
```
This script compiles the universal binary (`arm64` and `x86_64`), codesigns the bundle with the designated requirement, copies all assets, and creates a compressed `MacNotch.dmg`.

### Run Unit Tests
```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
```
All **90 unit tests** validate hardware geometry, clipboard filtering, audio providers, HUD dismissal, and settings persistence.

---

## 🔒 Privacy & Local-First Manifesto

MacNotch was built strictly local-first with zero interest in tracking you:
- **Zero Telemetry**: No analytics, trackers, logging SDKs, or external monitoring services.
- **100% Local Storage**: Clipboard history, notes, and file shelf items remain on your machine in `~/Library/Application Support/MacNotch/`.
- **Sensitive Data Shield**: Passwords copied from password managers (1Password, Bitwarden, Keychain), API tokens (`sk-...`, `ghp_...`), and SSH keys are heuristically filtered and never written to history.
- **Transparent Open Source**: Every line of code is inspectable in this repository.

---

## 📄 License

MIT License. Designed and developed with care by [Sahas Belbase](https://github.com/sahasbelbase).
