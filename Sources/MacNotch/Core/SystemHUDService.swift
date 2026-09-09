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

    public var onVolumeChange: ((Float, Bool) -> Void)?
    public var onCapsLockChange: ((Bool) -> Void)?

    private var globalFlagsMonitor: Any?
    private var localFlagsMonitor: Any?
    private var defaultOutputDeviceID: AudioDeviceID = 0
    private var hasListener: Bool = false

    public init() {
        self.isCapsLockOn = NSEvent.modifierFlags.contains(.capsLock)
        setupCapsLockMonitoring()
        setupVolumeMonitoring()
    }

    deinit {
        if let global = globalFlagsMonitor {
            NSEvent.removeMonitor(global)
        }
        if let local = localFlagsMonitor {
            NSEvent.removeMonitor(local)
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
}
