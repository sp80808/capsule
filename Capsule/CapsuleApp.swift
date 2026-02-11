//
//  CapsuleApp.swift
//  Capsule
//
//  Audio mixer for macOS with pill-style UI
//

import SwiftUI

@main
struct CapsuleApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 400, minHeight: 600)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(after: .appInfo) {
                Button("Refresh Apps") {
                    AudioManager.shared.refreshAudioApps()
                }
                .keyboardShortcut("r", modifiers: .command)
                
                Divider()
                
                Button("Mute All") {
                    AudioManager.shared.muteAllApps()
                }
                .keyboardShortcut("m", modifiers: [.command, .shift])
                
                Button("Unmute All") {
                    AudioManager.shared.unmuteAllApps()
                }
                .keyboardShortcut("u", modifiers: [.command, .shift])
            }
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Configure audio session on startup
        AudioManager.shared.initialize()
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}
