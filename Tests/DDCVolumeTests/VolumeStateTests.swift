import XCTest
@testable import Common

final class VolumeStateTests: XCTestCase {

    var state: VolumeState!

    override func setUp() {
        super.setUp()
        state = VolumeState(defaultVolume: 50)
    }

    // MARK: - Initial state

    func testInitialDesired() {
        XCTAssertEqual(state.desired, 50)
    }

    func testInitialLastSentIsNil() {
        XCTAssertNil(state.lastSent)
    }

    func testInitialNotMuted() {
        XCTAssertFalse(state.isMuted)
    }

    func testInitialVolumeClampedHigh() {
        let s = VolumeState(defaultVolume: 200)
        XCTAssertEqual(s.desired, 100)
    }

    func testInitialVolumeClampedLow() {
        let s = VolumeState(defaultVolume: -10)
        XCTAssertEqual(s.desired, 0)
    }

    // MARK: - UP

    func testUpIncrements() {
        _ = state.apply(.up(5))
        XCTAssertEqual(state.desired, 55)
    }

    func testUpClampsAt100() {
        _ = state.apply(.up(200))
        XCTAssertEqual(state.desired, 100)
    }

    func testUpFromZero() {
        let s = VolumeState(defaultVolume: 0)
        _ = s.apply(.up(10))
        XCTAssertEqual(s.desired, 10)
    }

    // MARK: - DOWN

    func testDownDecrements() {
        _ = state.apply(.down(5))
        XCTAssertEqual(state.desired, 45)
    }

    func testDownClampsAt0() {
        _ = state.apply(.down(200))
        XCTAssertEqual(state.desired, 0)
    }

    func testDownFrom100() {
        let s = VolumeState(defaultVolume: 100)
        _ = s.apply(.down(10))
        XCTAssertEqual(s.desired, 90)
    }

    // MARK: - SET

    func testSetVolume() {
        _ = state.apply(.set(75))
        XCTAssertEqual(state.desired, 75)
    }

    func testSetClampsHigh() {
        _ = state.apply(.set(150))
        XCTAssertEqual(state.desired, 100)
    }

    func testSetClampsLow() {
        _ = state.apply(.set(-10))
        XCTAssertEqual(state.desired, 0)
    }

    func testSetZero() {
        _ = state.apply(.set(0))
        XCTAssertEqual(state.desired, 0)
    }

    // MARK: - GET

    func testGetDoesNotChangeVolume() {
        _ = state.apply(.get)
        XCTAssertEqual(state.desired, 50)
    }

    // MARK: - Mute

    func testMuteSetsFlag() {
        _ = state.apply(.mute)
        XCTAssertTrue(state.isMuted)
    }

    func testUnmuteClears() {
        _ = state.apply(.mute)
        _ = state.apply(.unmute)
        XCTAssertFalse(state.isMuted)
    }

    func testToggleMuteFromFalse() {
        _ = state.apply(.toggleMute)
        XCTAssertTrue(state.isMuted)
    }

    func testToggleMuteFromTrue() {
        _ = state.apply(.mute)
        _ = state.apply(.toggleMute)
        XCTAssertFalse(state.isMuted)
    }

    func testMuteDoesNotChangeVolume() {
        _ = state.apply(.mute)
        XCTAssertEqual(state.desired, 50)
    }

    func testVolumeChangesWhileMuted() {
        _ = state.apply(.mute)
        _ = state.apply(.up(10))
        XCTAssertEqual(state.desired, 60)
        XCTAssertTrue(state.isMuted)
    }

    // MARK: - Sync

    func testVolumeSyncNeededInitially() {
        let work = state.syncNeeded()
        XCTAssertEqual(work.volume, 50)
    }

    func testVolumeSyncNotNeededAfterMarkSent() {
        state.markSent(volume: 50)
        let work = state.syncNeeded()
        XCTAssertNil(work.volume)
    }

    func testVolumeSyncNeededAfterChange() {
        state.markSent(volume: 50)
        _ = state.apply(.up(5))
        let work = state.syncNeeded()
        XCTAssertEqual(work.volume, 55)
    }

    func testMuteSendsVolumeZero() {
        state.markSent(volume: 50)
        _ = state.apply(.mute)
        let work = state.syncNeeded()
        XCTAssertEqual(work.volume, 0)
    }

    func testMuteNoSyncAfterVolumeZeroSent() {
        _ = state.apply(.mute)
        state.markSent(volume: 0)
        let work = state.syncNeeded()
        XCTAssertNil(work.volume)
    }

    func testUnmuteRestoresDesiredVolume() {
        _ = state.apply(.mute)
        state.markSent(volume: 0)
        _ = state.apply(.unmute)
        let work = state.syncNeeded()
        XCTAssertEqual(work.volume, 50)
    }

    func testVolumeAdjustWhileMutedDoesNotSync() {
        _ = state.apply(.mute)
        state.markSent(volume: 0)
        _ = state.apply(.up(10))   // desired is now 60, but effective is still 0
        let work = state.syncNeeded()
        XCTAssertNil(work.volume)
    }

    func testUnmuteAfterAdjustRestoresNewVolume() {
        _ = state.apply(.mute)
        state.markSent(volume: 0)
        _ = state.apply(.up(10))
        _ = state.apply(.unmute)
        let work = state.syncNeeded()
        XCTAssertEqual(work.volume, 60)
    }

    // MARK: - resetSync

    func testResetSyncForcesSyncOnNextCheck() {
        state.markSent(volume: 50)
        state.resetSync()
        let work = state.syncNeeded()
        XCTAssertEqual(work.volume, 50)
    }

    // MARK: - initializeFromMonitor

    func testInitializeFromMonitorSetsDesired() {
        state.initializeFromMonitor(80)
        XCTAssertEqual(state.desired, 80)
    }

    func testInitializeFromMonitorSetsLastSent() {
        state.initializeFromMonitor(80)
        XCTAssertEqual(state.lastSent, 80)
    }

    func testInitializeFromMonitorNoSyncNeeded() {
        state.initializeFromMonitor(80)
        let work = state.syncNeeded()
        XCTAssertNil(work.volume)
    }

    // MARK: - StatusResponse from apply

    func testApplyReturnsCorrectStatus() {
        let r = state.apply(.up(10))
        XCTAssertEqual(r.desiredVolume, 60)
        XCTAssertFalse(r.isMuted)
    }

    // MARK: - onChange callback

    func testOnChangeFiredOnApply() {
        let exp = expectation(description: "onChange")
        state.onChange = { exp.fulfill() }
        _ = state.apply(.up(5))
        wait(for: [exp], timeout: 1)
    }

    func testOnChangeFiredOnMarkSent() {
        let exp = expectation(description: "onChange")
        state.onChange = { exp.fulfill() }
        state.markSent(volume: 50)
        wait(for: [exp], timeout: 1)
    }
}
