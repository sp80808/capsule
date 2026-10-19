//
//  VolumeStore.swift
//  Capsule
//
//  Persists per-app mixer state. Volume and mute used to live only in memory,
//  so every relaunch (and every manual refresh) reset the user's mix.
//

import Foundation

struct VolumeStore {

    static let shared = VolumeStore()

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    // MARK: - Keys

    private enum Key {
        static let levels = "capsule.appLevels.v1"
        static let hidden = "capsule.hiddenApps.v1"
        static let demoMode = "capsule.demoMode"
        static let lastDevice = "capsule.lastOutputDevice"
        static let globalShortcuts = "capsule.globalShortcuts"
        static let snapshots = "capsule.snapshots.v1"
        static let deviceVolumes = "capsule.deviceVolumes.v1"
        static let rememberDeviceVolumes = "capsule.rememberDeviceVolumes"
    }

    // MARK: - Per-app levels

    struct Level: Codable, Equatable {
        var volume: Double
        var isMuted: Bool

        init(volume: Double, isMuted: Bool) {
            self.volume = volume
            self.isMuted = isMuted
        }
    }

    func levels() -> [String: Level] {
        guard let data = defaults.data(forKey: Key.levels) else { return [:] }
        let decoder = JSONDecoder()
        return (try? decoder.decode([String: Level].self, from: data)) ?? [:]
    }

    func saveLevel(_ level: Level, forApp id: String) {
        var all = levels()
        all[id] = level
        persist(all)
    }

    func removeLevel(forApp id: String) {
        var all = levels()
        all.removeValue(forKey: id)
        persist(all)
    }

    private func persist(_ all: [String: Level]) {
        guard let data = try? JSONEncoder().encode(all) else { return }
        defaults.set(data, forKey: Key.levels)
    }

    // MARK: - Hidden apps

    func hiddenAppIDs() -> Set<String> {
        Set(defaults.stringArray(forKey: Key.hidden) ?? [])
    }

    func saveHiddenAppIDs(_ ids: Set<String>) {
        defaults.set(Array(ids).sorted(), forKey: Key.hidden)
    }

    // MARK: - Preferences

    /// Demo Mode simulates playback levels. It defaults to on because per-app
    /// capture needs the Capsule audio driver, which is not wired up yet —
    /// without it every row would sit at "Idle" forever.
    var demoMode: Bool {
        get { defaults.object(forKey: Key.demoMode) as? Bool ?? true }
        // The setter only touches UserDefaults (a reference type), so it must
        // not be `mutating` — `AudioManager` holds the store as a `let`.
        nonmutating set { defaults.set(newValue, forKey: Key.demoMode) }
    }

    var lastOutputDeviceName: String? {
        get { defaults.string(forKey: Key.lastDevice) }
        nonmutating set { defaults.set(newValue, forKey: Key.lastDevice) }
    }

    // MARK: - Snapshots & device memory

    func snapshots() -> [MixSnapshot] {
        guard let data = defaults.data(forKey: Key.snapshots) else { return [] }
        let stored = (try? JSONDecoder().decode([MixSnapshot].self, from: data)) ?? []
        return stored.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    func saveSnapshots(_ snapshots: [MixSnapshot]) {
        guard let data = try? JSONEncoder().encode(snapshots) else { return }
        defaults.set(data, forKey: Key.snapshots)
    }

    func deviceVolumeMemory() -> DeviceVolumeMemory {
        guard let data = defaults.data(forKey: Key.deviceVolumes) else { return DeviceVolumeMemory() }
        return (try? JSONDecoder().decode(DeviceVolumeMemory.self, from: data)) ?? DeviceVolumeMemory()
    }

    func saveDeviceVolumeMemory(_ memory: DeviceVolumeMemory) {
        guard let data = try? JSONEncoder().encode(memory) else { return }
        defaults.set(data, forKey: Key.deviceVolumes)
    }

    /// Restore each output device's last master volume when you switch to it.
    var rememberDeviceVolumes: Bool {
        get { defaults.object(forKey: Key.rememberDeviceVolumes) as? Bool ?? true }
        nonmutating set { defaults.set(newValue, forKey: Key.rememberDeviceVolumes) }
    }

    /// System-wide hot keys are opt-in: they grab chords in every app, so the
    /// user has to ask for them.
    var globalShortcutsEnabled: Bool {
        get { defaults.bool(forKey: Key.globalShortcuts) }
        nonmutating set { defaults.set(newValue, forKey: Key.globalShortcuts) }
    }
}
