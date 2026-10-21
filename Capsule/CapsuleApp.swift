//
//  CapsuleApp.swift
//  Capsule
//
//  Audio mixer for macOS with pill-style UI.
//

import SwiftUI

@main
struct CapsuleApp: App {

    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // Capsule lives in the menu bar; the mixer popover and window are owned
        // by `StatusBarController`, so the only SwiftUI scene here is Settings.
        Settings {
            SettingsView(manager: AudioManager.shared)
        }
        .commands {
            CapsuleCommands(manager: AudioManager.shared)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {

    private var statusBarController: StatusBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Menu-bar-first utility: no Dock icon, and closing every window must
        // not quit (the mixer lives behind the status item).
        NSApp.setActivationPolicy(.accessory)

        let manager = AudioManager.shared
        manager.initialize()

        let controller = StatusBarController(manager: manager)
        MixerPresenter.shared.configure(manager: manager, presenter: controller)
        statusBarController = controller
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationWillTerminate(_ notification: Notification) {
        AudioManager.shared.shutdown()
    }
}
