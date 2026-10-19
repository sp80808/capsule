//
//  AudioManagerTests.swift
//  CapsuleTests
//
//  Covers the parts of the mixer that are pure logic: mute, solo, timed mutes,
//  snapshots, focus fallbacks and persistence. No Core Audio, no views.
//

import XCTest
@testable import Capsule

final class AudioManagerTests: XCTestCase {

    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "capsule.tests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    // MARK: - Helpers

    private func makeStore() -> VolumeStore {
        VolumeStore(defaults: defaults)
    }

    /// a: audible, b: audible, c: already muted — so "restore" has something it
    /// must deliberately leave alone.
    private func makeManager() -> (AudioManager, AudioApp, AudioApp, AudioApp) {
        let manager = AudioManager(store: makeStore())
        let a = AudioApp(id: "a", name: "A", volume: 0.8)
        let b = AudioApp(id: "b", name: "B", volume: 0.5)
        let c = AudioApp(id: "c", name: "C", volume: 0.3, isMuted: true)
        manager.replaceApps(with: [a, b, c])
        return (manager, a, b, c)
    }

    // MARK: - Mute

    func testSetVolumeUnmutes() {
        let (manager, a, _, _) = makeManager()
        manager.setMuted(true, for: a)
        XCTAssertTrue(a.isMuted)

        manager.setVolume(0.5, for: a)
        XCTAssertFalse(a.isMuted, "raising the level should unmute")
    }

    func testVolumeIsClamped() {
        let (manager, a, _, _) = makeManager()

        manager.setVolume(4, for: a)
        XCTAssertEqual(a.volume, 1, accuracy: 0.0001)

        manager.setVolume(-2, for: a)
        XCTAssertEqual(a.volume, 0, accuracy: 0.0001)
    }

    func testNudgeVolumeFromMutedStartsAtZero() {
        let (manager, a, _, _) = makeManager()
        a.volume = 0.6
        manager.setMuted(true, for: a)
        manager.nudgeVolume(0.05, for: a)

        XCTAssertFalse(a.isMuted)
        XCTAssertEqual(a.volume, 0.05, accuracy: 0.0001)
    }

    // MARK: - Solo ("mute all but this")

    func testSoloMutesOthersAndKeepsTargetAudible() {
        let (manager, a, b, c) = makeManager()
        manager.muteAllExcept(b)

        XCTAssertTrue(a.isMuted)
        XCTAssertTrue(c.isMuted)
        XCTAssertFalse(b.isMuted)
        XCTAssertEqual(manager.soloedAppID, "b")
        XCTAssertTrue(manager.isSoloActive)
    }

    func testSoloRestoreOnlyUnmutesWhatItSilenced() {
        let (manager, a, b, c) = makeManager()
        manager.muteAllExcept(b)
        manager.restoreSoloedApps()

        XCTAssertFalse(a.isMuted, "a was silenced by the solo, so it comes back")
        XCTAssertTrue(c.isMuted, "c was already muted before the solo")
        XCTAssertNil(manager.soloedAppID)
        XCTAssertFalse(manager.isSoloActive)
    }

    func testToggleSoloTwiceRestoresTheMix() {
        let (manager, a, b, _) = makeManager()
        manager.toggleSolo(b)
        XCTAssertTrue(a.isMuted)

        manager.toggleSolo(b)
        XCTAssertFalse(a.isMuted)
        XCTAssertNil(manager.soloedAppID)
    }

    func testMutingTheSoloedAppEndsTheSolo() {
        let (manager, _, b, _) = makeManager()
        manager.muteAllExcept(b)
        manager.setMuted(true, for: b)

        XCTAssertNil(manager.soloedAppID, "a solo with a muted target is not a solo")
    }

    func testUnmuteAllClearsSolo() {
        let (manager, a, b, c) = makeManager()
        manager.muteAllExcept(b)
        manager.unmuteAll()

        XCTAssertFalse(a.isMuted)
        XCTAssertFalse(b.isMuted)
        XCTAssertFalse(c.isMuted)
        XCTAssertNil(manager.soloedAppID)
    }

    func testMuteAllSilencesEverything() {
        let (manager, a, b, c) = makeManager()
        manager.muteAll()

        XCTAssertTrue(a.isMuted && b.isMuted && c.isMuted)
        XCTAssertTrue(manager.everythingMuted)
    }

    // MARK: - Timed mutes

    func testTimedMuteExpiresOnSchedule() {
        let (manager, a, _, _) = makeManager()
        let start = Date()

        manager.mute(a, forMinutes: 5)
        XCTAssertTrue(a.isMuted)
        XCTAssertTrue(manager.hasTimedMute(a))

        manager.expireDueMutes(now: start.addingTimeInterval(60))
        XCTAssertTrue(a.isMuted, "still inside the window")

        manager.expireDueMutes(now: start.addingTimeInterval(301))
        XCTAssertFalse(a.isMuted, "the timed mute should have released it")
        XCTAssertFalse(manager.hasTimedMute(a))
    }

    func testManualUnmuteCancelsTheTimer() {
        let (manager, a, _, _) = makeManager()
        manager.mute(a, forMinutes: 5)
        manager.setMuted(false, for: a)

        XCTAssertFalse(manager.hasTimedMute(a))
    }

    func testCancelTimedMuteKeepsTheAppMuted() {
        let (manager, a, _, _) = makeManager()
        manager.mute(a, forMinutes: 5)
        manager.cancelTimedMute(a)

        XCTAssertFalse(manager.hasTimedMute(a))
        XCTAssertTrue(a.isMuted, "cancelling the timer must not unmute")
    }

    func testMuteAllCancelsPendingTimers() {
        let (manager, a, _, _) = makeManager()
        manager.mute(a, forMinutes: 5)
        manager.muteAll()

        XCTAssertFalse(manager.hasTimedMute(a), "a blanket mute replaces the schedule")
    }

    func testCountdownTextCountsDown() {
        let (manager, a, _, _) = makeManager()
        manager.mute(a, forMinutes: 1)

        let text = manager.countdownText(a)
        XCTAssertNotNil(text)
        XCTAssertTrue(text?.hasPrefix("1:0") ?? false, "expected 1:0x, got \(text ?? "nil")")
    }

    // MARK: - Snapshots

    func testSnapshotRoundTrip() {
        let (manager, a, b, _) = makeManager()
        let snapshot = manager.captureSnapshot(named: "Meeting")

        manager.setVolume(0.1, for: a)
        manager.setMuted(true, for: b)
        manager.applySnapshot(snapshot)

        XCTAssertEqual(a.volume, 0.8, accuracy: 0.0001)
        XCTAssertFalse(b.isMuted)
    }

    func testSnapshotNameIsNormalised() {
        let (manager, _, _, _) = makeManager()
        let snapshot = manager.captureSnapshot(named: "   ")

        XCTAssertFalse(snapshot.name.isEmpty)
    }

    func testSavingTheSameNameReplaces() {
        let (manager, _, _, _) = makeManager()
        manager.captureSnapshot(named: "Meeting")
        manager.captureSnapshot(named: "Meeting")

        XCTAssertEqual(manager.snapshots.count, 1)
    }

    func testDeleteSnapshot() {
        let (manager, _, _, _) = makeManager()
        let snapshot = manager.captureSnapshot(named: "Focus")
        manager.deleteSnapshot(snapshot)

        XCTAssertTrue(manager.snapshots.isEmpty)
    }

    func testSnapshotLeavesUnknownAppsAlone() {
        let (manager, a, _, _) = makeManager()
        let snapshot = manager.captureSnapshot(named: "Meeting")

        let stranger = AudioApp(id: "z", name: "Z", volume: 0.25)
        manager.replaceApps(with: [a, stranger])
        manager.setVolume(0.9, for: a)
        manager.applySnapshot(snapshot)

        XCTAssertEqual(a.volume, 0.8, accuracy: 0.0001)
        XCTAssertEqual(stranger.volume, 0.25, accuracy: 0.0001, "not in the snapshot, so untouched")
    }

    // MARK: - Focus and shortcut targets

    func testShortcutTargetNeedsASelectionWithSeveralApps() {
        let (manager, _, b, _) = makeManager()
        XCTAssertNil(manager.shortcutTarget)

        manager.requestFocus(b)
        XCTAssertEqual(manager.shortcutTarget?.id, "b")
    }

    func testFocusFallsBackWhenTheAppDisappears() {
        let (manager, _, b, _) = makeManager()
        manager.requestFocus(b)
        manager.replaceApps(with: [AudioApp(id: "a", name: "A")])

        XCTAssertEqual(manager.focusedAppID, "a")
    }

    func testHotKeyTargetFallsBackToTheLoudestPlayingApp() {
        let (manager, a, b, _) = makeManager()
        a.isPlaying = true
        a.level = 0.2
        b.isPlaying = true
        b.level = 0.9

        XCTAssertEqual(manager.hotKeyTarget?.id, "b")
    }

    func testHotKeyFromHotKeyMutesTheFallbackTarget() {
        let (manager, _, b, _) = makeManager()
        b.isPlaying = true
        b.level = 0.7

        manager.toggleMuteFromHotKey()
        XCTAssertTrue(b.isMuted)
    }

    // MARK: - Visibility

    func testHiddenAppsLeaveTheMixerListButStayKnown() {
        let (manager, a, _, _) = makeManager()
        manager.toggleHidden(a)

        XCTAssertTrue(manager.isHidden(a))
        XCTAssertEqual(manager.visibleApps.count, 2)
        XCTAssertEqual(manager.hiddenApps.count, 1)

        manager.toggleHidden(a)
        XCTAssertEqual(manager.visibleApps.count, 3)
    }

    // MARK: - Persistence

    func testLevelsPersistAcrossInstances() {
        let (manager, a, b, _) = makeManager()
        manager.setVolume(0.42, for: a)
        manager.setMuted(true, for: b)

        let revived = AudioManager(store: makeStore())
        let newA = AudioApp(id: "a", name: "A", volume: 0.8)
        let newB = AudioApp(id: "b", name: "B", volume: 0.8)
        revived.replaceApps(with: [newA, newB])

        XCTAssertEqual(newA.volume, 0.42, accuracy: 0.0001)
        XCTAssertTrue(newB.isMuted)
    }

    func testSnapshotsAndHiddenAppsPersist() {
        let (manager, a, _, _) = makeManager()
        manager.captureSnapshot(named: "Late night")
        manager.toggleHidden(a)

        let revived = AudioManager(store: makeStore())
        XCTAssertEqual(revived.snapshots.map { $0.name }, ["Late night"])
        XCTAssertTrue(revived.hiddenAppIDs.contains("a"))
    }

    // MARK: - Status

    func testStatusGlyphReflectsTheMuteState() {
        let (manager, _, _, _) = makeManager()
        XCTAssertEqual(manager.statusGlyph, "speaker.wave.2.fill")

        manager.muteAll()
        XCTAssertEqual(manager.statusGlyph, "speaker.slash.fill")

        manager.unmuteAll()
        XCTAssertEqual(manager.statusGlyph, "speaker.wave.2.fill")
    }
}
