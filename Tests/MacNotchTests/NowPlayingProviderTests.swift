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
}
