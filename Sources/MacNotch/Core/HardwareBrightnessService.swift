import Foundation
import CoreGraphics
import ObjectiveC
import AppKit

/// Service providing physical display brightness and keyboard backlight control on macOS
/// through Apple's native private frameworks (DisplayServices and CoreBrightness).
public final class HardwareBrightnessService: @unchecked Sendable {
    public static let shared = HardwareBrightnessService()

    // MARK: - Display Brightness (DisplayServices.framework)

    private typealias DisplayServicesGetBrightnessFunc = @convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Float>) -> Int32
    private typealias DisplayServicesSetBrightnessFunc = @convention(c) (CGDirectDisplayID, Float) -> Int32

    private var displayServicesHandle: UnsafeMutableRawPointer?
    private var displayServicesGetBrightness: DisplayServicesGetBrightnessFunc?
    private var displayServicesSetBrightness: DisplayServicesSetBrightnessFunc?

    // MARK: - Keyboard Brightness (CoreBrightness.framework)

    private typealias CopyIDsFunc = @convention(c) (AnyObject, Selector) -> AnyObject?
    private typealias GetBrightnessFunc = @convention(c) (AnyObject, Selector, UInt64) -> Float
    private typealias SetBrightnessFunc = @convention(c) (AnyObject, Selector, Float, UInt64) -> Bool

    private var keyboardClient: AnyObject?
    private var selCopyIDs: Selector?
    private var selGetBrightness: Selector?
    private var selSetBrightness: Selector?
    private var copyIDsImp: CopyIDsFunc?
    private var getBrightnessImp: GetBrightnessFunc?
    private var setBrightnessImp: SetBrightnessFunc?

    // Fallback cached state
    private var cachedDisplayBrightness: Float = 0.5
    private var cachedKeyboardBrightness: Float = 0.5
    private let lock = NSLock()

    private init() {
        setupDisplayServices()
        setupCoreBrightness()
    }

    deinit {
        if let handle = displayServicesHandle {
            dlclose(handle)
        }
    }

    // MARK: - Setup

    private func setupDisplayServices() {
        let path = "/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices"
        guard let handle = dlopen(path, RTLD_LAZY) else { return }
        self.displayServicesHandle = handle

        if let symGet = dlsym(handle, "DisplayServicesGetBrightness") {
            self.displayServicesGetBrightness = unsafeBitCast(symGet, to: DisplayServicesGetBrightnessFunc.self)
        }
        if let symSet = dlsym(handle, "DisplayServicesSetBrightness") {
            self.displayServicesSetBrightness = unsafeBitCast(symSet, to: DisplayServicesSetBrightnessFunc.self)
        }

        // Initialize cached brightness from hardware
        var initial: Float = 0.5
        if let getFunc = self.displayServicesGetBrightness,
           getFunc(CGMainDisplayID(), &initial) == 0 {
            self.cachedDisplayBrightness = max(0.0, min(1.0, initial))
        }
    }

    private func setupCoreBrightness() {
        let path = "/System/Library/PrivateFrameworks/CoreBrightness.framework"
        guard let bundle = Bundle(path: path), bundle.load() else { return }

        guard let clientClass = NSClassFromString("KeyboardBrightnessClient") as? NSObject.Type else {
            return
        }

        let client = clientClass.init()
        self.keyboardClient = client

        let selCopy = NSSelectorFromString("copyKeyboardBacklightIDs")
        let selGet = NSSelectorFromString("brightnessForKeyboard:")
        let selSet = NSSelectorFromString("setBrightness:forKeyboard:")

        self.selCopyIDs = selCopy
        self.selGetBrightness = selGet
        self.selSetBrightness = selSet

        if let methodCopy = class_getInstanceMethod(clientClass, selCopy) {
            self.copyIDsImp = unsafeBitCast(method_getImplementation(methodCopy), to: CopyIDsFunc.self)
        }
        if let methodGet = class_getInstanceMethod(clientClass, selGet) {
            self.getBrightnessImp = unsafeBitCast(method_getImplementation(methodGet), to: GetBrightnessFunc.self)
        }
        if let methodSet = class_getInstanceMethod(clientClass, selSet) {
            self.setBrightnessImp = unsafeBitCast(method_getImplementation(methodSet), to: SetBrightnessFunc.self)
        }

        // Initialize cached keyboard brightness
        if let client = self.keyboardClient,
           let copyImp = self.copyIDsImp,
           let getImp = self.getBrightnessImp {
            if let rawIDs = copyImp(client, selCopy) as? [NSNumber], let firstID = rawIDs.first?.uint64Value {
                let initial = getImp(client, selGet, firstID)
                if initial >= 0 {
                    self.cachedKeyboardBrightness = max(0.0, min(1.0, initial))
                }
            } else {
                let initial = getImp(client, selGet, 1)
                if initial >= 0 {
                    self.cachedKeyboardBrightness = max(0.0, min(1.0, initial))
                }
            }
        }
    }

    // MARK: - Display Brightness API

    /// Reads the physical brightness of the main display (0.0 to 1.0).
    public func getDisplayBrightness() -> Float {
        lock.lock()
        defer { lock.unlock() }

        if let getFunc = displayServicesGetBrightness {
            var val: Float = 0
            if getFunc(CGMainDisplayID(), &val) == 0 {
                let clamped = max(0.0, min(1.0, val))
                cachedDisplayBrightness = clamped
                return clamped
            }
        }
        return cachedDisplayBrightness
    }

    /// Physically adjusts the brightness of the screen display (0.0 to 1.0).
    public func setDisplayBrightness(_ level: Float) {
        lock.lock()
        defer { lock.unlock() }

        let clamped = max(0.0, min(1.0, level))
        cachedDisplayBrightness = clamped

        guard let setFunc = displayServicesSetBrightness else { return }

        // Set main display
        _ = setFunc(CGMainDisplayID(), clamped)

        // Set all active online displays
        var maxDisplays: UInt32 = 16
        var onlineDisplays = [CGDirectDisplayID](repeating: 0, count: Int(maxDisplays))
        var displayCount: UInt32 = 0
        if CGGetOnlineDisplayList(maxDisplays, &onlineDisplays, &displayCount) == .success && displayCount > 0 {
            for i in 0..<Int(displayCount) {
                let dID = onlineDisplays[i]
                if dID != CGMainDisplayID() {
                    _ = setFunc(dID, clamped)
                }
            }
        }
    }

    // MARK: - Keyboard Backlight API

    /// Reads the physical brightness of the built-in keyboard backlight (0.0 to 1.0).
    public func getKeyboardBrightness() -> Float {
        lock.lock()
        defer { lock.unlock() }

        guard let client = keyboardClient,
              let selCopy = selCopyIDs,
              let selGet = selGetBrightness,
              let copyImp = copyIDsImp,
              let getImp = getBrightnessImp else {
            return cachedKeyboardBrightness
        }

        if let rawIDs = copyImp(client, selCopy) as? [NSNumber], let firstID = rawIDs.first?.uint64Value {
            let val = getImp(client, selGet, firstID)
            if val >= 0 {
                let clamped = max(0.0, min(1.0, val))
                cachedKeyboardBrightness = clamped
                return clamped
            }
        } else {
            let val = getImp(client, selGet, 1)
            if val >= 0 {
                let clamped = max(0.0, min(1.0, val))
                cachedKeyboardBrightness = clamped
                return clamped
            }
        }

        return cachedKeyboardBrightness
    }

    /// Physically dims or brightens the keyboard backlight (0.0 to 1.0).
    public func setKeyboardBrightness(_ level: Float) {
        lock.lock()
        defer { lock.unlock() }

        let clamped = max(0.0, min(1.0, level))
        cachedKeyboardBrightness = clamped

        guard let client = keyboardClient,
              let selCopy = selCopyIDs,
              let selSet = selSetBrightness,
              let copyImp = copyIDsImp,
              let setImp = setBrightnessImp else {
            return
        }

        if let rawIDs = copyImp(client, selCopy) as? [NSNumber], !rawIDs.isEmpty {
            for num in rawIDs {
                let kbID = num.uint64Value
                _ = setImp(client, selSet, clamped, kbID)
            }
        } else {
            _ = setImp(client, selSet, clamped, 1)
        }
    }
}
