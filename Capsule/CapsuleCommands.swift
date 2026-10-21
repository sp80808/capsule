//
//  CapsuleCommands.swift
//  Capsule
//
//  Main-menu commands. These are the working half of the shortcuts: the copies
//  inside the app context menu display the hint, these respond to the key press
//  while Capsule is active.
//

import SwiftUI

struct CapsuleCommands: Commands {

    @ObservedObject private var manager: AudioManager

    init(manager: AudioManager) {
        self.manager = manager
    }

    private var focusedName: String { manager.shortcutTarget?.name ?? "App" }

    var body: some Commands {
        // A menu bar utility has nothing to create.
        CommandGroup(replacing: .newItem) {}

        CommandMenu("Mixer") {
            Button {
                manager.toggleMuteFocused()
            } label: {
                Text(manager.shortcutTarget?.isMuted == true ? "Unmute \(focusedName)" : "Mute \(focusedName)")
            }
            .keyboardShortcut("m", modifiers: .command)
            .disabled(manager.shortcutTarget == nil)

            Button {
                manager.toggleSoloFocused()
            } label: {
                Text(manager.soloedAppID == manager.shortcutTarget?.id ? "Restore Other Apps" : "Mute All Others")
            }
            .keyboardShortcut("m", modifiers: [.command, .option])
            .disabled(manager.shortcutTarget == nil || manager.apps.count < 2)

            Divider()

            Button("Unmute All Apps") {
                manager.unmuteAll()
            }
            .keyboardShortcut("m", modifiers: [.command, .shift])

            Button("Mute All Apps") {
                manager.muteAll()
            }
            .keyboardShortcut("m", modifiers: [.command, .control])

            Divider()

            Button("Increase Volume") {
                manager.nudgeFocused(0.05)
            }
            .keyboardShortcut(.upArrow, modifiers: .option)
            .disabled(manager.shortcutTarget == nil)

            Button("Decrease Volume") {
                manager.nudgeFocused(-0.05)
            }
            .keyboardShortcut(.downArrow, modifiers: .option)
            .disabled(manager.shortcutTarget == nil)

            Divider()

            Button("Show Menu Bar Mixer") {
                MixerPresenter.shared.showMixer(focusing: manager.focusedApp)
            }
            .keyboardShortcut("o", modifiers: [.command, .shift])

            Button("Open Capsule Window") {
                MixerPresenter.shared.showMixerWindow(focusing: manager.focusedApp)
            }
            .keyboardShortcut("w", modifiers: [.command, .shift, .option])
        }
    }
}
