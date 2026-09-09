import AppKit
import Foundation

/// System-wide Now Playing provider leveraging macOS MediaRemote infrastructure.
///
/// Automatically captures playback state, metadata, and artwork from:
/// - Apple Music
/// - Spotify
/// - Custom music players implementing MPNowPlayingInfoCenter / MPRemoteCommandCenter
/// - Web browsers (YouTube, SoundCloud in Safari/Chrome)
/// - Podcasts and third-party media players
@MainActor
public final class MediaRemoteNowPlayingProvider: NowPlayingProvider {
    public private(set) var isPlaying: Bool = false
    public private(set) var currentTrack: Track?
    public private(set) var artwork: NSImage?
    public let providerName: String = "System (MediaRemote)"

    public var onUpdate: (() -> Void)?

    private typealias MRMediaRemoteRegisterForNotificationsFn = @convention(c) (DispatchQueue) -> Void
    private typealias MRMediaRemoteGetNowPlayingInfoFn = @convention(c) (DispatchQueue, @escaping (CFDictionary?) -> Void) -> Void
    private typealias MRMediaRemoteGetNowPlayingIsPlayingFn = @convention(c) (DispatchQueue, @escaping (Bool) -> Void) -> Void
    private typealias MRMediaRemoteSendCommandFn = @convention(c) (UInt32, CFDictionary?) -> Bool

    private var registerForNotifications: MRMediaRemoteRegisterForNotificationsFn?
    private var getNowPlayingInfo: MRMediaRemoteGetNowPlayingInfoFn?
    private var getNowPlayingIsPlaying: MRMediaRemoteGetNowPlayingIsPlayingFn?
    private var sendCommand: MRMediaRemoteSendCommandFn?

    private var notificationObservers: [NSObjectProtocol] = []
    public private(set) var isAvailable: Bool = false

    public init() {
        loadMediaRemoteSymbols()
        if isAvailable {
            setupNotifications()
            refreshNowPlaying()
        }
    }

    deinit {
        for observer in notificationObservers {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    private func loadMediaRemoteSymbols() {
        let path = "/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote"
        guard let handle = dlopen(path, RTLD_NOW) else {
            isAvailable = false
            return
        }

        if let regSym = dlsym(handle, "MRMediaRemoteRegisterForNowPlayingNotifications") {
            registerForNotifications = unsafeBitCast(regSym, to: MRMediaRemoteRegisterForNotificationsFn.self)
        }
        if let infoSym = dlsym(handle, "MRMediaRemoteGetNowPlayingInfo") {
            getNowPlayingInfo = unsafeBitCast(infoSym, to: MRMediaRemoteGetNowPlayingInfoFn.self)
        }
        if let isPlayingSym = dlsym(handle, "MRMediaRemoteGetNowPlayingApplicationIsPlaying") {
            getNowPlayingIsPlaying = unsafeBitCast(isPlayingSym, to: MRMediaRemoteGetNowPlayingIsPlayingFn.self)
        }
        if let cmdSym = dlsym(handle, "MRMediaRemoteSendCommand") {
            sendCommand = unsafeBitCast(cmdSym, to: MRMediaRemoteSendCommandFn.self)
        }

        isAvailable = (registerForNotifications != nil && getNowPlayingInfo != nil && sendCommand != nil)
    }

    private func setupNotifications() {
        registerForNotifications?(DispatchQueue.main)

        let notificationNames = [
            "kMRMediaRemoteNowPlayingInfoDidChangeNotification",
            "kMRMediaRemoteNowPlayingApplicationIsPlayingDidChangeNotification",
            "kMRMediaRemotePlayerNowPlayingInfoDidChangeNotification",
            "kMRPlayerPlaybackQueueChangedNotification"
        ]

        for name in notificationNames {
            let obs = NotificationCenter.default.addObserver(
                forName: NSNotification.Name(name),
                object: nil,
                queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.refreshNowPlaying()
                }
            }
            notificationObservers.append(obs)
        }
    }

    public func refreshNowPlaying() {
        guard isAvailable else { return }

        // Query active playback state
        getNowPlayingIsPlaying?(DispatchQueue.main) { [weak self] playing in
            MainActor.assumeIsolated {
                guard let self = self else { return }
                self.isPlaying = playing

                // Query active track info
                self.getNowPlayingInfo?(DispatchQueue.main) { [weak self] rawDict in
                    MainActor.assumeIsolated {
                        guard let self = self else { return }
                        guard let dict = rawDict as? [String: Any] else {
                            self.onUpdate?()
                            return
                        }

                        let title = dict["kMRMediaRemoteNowPlayingInfoTitle"] as? String ?? ""
                        let artist = dict["kMRMediaRemoteNowPlayingInfoArtist"] as? String ?? ""
                        let album = dict["kMRMediaRemoteNowPlayingInfoAlbum"] as? String ?? ""
                        let duration = dict["kMRMediaRemoteNowPlayingInfoDuration"] as? Double

                        if !title.isEmpty {
                            self.currentTrack = Track(
                                title: title,
                                artist: artist.isEmpty ? "Unknown Artist" : artist,
                                album: album,
                                duration: (duration != nil && !duration!.isInfinite) ? duration : nil
                            )

                            // Extract artwork if available
                            if let artData = dict["kMRMediaRemoteNowPlayingInfoArtworkData"] as? Data {
                                self.artwork = NSImage(data: artData)
                            }
                        }

                        self.onUpdate?()
                    }
                }
            }
        }
    }

    // MARK: - Playback Controls

    public func play() {
        _ = sendCommand?(1, nil) // kMRPlay
        isPlaying = true
        onUpdate?()
    }

    public func pause() {
        _ = sendCommand?(2, nil) // kMRPause
        isPlaying = false
        onUpdate?()
    }

    public func togglePlayPause() {
        _ = sendCommand?(0, nil) // kMRTogglePlayPause
        isPlaying.toggle()
        onUpdate?()
    }

    public func next() {
        _ = sendCommand?(4, nil) // kMRNextTrack
    }

    public func previous() {
        _ = sendCommand?(5, nil) // kMRPreviousTrack
    }
}
