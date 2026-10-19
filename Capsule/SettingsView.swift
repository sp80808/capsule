//
//  SettingsView.swift
//  Capsule
//
//  Settings window: demo data, output device, hidden apps and a shortcut
//  reference.
//

import SwiftUI

struct SettingsView: View {

    @ObservedObject var manager: AudioManager

    var body: some View {
        Form {
            Section("Playback") {
                Toggle(isOn: $manager.demoMode) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Demo Mode")
                        Text("Simulates playback levels and meters. Per-app capture needs the Capsule audio driver; until then every row would otherwise sit at “Idle”.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Section("Output device") {
                if manager.devices.isEmpty {
                    Text("No output device found.")
                        .font(.callout)
                        .foregroundColor(.secondary)
                } else {
                    Picker("Output", selection: deviceSelection) {
                        ForEach(manager.devices) { device in
                            Text(device.name).tag(device.id)
                        }
                    }
                    .labelsHidden()
                }

                Toggle(isOn: $manager.rememberDeviceVolumes) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Remember volume per device")
                        Text("Restores each output device's last master volume when you switch back to it.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Button("Rescan devices") {
                    manager.refreshDevices()
                }
            }

            Section("Hidden apps") {
                if manager.hiddenApps.isEmpty {
                    Text("Every app Capsule can see is listed in the mixer.")
                        .font(.callout)
                        .foregroundColor(.secondary)
                } else {
                    ForEach(manager.hiddenApps) { app in
                        HStack {
                            Text(app.name)
                            Spacer()
                            Button("Show") {
                                manager.toggleHidden(app)
                            }
                        }
                    }
                }
            }

            Section("Keyboard shortcuts") {
                shortcutRow("Mute / unmute the selected app", "⌘M")
                shortcutRow("Mute all other apps (solo)", "⌥⌘M")
                shortcutRow("Unmute all apps", "⇧⌘M")
                shortcutRow("Mute all apps", "⌃⌘M")
                shortcutRow("Volume up / down 5%", "⌥↑  ⌥↓")
                shortcutRow("Show the menu bar mixer", "⇧⌘O")
                shortcutRow("Open the Capsule window", "⌥⇧⌘W")

                Text("Right-click any app in the mixer for the same actions, plus “Show in Menu Bar Mixer”, which scrolls the mixer to that app.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section("Global shortcuts") {
                Toggle(isOn: $manager.globalShortcutsEnabled) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Enable system-wide shortcuts")
                        Text("Work from any app, not just while Capsule is frontmost. They are opt-in because they reserve these chords everywhere.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                ForEach(HotKeyAction.allCases) { action in
                    shortcutRow(action.title, action.display, enabled: manager.globalShortcutsEnabled)
                }

                Text("Chords use ⌃⌥⌘ on purpose: ⌘M is “minimise” in most apps and ⌃⌥ is the VoiceOver prefix. They act on the app selected in the mixer, or on the loudest app that is playing when nothing is selected.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section("Saved mixes") {
                Text("Use the stack icon in the mixer header to save the current mix and recall it later. Saving again with the same name replaces it.")
                    .font(.callout)
                    .foregroundColor(.secondary)
            }

            Section("Timed mutes") {
                Text("Right-click an app and choose “Mute for” to silence it for 5, 15, 30 or 60 minutes. The row counts down and the app unmutes itself; muting or unmuting by hand cancels the timer.")
                    .font(.callout)
                    .foregroundColor(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 480, height: 640)
    }

    private var deviceSelection: Binding<AudioDeviceID> {
        Binding(
            get: { manager.defaultDeviceID ?? 0 },
            set: { deviceID in
                guard let device = manager.devices.first(where: { $0.id == deviceID }) else { return }
                manager.selectDevice(device)
            }
        )
    }

    private func shortcutRow(_ description: String, _ keys: String, enabled: Bool = true) -> some View {
        HStack {
            Text(description)
                .font(.callout)
            Spacer()
            Text(keys)
                .font(.system(.callout, design: .rounded))
                .foregroundColor(enabled ? .secondary : Color.secondary.opacity(0.4))
        }
        .opacity(enabled ? 1 : 0.55)
    }
}

#Preview("Settings") {
    SettingsView(manager: CapsulePreview.makeManager())
}
