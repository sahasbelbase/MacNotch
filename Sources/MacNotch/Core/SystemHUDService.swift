import AppKit
import AudioToolbox
import CoreAudio
import Foundation

/// Service that monitors system-wide volume and keyboard state (Caps Lock)
/// to drive non-intrusive, fluid Notch HUD wings.
@MainActor
public final class SystemHUDService: ObservableObject {
    @Published public private(set) var currentVolume: Float = 0.5
    @Published public private(set) var isMuted: Bool = false
    @Published public private(set) var isCapsLockOn: Bool = false
    @Published public private(set) var keyboardBrightness: Float = 0.5
    @Published public private(set) var screenBrightness: Float = 0.7

    public var onVolumeChange: ((Float, Bool) -> Void)?
    public var onCapsLockChange: ((Bool) -> Void)?
    public var onKeyboardBrightnessChange: ((Float) -> Void)?
    public var onScreenBrightnessChange: ((Float) -> Void)?

    private var globalFlagsMonitor: Any?
    private var localFlagsMonitor: Any?
    private var systemEventsMonitor: Any?
    private var defaultOutputDeviceID: AudioDeviceID = 0
    private var hasListener: Bool = false

    public init() {
        self.isCapsLockOn = NSEvent.modifierFlags.contains(.capsLock)
        self.screenBrightness = HardwareBrightnessService.shared.getDisplayBrightness()
        self.keyboardBrightness = HardwareBrightnessService.shared.getKeyboardBrightness()
        setupCapsLockMonitoring()
        setupVolumeMonitoring()
        setupMediaKeyMonitoring()
    }

    deinit {
        if let global = globalFlagsMonitor {
            NSEvent.removeMonitor(global)
        }
        if let local = localFlagsMonitor {
            NSEvent.removeMonitor(local)
        }
        if let sys = systemEventsMonitor {
            NSEvent.removeMonitor(sys)
        }
    }

    // MARK: - Caps Lock Monitoring

    private func setupCapsLockMonitoring() {
        globalFlagsMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            MainActor.assumeIsolated {
                self?.handleFlagsChanged(event)
            }
        }

        localFlagsMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            MainActor.assumeIsolated {
                self?.handleFlagsChanged(event)
            }
            return event
        }
    }

    private func handleFlagsChanged(_ event: NSEvent) {
        let isCaps = event.modifierFlags.contains(.capsLock)
        if isCaps != self.isCapsLockOn {
            self.isCapsLockOn = isCaps
            onCapsLockChange?(isCaps)
        }
    }

    // MARK: - CoreAudio Volume Monitoring

    private func setupVolumeMonitoring() {
        updateDefaultOutputDevice()
    }

    private func updateDefaultOutputDevice() {
        removeVolumeListener()

        var defaultDeviceID = AudioDeviceID(0)
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var dataSize = UInt32(MemoryLayout<AudioDeviceID>.size)

        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &dataSize,
            &defaultDeviceID
        )

        guard status == noErr, defaultDeviceID != 0 else { return }
        self.defaultOutputDeviceID = defaultDeviceID

        // Query current volume
        queryVolume(for: defaultDeviceID)

        // Attach listener for volume changes
        var volumeAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
            mScope: kAudioObjectPropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )

        let listener: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            Task { @MainActor in
                self?.handleVolumeChanged()
            }
        }

        let listenerStatus = AudioObjectAddPropertyListenerBlock(
            defaultDeviceID,
            &volumeAddress,
            DispatchQueue.main,
            listener
        )

        if listenerStatus == noErr {
            hasListener = true
        }
    }

    private func removeVolumeListener() {
        hasListener = false
    }

    private func queryVolume(for deviceID: AudioDeviceID) {
        var volumeAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
            mScope: kAudioObjectPropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        var volume: Float32 = 0.5
        var size = UInt32(MemoryLayout<Float32>.size)

        let status = AudioObjectGetPropertyData(
            deviceID,
            &volumeAddress,
            0,
            nil,
            &size,
            &volume
        )

        if status == noErr {
            self.currentVolume = volume
        }

        // Query mute state
        var muteAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioObjectPropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        var isMute: UInt32 = 0
        var muteSize = UInt32(MemoryLayout<UInt32>.size)

        if AudioObjectGetPropertyData(deviceID, &muteAddress, 0, nil, &muteSize, &isMute) == noErr {
            self.isMuted = (isMute != 0)
        }
    }

    private func handleVolumeChanged() {
        guard defaultOutputDeviceID != 0 else { return }
        let oldVolume = self.currentVolume
        let oldMuted = self.isMuted

        queryVolume(for: defaultOutputDeviceID)

        if abs(self.currentVolume - oldVolume) > 0.005 || self.isMuted != oldMuted {
            onVolumeChange?(self.currentVolume, self.isMuted)
        }
    }

    // MARK: - Display & Keyboard Backlight Monitoring

    private func setupMediaKeyMonitoring() {
        systemEventsMonitor = NSEvent.addGlobalMonitorForEvents(matching: .systemDefined) { [weak self] event in
            guard event.subtype.rawValue == 8 else { return }
            let data = event.data1
            let keyCode = Int((data & 0xFFFF0000) >> 16)
            let keyFlags = (data & 0x0000FFFF)
            let keyState = (((keyFlags & 0xFF00) >> 8)) == 0xA // Key down
            guard keyState else { return }

            MainActor.assumeIsolated {
                switch keyCode {
                case 21: // NX_KEYTYPE_ILLUMINATION_UP
                    self?.adjustKeyboardBrightness(delta: 0.0625)
                case 22: // NX_KEYTYPE_ILLUMINATION_DOWN
                    self?.adjustKeyboardBrightness(delta: -0.0625)
                case 23: // NX_KEYTYPE_ILLUMINATION_TOGGLE
                    self?.toggleKeyboardBrightness()
                case 2:  // NX_KEYTYPE_BRIGHTNESS_UP
                    self?.adjustScreenBrightness(delta: 0.0625)
                case 3:  // NX_KEYTYPE_BRIGHTNESS_DOWN
                    self?.adjustScreenBrightness(delta: -0.0625)
                default:
                    break
                }
            }
        }
    }

    public func setKeyboardBrightness(_ level: Float) {
        let clamped = max(0.0, min(1.0, level))
        self.keyboardBrightness = clamped
        HardwareBrightnessService.shared.setKeyboardBrightness(clamped)
        onKeyboardBrightnessChange?(clamped)
    }

    public func adjustKeyboardBrightness(delta: Float) {
        setKeyboardBrightness(self.keyboardBrightness + delta)
    }

    public func toggleKeyboardBrightness() {
        if self.keyboardBrightness > 0.05 {
            setKeyboardBrightness(0.0)
        } else {
            setKeyboardBrightness(0.75)
        }
    }

    public func setScreenBrightness(_ level: Float) {
        let clamped = max(0.0, min(1.0, level))
        self.screenBrightness = clamped
        HardwareBrightnessService.shared.setDisplayBrightness(clamped)
        onScreenBrightnessChange?(clamped)
    }

    public func adjustScreenBrightness(delta: Float) {
        setScreenBrightness(self.screenBrightness + delta)
    }
}
