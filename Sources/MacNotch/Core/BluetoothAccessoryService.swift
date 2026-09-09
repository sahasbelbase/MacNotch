import Foundation
import CoreAudio
import AudioToolbox
import IOKit

/// Accessory connection event payload.
public struct AccessoryEvent: Equatable, Sendable {
    public let name: String
    public let icon: String
    public let batteryPercentage: Int?

    public init(name: String, icon: String, batteryPercentage: Int? = nil) {
        self.name = name
        self.icon = icon
        self.batteryPercentage = batteryPercentage
    }
}

/// Monitors audio device changes to detect Bluetooth headphones / AirPods connection events
/// and broadcast Dynamic Island accessory HUD cards.
@MainActor
public final class BluetoothAccessoryService: ObservableObject {
    @Published public private(set) var connectedAccessory: AccessoryEvent?

    public var onAccessoryConnected: ((AccessoryEvent) -> Void)?

    private var lastKnownDeviceID: AudioDeviceID = 0
    private nonisolated(unsafe) var listenerBlock: AudioObjectPropertyListenerBlock?

    public init() {
        startMonitoring()
    }

    deinit {
        stopMonitoring()
    }

    public func startMonitoring() {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        // Capture initial device ID
        var deviceID = AudioDeviceID()
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        if AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &deviceID) == noErr {
            lastKnownDeviceID = deviceID
        }

        let block: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            Task { @MainActor [weak self] in
                self?.handleDeviceChange()
            }
        }
        self.listenerBlock = block

        AudioObjectAddPropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            DispatchQueue.main,
            block
        )
    }

    public nonisolated func stopMonitoring() {
        guard let block = listenerBlock else { return }
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectRemovePropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            DispatchQueue.main,
            block
        )
        self.listenerBlock = nil
    }

    private func handleDeviceChange() {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var deviceID = AudioDeviceID()
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &deviceID) == noErr else {
            return
        }

        guard deviceID != lastKnownDeviceID else { return }
        lastKnownDeviceID = deviceID

        // Check if new device is Bluetooth
        var transportAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyTransportType,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var transportType: UInt32 = 0
        var transportSize = UInt32(MemoryLayout<UInt32>.size)
        guard AudioObjectGetPropertyData(deviceID, &transportAddress, 0, nil, &transportSize, &transportType) == noErr else {
            return
        }

        let isBluetooth = (transportType == kAudioDeviceTransportTypeBluetooth || transportType == kAudioDeviceTransportTypeBluetoothLE)
        guard isBluetooth else { return }

        // Fetch Device Name
        let deviceName = fetchDeviceName(for: deviceID) ?? "Bluetooth Audio"
        let icon = resolveAccessoryIcon(name: deviceName)
        let battery = fetchAccessoryBattery(name: deviceName)

        let event = AccessoryEvent(name: deviceName, icon: icon, batteryPercentage: battery)
        self.connectedAccessory = event
        self.onAccessoryConnected?(event)
    }

    private func fetchDeviceName(for deviceID: AudioDeviceID) -> String? {
        var nameAddress = AudioObjectPropertyAddress(
            mSelector: kAudioObjectPropertyName,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var cfName: CFString = "" as CFString
        var nameSize = UInt32(MemoryLayout<CFString>.size)
        let status = withUnsafeMutablePointer(to: &cfName) { ptr in
            AudioObjectGetPropertyData(deviceID, &nameAddress, 0, nil, &nameSize, ptr)
        }
        guard status == noErr else { return nil }
        return cfName as String
    }

    public func resolveAccessoryIcon(name: String) -> String {
        let lower = name.lowercased()
        if lower.contains("max") && lower.contains("airpod") {
            return "airpodsmax"
        } else if lower.contains("pro") && (lower.contains("airpod") || lower.contains("buds")) {
            return "airpodspro"
        } else if lower.contains("airpod") {
            return "airpods"
        } else if lower.contains("beat") {
            return "beats.headphones"
        } else if lower.contains("headphone") || lower.contains("sony") || lower.contains("bose") || lower.contains("wh-") || lower.contains("qc") {
            return "headphones"
        } else {
            return "speaker.wave.2.fill"
        }
    }

    private func fetchAccessoryBattery(name: String) -> Int? {
        var iterator: io_iterator_t = 0
        let matchingDict = IOServiceMatching("AppleBluetoothHIDDevice")
        guard IOServiceGetMatchingServices(kIOMainPortDefault, matchingDict, &iterator) == kIOReturnSuccess else {
            return nil
        }

        var matchedBattery: Int?
        var service = IOIteratorNext(iterator)
        while service != 0 {
            if let prodName = IORegistryEntryCreateCFProperty(service, "Product" as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? String,
               prodName.localizedCaseInsensitiveContains(name) || name.localizedCaseInsensitiveContains(prodName) {
                if let batteryVal = IORegistryEntryCreateCFProperty(service, "BatteryPercent" as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? Int {
                    matchedBattery = batteryVal
                    IOObjectRelease(service)
                    break
                }
            }
            IOObjectRelease(service)
            service = IOIteratorNext(iterator)
        }
        IOObjectRelease(iterator)
        return matchedBattery
    }
}
