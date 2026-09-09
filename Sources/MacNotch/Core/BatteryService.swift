import Foundation
import IOKit.ps

/// Snapshot of the Mac's current power and battery state.
public struct BatterySnapshot: Equatable, Sendable {
    public let hasBattery: Bool
    public let percentage: Int
    public let isCharging: Bool
    public let isPluggedIn: Bool
    public let timeToFullMinutes: Int?
    public let timeToEmptyMinutes: Int?
    public let isLowPower: Bool

    public init(
        hasBattery: Bool = false,
        percentage: Int = 100,
        isCharging: Bool = false,
        isPluggedIn: Bool = false,
        timeToFullMinutes: Int? = nil,
        timeToEmptyMinutes: Int? = nil,
        isLowPower: Bool = false
    ) {
        self.hasBattery = hasBattery
        self.percentage = percentage
        self.isCharging = isCharging
        self.isPluggedIn = isPluggedIn
        self.timeToFullMinutes = timeToFullMinutes
        self.timeToEmptyMinutes = timeToEmptyMinutes
        self.isLowPower = isLowPower
    }
}

/// Service monitoring macOS battery status and power source changes via IOKit.
@MainActor
public final class BatteryService: ObservableObject {
    @Published public private(set) var snapshot: BatterySnapshot = BatterySnapshot()

    public var onPowerEvent: ((BatterySnapshot, Bool) -> Void)?

    private var runLoopSource: CFRunLoopSource?
    private var lastPluggedState: Bool?
    private var lastPercentage: Int?

    public init() {
        updateBatteryState(notifyOnChange: false)
        setupPowerNotification()
    }

    deinit {
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
    }

    private func setupPowerNotification() {
        let context = Unmanaged.passUnretained(self).toOpaque()
        let runLoopCallback: IOPowerSourceCallbackType = { context in
            guard let context = context else { return }
            let service = Unmanaged<BatteryService>.fromOpaque(context).takeUnretainedValue()
            Task { @MainActor in
                service.updateBatteryState(notifyOnChange: true)
            }
        }

        if let source = IOPSNotificationCreateRunLoopSource(runLoopCallback, context)?.takeRetainedValue() {
            self.runLoopSource = source
            CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        }
    }

    public func updateBatteryState(notifyOnChange: Bool = true) {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let list = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef],
              !list.isEmpty else {
            self.snapshot = BatterySnapshot(hasBattery: false)
            return
        }

        var foundBattery = false
        var currentPct = 100
        var isCharging = false
        var isPlugged = false
        var timeToFull: Int? = nil
        var timeToEmpty: Int? = nil

        for powerSource in list {
            guard let desc = IOPSGetPowerSourceDescription(info, powerSource)?.takeUnretainedValue() as? [String: Any] else {
                continue
            }

            // Verify device has an internal battery
            let type = desc[kIOPSTypeKey] as? String
            if type == kIOPSInternalBatteryType {
                foundBattery = true

                let curCap = desc[kIOPSCurrentCapacityKey] as? Int ?? 0
                let maxCap = desc[kIOPSMaxCapacityKey] as? Int ?? 100
                currentPct = maxCap > 0 ? Int((Double(curCap) / Double(maxCap)) * 100.0) : curCap

                isCharging = desc[kIOPSIsChargingKey] as? Bool ?? false
                let psState = desc[kIOPSPowerSourceStateKey] as? String
                isPlugged = (psState == kIOPSACPowerValue)

                if let ttf = desc[kIOPSTimeToFullChargeKey] as? Int, ttf > 0 {
                    timeToFull = ttf
                }
                if let tte = desc[kIOPSTimeToEmptyKey] as? Int, tte > 0 {
                    timeToEmpty = tte
                }
                break
            }
        }

        guard foundBattery else {
            self.snapshot = BatterySnapshot(hasBattery: false)
            return
        }

        let isLow = currentPct <= 20 && !isPlugged
        let newSnapshot = BatterySnapshot(
            hasBattery: true,
            percentage: currentPct,
            isCharging: isCharging,
            isPluggedIn: isPlugged,
            timeToFullMinutes: timeToFull,
            timeToEmptyMinutes: timeToEmpty,
            isLowPower: isLow
        )

        let wasPlugged = lastPluggedState
        let wasPct = lastPercentage

        self.snapshot = newSnapshot
        self.lastPluggedState = isPlugged
        self.lastPercentage = currentPct

        if notifyOnChange {
            // Did plug state change?
            let plugChanged = (wasPlugged != nil && wasPlugged != isPlugged)
            // Did cross low battery threshold (<=20% or <=10%)?
            let reachedLow = (currentPct <= 20 && (wasPct ?? 100) > 20 && !isPlugged)

            if plugChanged || reachedLow {
                onPowerEvent?(newSnapshot, plugChanged)
            }
        }
    }
}
