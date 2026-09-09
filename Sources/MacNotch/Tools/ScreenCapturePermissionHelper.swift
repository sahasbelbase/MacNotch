import AppKit
import CoreGraphics
import Foundation

/// Centralized manager for validating, requesting, and guiding screen recording (TCC) permissions.
@MainActor
public final class ScreenCapturePermissionHelper {
    public static let shared = ScreenCapturePermissionHelper()

    private init() {}

    /// Checks if MacNotch currently holds screen recording permission.
    public var hasPermission: Bool {
        CGPreflightScreenCaptureAccess()
    }

    /// Triggers macOS native permission prompt or registers application in Privacy & Security.
    @discardableResult
    public func requestPermission() -> Bool {
        CGRequestScreenCaptureAccess()
    }

    /// Opens System Settings directly to Privacy & Security -> Screen & System Audio Recording.
    public func openScreenRecordingSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") else { return }
        NSWorkspace.shared.open(url)
    }

    /// Restarts MacNotch so that newly granted screen recording permissions immediately take effect.
    public func restartApp() {
        let appURL = Bundle.main.bundleURL
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-n", appURL.path]
        try? process.run()
        NSApp.terminate(nil)
    }
}
