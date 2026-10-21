//
//  VolumeStoreTests.swift
//  CapsuleTests
//
//  Persistence round-trips and the two pure value types.
//

import XCTest
@testable import Capsule

final class VolumeStoreTests: XCTestCase {

    private var suiteName: String!
    private var defaults: UserDefaults!
    private var store: VolumeStore!

    override func setUp() {
        super.setUp()
        suiteName = "capsule.store.tests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
        store = VolumeStore(defaults: defaults)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        store = nil
        suiteName = nil
        super.tearDown()
    }

    // MARK: - Levels

    func testLevelRoundTrip() {
        store.saveLevel(VolumeStore.Level(volume: 0.35, isMuted: true), forApp: "com.apple.Music")
        let levels = store.levels()

        XCTAssertEqual(levels["com.apple.Music"]?.volume, 0.35)
        XCTAssertEqual(levels["com.apple.Music"]?.isMuted, true)
    }

    func testSaveLevelKeepsOtherApps() {
        store.saveLevel(VolumeStore.Level(volume: 0.1, isMuted: false), forApp: "a")
        store.saveLevel(VolumeStore.Level(volume: 0.2, isMuted: false), forApp: "b")

        XCTAssertEqual(store.levels().count, 2)
    }

    func testRemoveLevel() {
        store.saveLevel(VolumeStore.Level(volume: 0.1, isMuted: false), forApp: "a")
        store.removeLevel(forApp: "a")

        XCTAssertTrue(store.levels().isEmpty)
    }

    // MARK: - Preferences

    func testDefaults() {
        XCTAssertTrue(store.demoMode, "demo mode is on until the driver lands")
        XCTAssertFalse(store.globalShortcutsEnabled, "system-wide chords are opt-in")
        XCTAssertTrue(store.rememberDeviceVolumes)
        XCTAssertTrue(store.hiddenAppIDs().isEmpty)
        XCTAssertTrue(store.snapshots().isEmpty)
    }

    func testPreferenceRoundTrip() {
        store.demoMode = false
        store.globalShortcutsEnabled = true
        store.rememberDeviceVolumes = false
        store.saveHiddenAppIDs(["a", "b"])
        store.lastOutputDeviceName = "Studio Display"

        let revived = VolumeStore(defaults: defaults)
        XCTAssertFalse(revived.demoMode)
        XCTAssertTrue(revived.globalShortcutsEnabled)
        XCTAssertFalse(revived.rememberDeviceVolumes)
        XCTAssertEqual(revived.hiddenAppIDs(), ["a", "b"])
        XCTAssertEqual(revived.lastOutputDeviceName, "Studio Display")
    }

    // MARK: - Snapshots

    func testSnapshotRoundTrip() {
        let snapshot = MixSnapshot(
            name: "Meeting",
            levels: ["a": VolumeStore.Level(volume: 0.8, isMuted: false)]
        )
        store.saveSnapshots([snapshot])

        let loaded = store.snapshots()
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded.first?.name, "Meeting")
        XCTAssertEqual(loaded.first?.levels["a"]?.volume, 0.8)
    }

    func testSnapshotsAreSortedByName() {
        store.saveSnapshots([
            MixSnapshot(name: "Zeta"),
            MixSnapshot(name: "Alpha")
        ])

        XCTAssertEqual(store.snapshots().map { $0.name }, ["Alpha", "Zeta"])
    }

    // MARK: - Device volume memory

    func testDeviceVolumeMemoryRoundTrip() {
        var memory = store.deviceVolumeMemory()
        memory.remember(0.4, for: "Headphones")
        store.saveDeviceVolumeMemory(memory)

        let revived = VolumeStore(defaults: defaults)
        XCTAssertEqual(revived.deviceVolumeMemory().volume(for: "Headphones"), 0.4)
        XCTAssertNil(revived.deviceVolumeMemory().volume(for: "Speakers"))
    }

    // MARK: - Pure value types

    func testDeviceVolumeMemoryClamps() {
        var memory = DeviceVolumeMemory()
        memory.remember(1.8, for: "Speakers")
        memory.remember(-0.5, for: "Headphones")

        XCTAssertEqual(memory.volume(for: "Speakers"), 1)
        XCTAssertEqual(memory.volume(for: "Headphones"), 0)
        XCTAssertEqual(memory.deviceNames, ["Headphones", "Speakers"])
        XCTAssertFalse(memory.isEmpty)
    }

    func testSnapshotNameNormalisation() {
        XCTAssertEqual(MixSnapshot(name: "  Focus  ").name, "Focus")
        XCTAssertFalse(MixSnapshot(name: "").name.isEmpty)
        XCTAssertFalse(MixSnapshot(name: "\n\t").name.isEmpty)
    }

    func testSnapshotFallbackName() {
        XCTAssertTrue(MixSnapshot.fallbackName().hasPrefix("Mix "))
    }

    func testSnapshotCodableRoundTrip() throws {
        let original = MixSnapshot(
            name: "Late night",
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            levels: [
                "a": VolumeStore.Level(volume: 0.2, isMuted: false),
                "b": VolumeStore.Level(volume: 0.9, isMuted: true)
            ]
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(MixSnapshot.self, from: data)

        XCTAssertEqual(decoded, original)
    }

    func testDeviceVolumeMemoryCodableRoundTrip() throws {
        var original = DeviceVolumeMemory()
        original.remember(0.55, for: "Studio Display")

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(DeviceVolumeMemory.self, from: data)

        XCTAssertEqual(decoded.volume(for: "Studio Display"), 0.55)
        XCTAssertEqual(decoded, original)
    }
}
