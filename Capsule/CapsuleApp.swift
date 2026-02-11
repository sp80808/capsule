//
//  CapsuleApp.swift
//  Capsule
//
//  A system-wide audio mixer for macOS that mimics the native Control Centre UI.
//  Allows per-app volume control using CoreAudio.
//

import SwiftUI

@main
struct CapsuleApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        // Main window hidden, using menu bar only
        Settings {
            EmptyView()
        }
    }
}

// AppDelegate to manage the menu bar item and popover
class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var popover: NSPopover?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Create the status bar item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        
        if let button = statusItem?.button {
            // Use SF Symbol for the menu bar icon
            button.image = NSImage(systemSymbolName: "speaker.wave.3.fill", accessibilityDescription: "Capsule Audio Mixer")
            button.action = #selector(togglePopover)
            button.target = self
        }
        
        // Create the popover with our SwiftUI view
        popover = NSPopover()
        popover?.contentSize = NSSize(width: 360, height: 480)
        popover?.behavior = .transient
        popover?.contentViewController = NSHostingController(rootView: ContentView())
    }
    
    @objc func togglePopover() {
        guard let button = statusItem?.button else { return }
        
        if let popover = popover {
            if popover.isShown {
                popover.performClose(nil)
            } else {
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
                // Activate the popover window
                popover.contentViewController?.view.window?.makeKey()
            }
        }
    }
}
