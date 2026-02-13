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
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Configure audio session on startup
        AudioManager.shared.initialize()
        
        // Register for window notifications to optimize resource usage
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowDidBecomeKey),
            name: NSWindow.didBecomeKeyNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowDidResignKey),
            name: NSWindow.didResignKeyNotification,
            object: nil
        )
    }
    
    @objc func windowDidBecomeKey(_ notification: Notification) {
        // Resume monitoring when window becomes active (without reinitializing)
        AudioManager.shared.resumeMonitoring()
    }
    
    @objc func windowDidResignKey(_ notification: Notification) {
        // Pause monitoring when window becomes inactive to save resources
        AudioManager.shared.stopMonitoring()
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}
