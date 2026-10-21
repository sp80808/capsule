# Capsule 🎛️

A native macOS audio mixer that lives in your menu bar, with per-app volume
control and a Control Center-inspired design.

![macOS](https://img.shields.io/badge/macOS-13.0+-blue.svg)
![Swift](https://img.shields.io/badge/Swift-5.0-orange.svg)
![SwiftUI](https://img.shields.io/badge/SwiftUI-Native-green.svg)

## Features

- 🎛️ **Menu bar mixer**: click the status item for a popover mixer, or open a
  resizable window
- 🖱️ **Right-click any app** for mute, solo, volume presets and "show me this
  app in the mixer"
- ⌨️ **Keyboard shortcuts** that work while Capsule is frontmost (⌘M, ⌥⌘M, ⇧⌘M,
  ⌥↑/⌥↓), plus **opt-in system-wide hotkeys** (⌃⌥⌘M) that work from any app
- 🔇 **Solo / "mute all others"** that remembers what it silenced and restores it
- ⏱️ **Timed mutes**: mute an app for 5/15/30/60 minutes and it comes back on its
  own, with a countdown on the row
- 🎚️ **Output device switching** and **master volume + mute**, straight from
  Core Audio
- 🎨 **Native macOS design**: pill sliders, frosted glass, adaptive colours
- 💾 **Remembers your mix** across relaunches, per output device
- 🗂️ **Saved mixes**: snapshot the whole mixer under a name and recall it later
- ♿ **VoiceOver friendly**: labelled sliders with adjustable actions

> **Demo Mode.** Per-app *capture* needs an audio driver (see
> [AUDIO_INTEGRATION.md](AUDIO_INTEGRATION.md)), which is not wired up yet.
> Until then, playback meters are simulated and the mixer is labelled `DEMO`.
> Device switching, master volume, mute/solo state and persistence are real.
> Turn it off in Settings to see the honest state.

## Usage

- **Show the mixer**: click the Capsule icon in the menu bar
- **Adjust volume**: drag a pill slider (hold ⌥ for 1% steps, ⇧ for 10%)
- **Mute**: click the speaker button on a row, or double-click a slider
- **Right-click an app** for everything else:

  | Item | Shortcut |
  | --- | --- |
  | Show in Menu Bar Mixer | ⇧⌘O |
  | Mute / Unmute *App* | ⌘M |
  | Mute All Others (solo) / Restore Other Apps | ⌥⌘M |
  | Unmute All Apps | ⇧⌘M |
  | Mute All Apps | ⌃⌘M |
  | Volume ±5% | ⌥↑ / ⌥↓ |

  "Show in Menu Bar Mixer" opens the popover, scrolls to that app, highlights it
  and makes it the target of the shortcuts above. The menu also offers
  **Mute for ▸ 5/15/30/60 minutes**, which counts down on the row and unmutes
  itself.
- **Status item right-click**: mute/unmute, mute all others, unmute all, output
  device, Settings, Quit
- **System-wide hotkeys** (Settings → Global shortcuts, off by default): ⌃⌥⌘M
  mute the selected app, ⌃⌥⌘⇧M solo, ⌃⌥⌘U unmute all, ⌃⌥⌘C show the mixer.
  They use ⌃⌥⌘ because ⌘M is "minimise" everywhere and ⌃⌥ is the VoiceOver
  prefix.

## Design

- **Thick pill sliders** with a spring that steps out of the way while dragging
- **Frosted glass** via `NSVisualEffectView`
- **Adaptive colours** — the UI reads correctly in Light and Dark Mode
- **Level meters** beside each app's status

## Requirements

- macOS 13.0 (Ventura) or later
- Xcode 15.0 or later

## Building

```bash
git clone https://github.com/sp80808/capsule.git
cd capsule
open Capsule.xcodeproj      # then ⌘R
```

or from the command line:

```bash
xcodebuild -project Capsule.xcodeproj -target Capsule -configuration Debug build
```

## Architecture

| File | Responsibility |
| --- | --- |
| `CapsuleApp.swift` | App entry, `Settings` scene, app delegate, activation policy |
| `StatusBarController.swift` | `NSStatusItem`, mixer popover, detached window, status menu |
| `MixerPresenter.swift` | SwiftUI → AppKit bridge ("show the mixer on this app") |
| `AudioManager.swift` | Single source of truth: apps, levels, mute/solo, focus, devices |
| `AudioApp.swift` | Per-app model with stable identity + icon fallbacks |
| `AudioDeviceService.swift` | Core Audio device enumeration, master volume/mute |
| `VolumeStore.swift` | `UserDefaults` persistence |
| `MixSnapshot.swift` | Saved mixes and per-device master volume memory |
| `MixerView.swift` | The mixer (popover and window share it) |
| `AppRowView.swift` | App card, level meter and the right-click context menu |
| `PillSlider.swift` | Custom slider with accessibility support |
| `CapsuleCommands.swift` | Main-menu commands / keyboard shortcuts |
| `GlobalHotKeys.swift` | System-wide hotkeys (Carbon) |
| `SettingsView.swift` | Settings window |
| `Theme.swift` | Shared colours, metrics, `VisualEffectBlur` |

Views never mutate an `AudioApp` directly — they call `AudioManager`, which
applies the change, persists it and hands it to `applyToAudioEngine(_:)`, the
single seam where the audio driver plugs in.

## Development checks

Three checks run on Linux and in CI (see `.github/workflows/ci.yml`):

```bash
python3 -m venv .venv && .venv/bin/pip install tree-sitter tree-sitter-swift

.venv/bin/python Scripts/swift_syntax_check.py     # every file parses
.venv/bin/python Scripts/swift_cross_reference.py  # member accesses resolve
.venv/bin/python Scripts/check_xcodeproj.py        # new files are registered
```

On a Mac, the real check is:

```bash
xcodebuild -project Capsule.xcodeproj -scheme Capsule test
```

`CapsuleTests` covers the mute/solo/timed-mute/snapshot logic. CI runs both the
scripts and that command (build + test on a `macos-14` runner) on every push and
pull request; a failing build posts its compiler errors back to the PR. See
[AUDIT.md](AUDIT.md) for what each check does and does not prove.

## Roadmap

[AUDIT.md](AUDIT.md) contains the current audit, the list of bugs that were
fixed, and a phased roadmap (process taps, global hotkeys, per-tab control via a
browser extension, ducking rules, profiles, tests).

## License

MIT License - feel free to use this project as you wish!

## Credits

Inspired by macOS Control Center design and the eqMac audio driver project.
