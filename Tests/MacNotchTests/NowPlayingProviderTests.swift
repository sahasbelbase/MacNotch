import XCTest
@testable import MacNotch
import AppKit

@MainActor
final class MockNowPlayingProvider: NowPlayingProvider {
    var isPlaying: Bool = false
    var currentTrack: Track?
    var artwork: NSImage?
    var providerName: String = "Mock Player"

    var playCallCount = 0
    var pauseCallCount = 0
    var toggleCallCount = 0
    var nextCallCount = 0
    var prevCallCount = 0

    func play() {
        playCallCount += 1
        isPlaying = true
    }

    func pause() {
        pauseCallCount += 1
        isPlaying = false
    }

    func togglePlayPause() {
        toggleCallCount += 1
        isPlaying.toggle()
    }

    func next() {
        nextCallCount += 1
    }

    func previous() {
        prevCallCount += 1
    }
}

final class NowPlayingProviderTests: XCTestCase {
    @MainActor
    func testMockProviderPlaybackControls() {
        let provider = MockNowPlayingProvider()
        XCTAssertFalse(provider.isPlaying)

        provider.play()
        XCTAssertTrue(provider.isPlaying)
        XCTAssertEqual(provider.playCallCount, 1)

        provider.pause()
        XCTAssertFalse(provider.isPlaying)
        XCTAssertEqual(provider.pauseCallCount, 1)

        provider.togglePlayPause()
        XCTAssertTrue(provider.isPlaying)
        XCTAssertEqual(provider.toggleCallCount, 1)

        provider.next()
        XCTAssertEqual(provider.nextCallCount, 1)

        provider.previous()
        XCTAssertEqual(provider.prevCallCount, 1)
    }

    @MainActor
    func testTrackMetadataHandling() {
        let longTitle = String(repeating: "A Very Long Track Title That Exceeds Normal Length ", count: 4)
        let track = Track(
            title: longTitle,
            artist: "Artist Name",
            album: "Album Name",
            duration: 245.5
        )

        XCTAssertEqual(track.title, longTitle)
        XCTAssertEqual(track.artist, "Artist Name")
        XCTAssertEqual(track.album, "Album Name")
        XCTAssertEqual(track.duration, 245.5)
    }

    @MainActor
    func testMusicStudioProviderInitialization() {
        let provider = MusicStudioNowPlayingProvider()
        XCTAssertEqual(provider.providerName, "Music Studio")
        XCTAssertFalse(provider.isPlaying)
        XCTAssertNil(provider.currentTrack)
        XCTAssertNil(provider.artwork)
    }

    @MainActor
    func testMusicStudioTrackModelAndPlayback() {
        let track = MusicStudioTrack(
            filename: "Socha Hai.mp3",
            title: "Socha Hai",
            artist: "Farhan Akhtar",
            album: "Rock On!!",
            year: "2010",
            genre: "Bollywood",
            duration: 262.0,
            size_mb: 10.39,
            bitrate: "320 kbps"
        )

        XCTAssertEqual(track.id, "Socha Hai.mp3")
        XCTAssertEqual(track.title, "Socha Hai")
        XCTAssertEqual(track.artist, "Farhan Akhtar")
        XCTAssertEqual(track.duration, 262.0)

        let provider = MusicStudioNowPlayingProvider()
        provider.playTrack(track)

        XCTAssertTrue(provider.isPlaying)
        XCTAssertEqual(provider.currentTrack?.title, "Socha Hai")
        XCTAssertEqual(provider.currentTrack?.artist, "Farhan Akhtar")
        XCTAssertTrue(provider.isAvailable)
    }

    @MainActor
    func testKeywordActionDefinitions() {
        let playAction = MusicStudioListView.KeywordAction.play
        let pauseAction = MusicStudioListView.KeywordAction.pause
        let forwardAction = MusicStudioListView.KeywordAction.forward
        let prevAction = MusicStudioListView.KeywordAction.previous

        XCTAssertEqual(playAction.title, "Play")
        XCTAssertEqual(pauseAction.title, "Pause")
        XCTAssertEqual(forwardAction.title, "Forward (Next Song)")
        XCTAssertEqual(prevAction.title, "Previous (Rewind)")

        XCTAssertEqual(playAction.icon, "play.fill")
        XCTAssertEqual(pauseAction.icon, "pause.fill")
        XCTAssertEqual(forwardAction.icon, "forward.fill")
        XCTAssertEqual(prevAction.icon, "backward.fill")

        let track = MusicStudioTrack(filename: "test.mp3", title: "Test Song", artist: "Artist", album: "Album")
        let trackAction = MusicStudioListView.KeywordAction.playTrack(track)
        XCTAssertEqual(trackAction.title, "Play \"Test Song\"")
        XCTAssertEqual(trackAction.icon, "play.circle.fill")
    }

    @MainActor
    func testEnsureMusicStudioRunningWhenClosed() async {
        let provider = MusicStudioNowPlayingProvider()
        let exp = expectation(description: "Ensure Music Studio running completes")

        provider.ensureMusicStudioRunning { ready in
            XCTAssertTrue(ready, "Music Studio should launch in the background and respond on port 5050")
            exp.fulfill()
        }

        await fulfillment(of: [exp], timeout: 15.0)
    }

    @MainActor
    func testOnlineStreamTrackModelAndStreaming() {
        let streamTrack = MusicStudioTrack(
            filename: "",
            title: "Viva La Vida",
            artist: "Coldplay",
            album: "Viva La Vida",
            duration: 242.0,
            cover_url: "https://example.com/art.jpg",
            query: "Coldplay - Viva La Vida Official Audio"
        )

        XCTAssertTrue(streamTrack.isStream)
        XCTAssertEqual(streamTrack.id, "Coldplay-Viva La Vida")
        XCTAssertEqual(streamTrack.title, "Viva La Vida")
        XCTAssertEqual(streamTrack.artist, "Coldplay")
        XCTAssertEqual(streamTrack.cover_url, "https://example.com/art.jpg")
        XCTAssertEqual(streamTrack.query, "Coldplay - Viva La Vida Official Audio")

        let provider = MusicStudioNowPlayingProvider()
        provider.streamTrack(streamTrack)

        XCTAssertTrue(provider.isPlaying)
        XCTAssertEqual(provider.currentTrack?.title, "Viva La Vida")
        XCTAssertEqual(provider.currentTrack?.artist, "Coldplay")
        XCTAssertEqual(provider.currentTrack?.album, "Viva La Vida")
        XCTAssertEqual(provider.duration, 242.0)
    }

    @MainActor
    func testOnlineTrackSearchAPI() async {
        let provider = MusicStudioNowPlayingProvider()
        let results = await provider.searchOnlineTracks(query: "Coldplay")
        // When Music Studio is running, search returns live Deezer results
        if !results.isEmpty {
            let first = results[0]
            XCTAssertTrue(first.isStream)
            XCTAssertFalse(first.title.isEmpty)
            XCTAssertFalse(first.artist.isEmpty)
        }
    }

    @MainActor
    func testDeleteTrackSafety() async {
        let provider = MusicStudioNowPlayingProvider()
        // Empty filename (stream track) should fail immediately
        let streamTrack = MusicStudioTrack(filename: "", title: "Test", artist: "Artist", album: "Album")
        let streamResult = await provider.deleteTrack(streamTrack)
        XCTAssertFalse(streamResult, "Deleting a stream track with empty filename should fail")

        // Nonexistent file should fail safely without crashing
        let fakeTrack = MusicStudioTrack(filename: "nonexistent_track_99999.mp3", title: "Nonexistent", artist: "Ghost", album: "Void")
        let fakeResult = await provider.deleteTrack(fakeTrack)
        XCTAssertFalse(fakeResult, "Deleting a nonexistent file should return false")
    }

    @MainActor
    func testActiveAudioPlayerEnumProperties() {
        XCTAssertEqual(ActiveAudioPlayer.musicStudio.rawValue, "Music Studio")
        XCTAssertEqual(ActiveAudioPlayer.spotify.rawValue, "Spotify")
        XCTAssertEqual(ActiveAudioPlayer.appleMusic.rawValue, "Apple Music")
        XCTAssertEqual(ActiveAudioPlayer.youtubeMusic.rawValue, "YouTube Music")
        XCTAssertEqual(ActiveAudioPlayer.mediaRemote.rawValue, "Media Player")
    }

    @MainActor
    func testSystemNowPlayingServiceDetection() {
        let service = SystemNowPlayingService()
        // Detection properties should be boolean and should evaluate without crashing or throwing
        _ = service.isMusicStudioDownloaded
        _ = service.isSpotifyDownloaded
        _ = service.isAppleMusicDownloaded
        _ = service.isYouTubeMusicDownloaded

        _ = service.isMusicStudioRunning
        _ = service.isSpotifyRunning
        _ = service.isAppleMusicRunning
        _ = service.isYouTubeMusicRunning

        // Active player should always resolve to a valid ActiveAudioPlayer enum
        XCTAssertNotNil(service.activePlayer)
        XCTAssertFalse(service.activePlayer.rawValue.isEmpty)
    }
}

