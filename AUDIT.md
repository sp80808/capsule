# Capsule Audit & Roadmap

Audit performed 2026-10-18 against `4ce661e` on branch `arena/e0c40db0-capsule`.

Everything in **Fixed** below is already applied in this branch (last updated
2026-10-19: global hotkeys, timed mutes, reduce-motion support). Everything in
**Open** and **Roadmap** is a proposal.

---

## 1. How this was verified

There is no Swift toolchain or macOS SDK on the machine this was written on, so
`xcodebuild` could not be run. Three checks that *do* run here were added and
are wired into CI:

| Check | What it proves | Run it |
| --- | --- | --- |
| `Scripts/swift_syntax_check.py` | Every `.swift` file parses (tree-sitter Swift grammar); catches unbalanced braces, malformed declarations, stray tokens | `python3 Scripts/swift_syntax_check.py` |
| `Scripts/swift_cross_reference.py` | Every member access on a Capsule type resolves to a member that type actually declares; catches renamed methods, missing properties, typos at call sites | `python3 Scripts/swift_cross_reference.py` |
| `Scripts/check_xcodeproj.py` | Every Swift file on disk is registered in the Sources build phase and every file reference resolves | `python3 Scripts/check_xcodeproj.py` |

```bash
python3 -m venv .venv && .venv/bin/pip install tree-sitter tree-sitter-swift
.venv/bin/python Scripts/swift_syntax_check.py       # 14/14 files parsed cleanly
.venv/bin/python Scripts/swift_cross_reference.py    # every member access resolves
.venv/bin/python Scripts/check_xcodeproj.py          # 14 Swift files registered
```

The cross-reference check is not a type checker — it was validated by renaming
`AudioManager.replayFocus()` and confirming the check failed at the call site in
`MixerPresenter.swift`. **The remaining risk is type-level**: overload
resolution, generic inference and framework API availability have not been
compiled. Run `xcodebuild -project Capsule.xcodeproj -target Capsule build` on a
Mac before shipping.

---

## 2. What was added in this branch

### Menu bar mixer

Capsule was a plain `WindowGroup` app with no menu bar presence, despite being
described everywhere as a menu bar mixer. It now has:

- `StatusBarController` — an `NSStatusItem` whose icon reflects mute/solo state.
  Left-click toggles a popover mixer, right-click (or control-click) opens a
  utility menu: show mixer, open window, mute/unmute the focused app, mute all
  others, unmute all, output-device submenu, Settings, Quit.
- `MixerView` — one view, two homes: a fixed 360×540 popover (`compact: true`)
  and a resizable detached window via `ContentView`.
- `MixerPresenter` — the SwiftUI→AppKit bridge so a view can ask for "show the
  mixer on this app" without knowing about `NSPopover`.
- Activation policy `.accessory`, so Capsule lives in the menu bar instead of
  the Dock.

### Right-click context menu (the request)

Every app card — and its slider, so a right-click anywhere on the card behaves
the same — has a context menu (`AppContextMenu` in `AppRowView.swift`):

| Item | Shortcut | Behaviour |
| --- | --- | --- |
| Show in Menu Bar Mixer | ⇧⌘O | Opens the popover, scrolls to that row, draws the selection ring and flashes it |
| Open in Capsule Window | — | Same, in the detached window |
| Mute / Unmute *App* | ⌘M | Toggles that app |
| Mute All Others | ⌥⌘M | Solos the app; becomes "Restore Other Apps" while active, and restores exactly the apps it silenced |
| Unmute All Apps | ⇧⌘M | Clears solo too |
| Set Volume ▸ 0…100% | — | Presets |
| Activate *App* | — | Brings that app's own windows forward |
| Hide from Capsule / Show in Capsule | — | Persisted |
| Copy Name | — | Pasteboard |

"Focusing on that specific window" is implemented as: select the row → the
keyboard shortcuts now act on it, the ring highlights it, and the list scrolls
to it. The focus request is sent twice (`AudioManager.requestFocus` then
`replayFocus` on the next run loop tick) so a popover whose scroll view did not
exist a moment ago still lands on the right row.

### Global hotkeys (opt-in)

`GlobalHotKeys.swift` registers system-wide chords through the Carbon
`RegisterEventHotKey` API, so the mixer can be driven from any app instead of
only while Capsule is frontmost. Off by default — grabbing chords everywhere
should be a choice — and toggled in Settings → Global shortcuts:

| Chord | Action |
| --- | --- |
| ⌃⌥⌘M | Mute / unmute the selected app |
| ⌃⌥⌘⇧M | Mute all other apps (solo) / restore |
| ⌃⌥⌘U | Unmute all apps |
| ⌃⌥⌘C | Show the menu bar mixer |

⌃⌥⌘ was chosen deliberately: ⌘M is "minimise" in almost every app, and ⌃⌥ is
the VoiceOver modifier prefix, so a plain ⌘M/⌃⌘M binding would break other
software.

### Timed mutes

"Mute for ▸ 5 / 15 / 30 / 60 minutes" in the app context menu silences an app
and schedules its return. The row counts down ("Muted · 4:59 left") and the app
unmutes itself; muting or unmuting by hand, or Mute All / Unmute All, cancels
the timer. Only one 1-second timer runs, and only while a countdown is active.

### Working shortcuts

Context-menu items on macOS only *display* a shortcut, so the same actions are
also real menu commands in `CapsuleCommands.swift` (a "Mixer" menu): ⌘M, ⌥⌘M,
⇧⌘M, ⌃⌘M, ⌥↑/⌥↓ (±5%), ⇧⌘O, ⌥⇧⌘W. They act on the selected app, or on the
only app in the list when nothing is selected. `CommandGroup(replacing:
.newItem)` removes "New Window", which has no meaning here.

### Real functionality that did not exist

- **Output device switching** — a picker in the mixer header and status menu,
  backed by `AudioDeviceService.setDefaultOutputDevice`.
- **Master volume + mute** for the current output device, with per-channel
  fallback and a "Hardware" label when the device exposes no software volume.
- **Persistence** (`VolumeStore`) — per-app volume and mute, hidden apps, demo
  mode, last device, all in `UserDefaults`.
- **Real app list** — `NSWorkspace.runningApplications` with real icons and
  names, live on launch/terminate notifications, instead of six hardcoded
  sample apps.
- **Filter field** (appears above 5 apps), empty states, level meters, one-click
  mute button per row, app-count/muted/solo footer.
- **Accessibility** — labelled sliders with `accessibilityValue`,
  `accessibilityAdjustableAction` (±5%) and a named Mute/Unmute action.
- **Settings window** — demo mode, output device, hidden apps, shortcut
  reference.

---

## 3. Bugs found and fixed

| # | Where | Problem | Fix |
| --- | --- | --- | --- |
| 1 | `AudioManager.AudioApp` | `let id = UUID()` — a new identity on every refresh, so SwiftUI threw away row state (selection, focus, scroll position) and per-app persistence was impossible | Stable id: bundle identifier, falling back to `pid-<pid>` |
| 2 | `refreshAudioApps()` | Rebuilt the whole list from hardcoded samples, silently discarding every user setting | `apply(_:)` reuses existing `AudioApp` instances and merges saved levels |
| 3 | everywhere | Nothing was persisted; relaunching reset the mix | `VolumeStore` + Combine bridge on `$volume`/`$isMuted` |
| 4 | `setAppVolume` | Dead code — the slider never called it, so the UI was write-only to memory | All mutations go through `AudioManager`, which persists and calls `applyToAudioEngine(_:)`, the single seam for the driver |
| 5 | `AudioApp.isMuted` | Had no effect on anything except the slider glyph | `effectiveVolume`/`isSilenced`; rows show "Muted", mute-all/solo/status icon all respect it |
| 6 | `updateAudioApps()` | `app.isPlaying = Bool.random()` every 2s — the UI flickered randomly and the model mutated forever even with no window open | Deterministic per-app demo levels behind an explicit, labelled Demo Mode flag; the timer only drives levels when demo mode is on |
| 7 | `AppDelegate` | `applicationShouldTerminateAfterLastWindowClosed → true` — closing the only window quit the app, impossible for a menu bar utility | Returns `false`; app runs `.accessory` |
| 8 | `AudioManager` | Cleanup lived in `deinit`, which never runs for a `static let` singleton | `initialize()` / `shutdown()` wired to the app lifecycle |
| 9 | `ContentView` | `@StateObject private var audioManager = AudioManager.shared` — `@StateObject` claims ownership of a shared singleton | Injected `@ObservedObject` |
| 10 | `updateAudioApps()` | `DispatchQueue.main.async` inside a main-run-loop timer callback | Removed |
| 11 | `getAudioDevices()` | Dead code, ignored every error, and would have listed input-only devices | `AudioDeviceService`: error-checked, liveness + output-stream filtering, sorted, default marked |
| 12 | `Info.plist` | `NSSupportsAutomaticTermination` / `NSSupportsSuddenTermination` = `true` — macOS may silently reap a menu bar utility | Both `false` |
| 13 | `Capsule.entitlements` | `com.apple.security.device.audio-input` is not a real entitlement key (the mic one is `com.apple.security.audio-input`, already present) | Removed |
| 14 | repo | No CI, no automated check of any kind | Three scripts + `.github/workflows/ci.yml` (Linux checks + macOS build) |
| 15 | all views | `Color.white.opacity(…)` card/track fills — invisible in Light Mode | `CapsuleTheme` with appearance-adaptive colours, handle/glyph inverted against the material |
| 16 | `PillSlider` | The spring animation fought the pointer while dragging | Animation suppressed during drag; ⌥ = 1% steps, ⇧ = 10% steps |
| 17 | `PillSlider`, rows | No accessibility labels or values | Labels, values, adjustable action, named mute action |
| 18 | previews | `PreviewProvider` (deprecated since Xcode 15) | `#Preview` + a shared `CapsulePreview.makeManager()` |
| 19 | `VolumeStore` | Computed-property setters on a struct are `mutating`, which would not compile against a `let` store | `nonmutating set` (they only touch `UserDefaults`) |

---

## 4. Open issues (deliberately not "fixed")

1. **Per-app audio still does not exist.** Levels are simulated and gain is not
   applied. This is a driver problem, not a UI problem. On macOS 14.4+ the
   public `AudioHardwareCreateProcessTap` API can capture and attenuate a
   single process without a kernel/HAL extension; below that you need a HAL
   plug-in (the eqMac route). `AudioManager.applyToAudioEngine(_:)` is where it
   plugs in, and `Demo Mode` in Settings is the visible admission that it is not
   wired up yet.
2. **App Sandbox is on.** Reading and setting device volume/mute works
   sandboxed. Installing a HAL plug-in cannot be done from inside the sandbox —
   it needs a privileged helper, or the process-tap route above.
3. **`NSMicrophoneUsageDescription` is unused** until capture lands; kept so the
   first capture build does not crash on the prompt.
4. **No unit tests.** There is no test target in the project. The mute/solo/
   persistence logic is now isolated in `AudioManager` + `VolumeStore` (no view
   types), so a target is mechanical to add — see Roadmap E1.
5. **All copy is hardcoded English.** No `String(localized:)`, no `.xcstrings`.
6. **Refresh churn.** Every `NSWorkspace` launch/terminate notification triggers
   a full re-enumeration. Cheap today, worth debouncing if it ever shows.

---

## 5. Roadmap / brainstorm

### A. Audio engine (what turns the mockup into a product)

- **A1. Process taps (macOS 14.4+).** `CATapDescription` +
  `AudioHardwareCreateProcessTap` + an `AUVolume`/gain node per process. Real
  levels, real mute, no driver install, sandbox-friendly. Then delete Demo Mode.
- **A2. HAL plug-in fallback (macOS 13–14.3).** Ship the eqMac-style driver as a
  separate signed package; Capsule talks to it over XPC. Gate the UI on
  "driver installed" with a one-click installer flow.
- **A3. Per-app output routing.** Aggregate devices so Zoom goes to headphones
  while Music stays on speakers.
- **A4. Ducking rules.** "When *Call* is speaking, lower *Music* by 60%" — the
  feature that beats a plain per-app slider, and the natural home for the
  solo/mute primitives added here.
- **A5. Level-driven auto-behaviour.** Auto-show an app the moment it makes
  sound; auto-hide after N minutes of silence; "meeting mode" presets.
- **A6. Per-device master memory.** Remember and restore master volume per
  output device on switch.
- **A7. Boost above 100%** per app (needs A1/A2), with a visible headroom meter.

### B. Mixer UX

- **B1. ~~Global hotkeys.~~ Done** (Carbon `RegisterEventHotKey`, opt-in in
  Settings). Remaining work: make the chords user-configurable with a key
  recorder, and surface conflicts when registration fails.
- **B2. Per-tab control.** The "mute that tab" wording points here: per-app rows
  are as fine-grained as Core Audio gets, but a Safari/Chrome extension + Native
  Messaging host can enumerate tabs and expose each one as a row. The context
  menu, solo and shortcut machinery in this branch works unchanged on those
  rows — only `AudioApp.id` becomes a tab id.
- **B3. ~~Temporary mutes.~~ Mostly done** — "Mute for 5/15/30/60 minutes" with
  a live countdown. Remaining: "mute until I next unmute", per-app defaults, and
  a countdown ring rather than text.
- **B4. Pin & reorder.** Drag rows to pin; pinned apps survive scrolling and
  show in a compact top section.
- **B5. App groups.** "Browsers", "Calls", "Games" with a group fader that
  scales its members proportionally.
- **B6. Snapshots/profiles.** Name and recall mixes ("Meeting", "Focus",
  "Late night"); import/export as JSON.
- **B7. Mini mode.** A one-row popover: focused app + master, for people who
  only ever touch two sliders.
- **B8. Peak-hold master meter** and a per-row sparkline of recent levels
  ("what was making noise at 3pm").
- **B9. Full keyboard traversal.** ↑/↓ between rows, ←/→ to adjust, space to
  mute, ⌘F to filter — no mouse required.
- **B10. First-run tour** that explains the driver situation instead of
  silently showing simulated data.

### C. System integration

- **C1. Dock tile / Services menu** entries for mute-all and show-mixer.
- **C2. Launch at login** via `SMAppService.mainApp`.
- **C3. Menu bar level meter** — replace the static glyph with a live 3-bar
  meter when something is playing.
- **C4. `capsule` CLI** (`capsule mute Safari`, `capsule solo Zoom`) for
  scripting, plus a Spotlight/Shortcuts action set.
- **C5. Focus-mode awareness** — auto-mute everything when a macOS Focus turns
  on.
- **C6. Device auto-switch rules** — plug in headphones: move music, leave calls
  on the built-in speaker.

### D. UI polish

- **D1. Appearance-adaptive material** — the HUD material is always dark; offer
  `.popover`/`.sidebar` to match the system appearance.
- **D2. App accent colours** derived from the app icon instead of one gradient
  for every fallback row.
- **D3. ~~Motion off-switch.~~ Done** — the slider spring and the row flash
  honour `accessibilityReduceMotion`.
- **D4. Wider popover option** (Settings) for long app names.
- **D5. Localisation** — `String(localized:)` everywhere, `.xcstrings` catalog,
  and localised shortcut hints.

### E. Engineering

- **E1. Unit test target** for `AudioManager` (solo/restore semantics, mute
  bookkeeping, focus fallback) and `VolumeStore` (round-trip, migration). The
  logic is already view-free.
- **E2. `LevelSource` protocol** so demo data, process taps and the HAL driver
  are interchangeable behind one interface.
- **E3. SwiftLint/SwiftFormat** in CI.
- **E4. Snapshot tests** for `PillSlider` in both appearances.
- **E5. Crash-free telemetry-free logging** via `os.Logger` subsystem categories
  instead of `print`.
