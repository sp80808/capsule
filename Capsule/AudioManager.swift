//
//  AudioManager.swift
//  Capsule
//
//  The mixer's single source of truth: which apps are listed, their levels,
//  mute/solo state, which app the keyboard shortcuts act on, and the output
//  device. Views never mutate an `AudioApp` directly — they go through here so
//  every change is applied to Core Audio and persisted.
//

import AppKit
import Combine
import CoreAudio
import Foundation

final class AudioManager: ObservableObject {

    static let shared = AudioManager()

    // MARK: - Published state

    /// Every app Capsule knows about, in display order.
    @Published private(set) var apps: [AudioApp] = []

    /// Apps the user chose to hide from the mixer.
    @Published private(set) var hiddenAppIDs: Set<String> = []

    @Published private(set) var devices: [AudioDevice] = []
    @Published private(set) var defaultDeviceID: AudioDeviceID?
    /// nil when the current device has no software volume control.
    @Published private(set) var masterVolume: Double?
    @Published private(set) var masterMuted: Bool = false

    /// The app the keyboard shortcuts (⌘M, ⌥⌘M, ⌥↑…) act on.
    @Published var focusedAppID: AudioApp.ID?

    /// Bumped on every "reveal this app" request so the list can scroll even
    /// when the same row is focused twice in a row.
    @Published private(set) var focusToken: Int = 0

    /// The app currently soloed by "Mute All Others", if any.
    @Published private(set) var soloedAppID: AudioApp.ID?

    /// Simulated playback levels, until the per-app audio driver lands.
    @Published var demoMode: Bool {
        didSet {
            guard demoMode != oldValue else { return }
            store.demoMode = demoMode
            if !demoMode { clearDemoLevels() }
        }
    }

    /// System-wide hot keys (⌃⌥⌘M and friends), opt-in from Settings.
    @Published var globalShortcutsEnabled: Bool {
        didSet {
            guard globalShortcutsEnabled != oldValue else { return }
            store.globalShortcutsEnabled = globalShortcutsEnabled
            syncGlobalShortcuts()
        }
    }

    /// When a timed mute expires, keyed by app id.
    @Published private(set) var muteExpiries: [AudioApp.ID: Date] = [:]

    /// Ticks once a second while a countdown is running, so rows can repaint
    /// their remaining time.
    @Published private(set) var countdownTick: Int = 0

    /// SF Symbol for the menu bar item, reflecting the current mute state.
    @Published private(set) var statusGlyph: String = "speaker.wave.2.fill"

    // MARK: - Derived state

    var visibleApps: [AudioApp] { apps.filter { !hiddenAppIDs.contains($0.id) } }

    /// Apps the user hid from the mixer (Settings → Hidden apps).
    var hiddenApps: [AudioApp] { apps.filter { hiddenAppIDs.contains($0.id) } }

    var focusedApp: AudioApp? {
        guard let focusedAppID else { return nil }
        return apps.first { $0.id == focusedAppID }
    }

    /// The soloed app object, if it is still in the list.
    var soloedApp: AudioApp? {
        guard let soloedAppID else { return nil }
        return apps.first { $0.id == soloedAppID }
    }

    var mutedCount: Int { apps.filter { $0.isMuted }.count }

    var everythingMuted: Bool { !apps.isEmpty && apps.allSatisfy { $0.isSilenced } }

    var isSoloActive: Bool { soloedAppID != nil }

    // MARK: - Internals

    private let store: VolumeStore
    private var subscriptions: [AudioApp.ID: [AnyCancellable]] = [:]
    private var workspaceObservers: [NSObjectProtocol] = []
    private var monitorTimer: Timer?
    private var expiryTimer: Timer?
    private var demoTick: Int = 0
    /// Apps silenced by the current solo, so "Restore" can undo it exactly.
    private var silencedBySolo: Set<AudioApp.ID> = []
    private var didInitialize = false

    init(store: VolumeStore = .shared) {
        self.store = store
        self.demoMode = store.demoMode
        self.globalShortcutsEnabled = store.globalShortcutsEnabled
        self.hiddenAppIDs = store.hiddenAppIDs()
    }

    // MARK: - Lifecycle

    func initialize() {
        guard !didInitialize else { return }
        didInitialize = true

        refreshApps()
        refreshDevices()
        startMonitoring()
        syncGlobalShortcuts()

        let workspace = NSWorkspace.shared.notificationCenter
        let notifications: [NSNotification.Name] = [
            NSWorkspace.didLaunchApplicationNotification,
            NSWorkspace.didTerminateApplicationNotification
        ]
        for name in notifications {
            let observer = workspace.addObserver(
                forName: name,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.refreshApps()
            }
            workspaceObservers.append(observer)
        }
    }

    func shutdown() {
        monitorTimer?.invalidate()
        monitorTimer = nil

        expiryTimer?.invalidate()
        expiryTimer = nil

        GlobalHotKeyCenter.shared.uninstall()

        let workspace = NSWorkspace.shared.notificationCenter
        workspaceObservers.forEach { workspace.removeObserver($0) }
        workspaceObservers.removeAll()
    }

    private func startMonitoring() {
        monitorTimer?.invalidate()
        monitorTimer = Timer.scheduledTimer(withTimeInterval: 0.75, repeats: true) { [weak self] _ in
            guard let self else { return }
            if self.demoMode { self.updateDemoLevels() }
            self.updateStatusGlyph()
        }
    }

    // MARK: - App list

    /// Re-reads the running application list. Existing `AudioApp` instances are
    /// reused so SwiftUI keeps row identity (and therefore focus, selection and
    /// scroll position) across refreshes.
    func refreshApps() {
        let running = NSWorkspace.shared.runningApplications
        let ownBundleID = Bundle.main.bundleIdentifier

        var next: [AudioApp] = []
        var seen: Set<String> = []

        for app in running {
            guard app.activationPolicy == .regular else { continue }
            guard let name = app.localizedName, !name.isEmpty else { continue }

            let bundleID = app.bundleIdentifier
            if let bundleID, bundleID == ownBundleID { continue }

            let id = bundleID ?? "pid-\(app.processIdentifier)"
            guard !seen.contains(id) else { continue }
            seen.insert(id)

            next.append(
                AudioApp(
                    id: id,
                    name: name,
                    bundleIdentifier: bundleID,
                    processIdentifier: app.processIdentifier,
                    icon: app.icon,
                    volume: 0.8
                )
            )
        }

        next.sort { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        apply(next)
    }

    /// Swaps in a brand new list — used by previews and tests.
    func replaceApps(with newApps: [AudioApp]) {
        apply(newApps)
    }

    private func apply(_ newApps: [AudioApp]) {
        let saved = store.levels()
        var byID: [AudioApp.ID: AudioApp] = [:]
        byID.reserveCapacity(apps.count)
        for app in apps { byID[app.id] = app }

        var result: [AudioApp] = []
        result.reserveCapacity(newApps.count)

        for app in newApps {
            if let existing = byID[app.id] {
                result.append(existing)
                continue
            }

            if let level = saved[app.id] {
                app.volume = AudioApp.clamp(level.volume)
                app.isMuted = level.isMuted
            }
            result.append(app)
            observe(app)
        }

        let surviving = Set(result.map { $0.id })
        for id in byID.keys where !surviving.contains(id) {
            subscriptions[id]?.forEach { $0.cancel() }
            subscriptions[id] = nil
        }

        apps = result

        if let focusedAppID, !surviving.contains(focusedAppID) {
            self.focusedAppID = result.first?.id
        }
        if let soloedAppID, !surviving.contains(soloedAppID) {
            clearSolo()
        }

        updateStatusGlyph()
    }

    /// Persists and applies any later change to an app's level or mute state,
    /// no matter which view caused it.
    private func observe(_ app: AudioApp) {
        subscriptions[app.id]?.forEach { $0.cancel() }

        let volumeSubscription = app.$volume
            .dropFirst()
            .removeDuplicates()
            .sink { [weak self, weak app] value in
                guard let self, let app else { return }
                self.store.saveLevel(
                    VolumeStore.Level(volume: value, isMuted: app.isMuted),
                    forApp: app.id
                )
                self.applyToAudioEngine(app)
                self.updateStatusGlyph()
            }

        let muteSubscription = app.$isMuted
            .dropFirst()
            .removeDuplicates()
            .sink { [weak self, weak app] isMuted in
                guard let self, let app else { return }
                self.store.saveLevel(
                    VolumeStore.Level(volume: app.volume, isMuted: isMuted),
                    forApp: app.id
                )
                self.applyToAudioEngine(app)
                self.updateStatusGlyph()
            }

        subscriptions[app.id] = [volumeSubscription, muteSubscription]
    }

    /// Hands the level to the audio engine. A no-op until the per-app driver is
    /// integrated — see AUDIO_INTEGRATION.md.
    private func applyToAudioEngine(_ app: AudioApp) {
        #if DEBUG
        print("[Capsule] \(app.name) → \(app.percent)%\(app.isMuted ? " (muted)" : "")")
        #endif
    }

    // MARK: - Volume & mute

    func setVolume(_ value: Double, for app: AudioApp) {
        app.volume = AudioApp.clamp(value)
        if app.volume > 0.001 { app.isMuted = false }
    }

    /// ±5% steps, used by ⌥↑ / ⌥↓.
    func nudgeVolume(_ delta: Double, for app: AudioApp) {
        let base = app.isMuted ? 0 : app.volume
        if delta > 0 { app.isMuted = false }
        setVolume(base + delta, for: app)
    }

    func setMuted(_ muted: Bool, for app: AudioApp) {
        guard app.isMuted != muted else { return }
        app.isMuted = muted

        // A manual mute change invalidates the solo's undo memory for this app.
        silencedBySolo.remove(app.id)
        // Manually unmuting cancels a scheduled unmute.
        if !muted { muteExpiries.removeValue(forKey: app.id) }
        if soloedAppID == app.id { soloedAppID = nil }

        updateStatusGlyph()
    }

    func toggleMute(_ app: AudioApp) {
        setMuted(!app.isMuted, for: app)
    }

    func muteAll() {
        clearSolo()
        muteExpiries.removeAll()
        stopExpiryTimer()
        apps.forEach { $0.isMuted = true }
        updateStatusGlyph()
    }

    func unmuteAll() {
        clearSolo()
        muteExpiries.removeAll()
        stopExpiryTimer()
        apps.forEach { $0.isMuted = false }
        updateStatusGlyph()
    }

    // MARK: - Timed mutes

    /// Mutes an app and schedules it to come back after `minutes`.
    func mute(_ app: AudioApp, forMinutes minutes: Double) {
        setMuted(true, for: app)
        muteExpiries[app.id] = Date().addingTimeInterval(minutes * 60)
        startExpiryTimerIfNeeded()
    }

    func cancelTimedMute(_ app: AudioApp) {
        muteExpiries.removeValue(forKey: app.id)
        if muteExpiries.isEmpty { stopExpiryTimer() }
    }

    func hasTimedMute(_ app: AudioApp) -> Bool {
        muteExpiries[app.id] != nil
    }

    func remainingSeconds(_ app: AudioApp) -> Int? {
        guard let expiry = muteExpiries[app.id] else { return nil }
        return max(0, Int(expiry.timeIntervalSinceNow.rounded(.up)))
    }

    /// "4:59" style countdown, or nil when the app has no timed mute.
    /// Reads `countdownTick` so it re-evaluates once a second.
    func countdownText(_ app: AudioApp) -> String? {
        _ = countdownTick
        guard let remaining = remainingSeconds(app) else { return nil }
        return String(format: "%d:%02d", remaining / 60, remaining % 60)
    }

    private func startExpiryTimerIfNeeded() {
        guard expiryTimer == nil else { return }
        expiryTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.tickExpiries()
        }
    }

    private func stopExpiryTimer() {
        expiryTimer?.invalidate()
        expiryTimer = nil
    }

    private func tickExpiries() {
        // Snapshot first: mutating the dictionary while iterating it would trap
        // on exclusivity.
        let due = muteExpiries.filter { $0.value <= Date() }.map { $0.key }
        for id in due {
            muteExpiries.removeValue(forKey: id)
            if let app = apps.first(where: { $0.id == id }) {
                setMuted(false, for: app)
            }
        }
        if muteExpiries.isEmpty {
            stopExpiryTimer()
        } else {
            countdownTick &+= 1
        }
    }

    // MARK: - Global shortcuts

    /// (Re)binds the system-wide hot keys to the current actions.
    func syncGlobalShortcuts() {
        guard globalShortcutsEnabled else {
            GlobalHotKeyCenter.shared.uninstall()
            return
        }

        GlobalHotKeyCenter.shared.install([
            .muteSelected: { [weak self] in self?.toggleMuteFromHotKey() },
            .soloSelected: { [weak self] in self?.toggleSoloFromHotKey() },
            .unmuteAll: { [weak self] in self?.unmuteAll() },
            .showMixer: { [weak self] in
                MixerPresenter.shared.showMixer(focusing: self?.focusedApp)
            }
        ])
    }

    // MARK: - Solo ("mute all but this")

    /// Mutes every other app and remembers exactly which ones, so the same
    /// action restores the previous mix instead of blanket-unmuting.
    func muteAllExcept(_ app: AudioApp) {
        if soloedAppID != nil { restoreSoloedApps() }

        var silenced: Set<AudioApp.ID> = []
        for other in apps where other.id != app.id {
            if !other.isMuted {
                other.isMuted = true
                silenced.insert(other.id)
            }
        }

        silencedBySolo = silenced
        soloedAppID = app.id
        app.isMuted = false
        updateStatusGlyph()
    }

    /// Undoes the current solo without touching anything else.
    func restoreSoloedApps() {
        for app in apps where silencedBySolo.contains(app.id) {
            app.isMuted = false
        }
        clearSolo()
    }

    func clearSolo() {
        silencedBySolo.removeAll()
        soloedAppID = nil
        updateStatusGlyph()
    }

    /// ⌥⌘M: solo this app, or restore the mix when it is already soloed.
    func toggleSolo(_ app: AudioApp) {
        if soloedAppID == app.id {
            restoreSoloedApps()
        } else {
            muteAllExcept(app)
        }
    }

    // MARK: - Keyboard-shortcut targets

    func toggleMuteFocused() {
        guard let app = shortcutTarget else { return }
        toggleMute(app)
    }

    func toggleSoloFocused() {
        guard let app = shortcutTarget else { return }
        toggleSolo(app)
    }

    func nudgeFocused(_ delta: Double) {
        guard let app = shortcutTarget else { return }
        nudgeVolume(delta, for: app)
    }

    /// Explicitly focused app, else the only app in the list.
    var shortcutTarget: AudioApp? {
        if let focusedApp { return focusedApp }
        return visibleApps.count == 1 ? visibleApps.first : nil
    }

    /// Target for the system-wide hotkeys. Falls back to the loudest app that is
    /// currently playing, so a global "shut that up" chord does something
    /// sensible even when no row is selected.
    var hotKeyTarget: AudioApp? {
        if let shortcutTarget { return shortcutTarget }
        return apps
            .filter { $0.isPlaying && !$0.isMuted }
            .max { $0.level < $1.level }
    }

    func toggleMuteFromHotKey() {
        guard let app = hotKeyTarget else { return }
        toggleMute(app)
    }

    func toggleSoloFromHotKey() {
        guard let app = hotKeyTarget, apps.count > 1 else { return }
        toggleSolo(app)
    }

    // MARK: - Focus

    /// Selects an app so the shortcuts act on it and asks every visible list to
    /// scroll to it.
    func requestFocus(_ id: AudioApp.ID) {
        focusedAppID = id
        focusToken &+= 1
    }

    func requestFocus(_ app: AudioApp) {
        requestFocus(app.id)
    }

    /// Re-issues the current focus request. Used after a mixer surface appears,
    /// so a scroll view that did not exist yet still lands on the right row.
    func replayFocus() {
        focusToken &+= 1
    }

    // MARK: - Visibility

    func isHidden(_ app: AudioApp) -> Bool { hiddenAppIDs.contains(app.id) }

    func toggleHidden(_ app: AudioApp) {
        if hiddenAppIDs.contains(app.id) {
            hiddenAppIDs.remove(app.id)
        } else {
            hiddenAppIDs.insert(app.id)
            if focusedAppID == app.id { focusedAppID = nil }
        }
        store.saveHiddenAppIDs(hiddenAppIDs)
    }

    func revealAllHiddenApps() {
        hiddenAppIDs.removeAll()
        store.saveHiddenAppIDs(hiddenAppIDs)
    }

    /// Brings the app's own windows forward — the other half of "focus this
    /// app".
    @discardableResult
    func activate(_ app: AudioApp) -> Bool {
        guard app.processIdentifier != 0,
              let running = NSRunningApplication(processIdentifier: app.processIdentifier)
        else { return false }
        return running.activate(options: [.activateIgnoringOtherApps])
    }

    // MARK: - Output device

    func refreshDevices() {
        devices = AudioDeviceService.outputDevices()
        defaultDeviceID = AudioDeviceService.defaultOutputDeviceID()

        if let defaultDeviceID {
            masterVolume = AudioDeviceService.volume(of: defaultDeviceID)
            masterMuted = AudioDeviceService.isMuted(defaultDeviceID)
            if let name = devices.first(where: { $0.id == defaultDeviceID })?.name {
                store.lastOutputDeviceName = name
            }
        } else {
            masterVolume = nil
            masterMuted = false
        }
    }

    func selectDevice(_ device: AudioDevice) {
        guard AudioDeviceService.setDefaultOutputDevice(device.id) else { return }
        refreshDevices()
    }

    func setMasterVolume(_ value: Double) {
        guard let defaultDeviceID else { return }
        if AudioDeviceService.setVolume(value, on: defaultDeviceID) {
            masterVolume = min(max(value, 0), 1)
            if value > 0.001 { masterMuted = false }
        }
    }

    func toggleMasterMute() {
        guard let defaultDeviceID else { return }
        let next = !masterMuted
        if AudioDeviceService.setMuted(next, on: defaultDeviceID) {
            masterMuted = next
        }
    }

    // MARK: - Menu bar icon

    private func updateStatusGlyph() {
        let glyph: String
        if masterMuted || everythingMuted {
            glyph = "speaker.slash.fill"
        } else if isSoloActive {
            glyph = "person.wave.2.fill"
        } else {
            glyph = "speaker.wave.2.fill"
        }
        if glyph != statusGlyph { statusGlyph = glyph }
    }

    // MARK: - Demo levels

    /// Simulated playback activity. Deterministic per app so rows do not flicker
    /// between "Playing" and "Idle" on every tick the way the old
    /// `Bool.random()` version did.
    private func updateDemoLevels() {
        demoTick += 1

        for (index, app) in apps.enumerated() {
            guard !app.isSilenced else {
                if app.level != 0 { app.level = 0 }
                if app.isPlaying { app.isPlaying = false }
                continue
            }

            let seed = Double((abs(app.id.hashValue) + index * 17) % 100) / 100
            // Only some apps are "playing" at any moment, and which ones is
            // stable for the whole run.
            guard seed > 0.45 else {
                if app.level != 0 { app.level = 0 }
                if app.isPlaying { app.isPlaying = false }
                continue
            }

            let phase = Double(demoTick) * 0.5 + seed * 6.283
            let level = min(max(0.25 + 0.5 * seed + 0.25 * sin(phase) * app.volume, 0), 1)
            app.level = level
            app.isPlaying = level > 0.15
        }
    }

    private func clearDemoLevels() {
        for app in apps {
            app.level = 0
            app.isPlaying = false
        }
    }
}
