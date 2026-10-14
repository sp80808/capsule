//
//  CapsuleApp.swift
//  Capsule
//
//  Per-app mixer window with a compact system-output menu bar control.
//

import SwiftUI
import AppKit

@main
struct CapsuleApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 400, minHeight: 600)
        }
        .windowStyle(.hiddenTitleBar)

        if #available(macOS 13.0, *) {
            MenuBarExtra("Capsule", systemImage: "speaker.wave.2.fill") {
                VStack(spacing: 12) {
                    SystemOutputControl(output: .shared)
                    Divider()
                    Button("Quit Capsule") { NSApplication.shared.terminate(nil) }
                        .buttonStyle(.plain)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(12)
                .frame(width: 310)
                .background(VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow))
            }
            .menuBarExtraStyle(.window)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?

    func applicationDidFinishLaunching(_ notification: Notification) {
        AudioManager.shared.initialize()
        // Ensure output listeners remain live even if the mixer window is closed.
        _ = SystemOutputController.shared
        if #unavailable(macOS 13.0) {
            installLegacyStatusItem()
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Menu bar utilities should remain available after the mixer window closes.
        false
    }

    private func installLegacyStatusItem() {
        let panel = VStack(spacing: 10) {
            SystemOutputControl(output: .shared)
            Button("Quit Capsule") { NSApplication.shared.terminate(nil) }
                .font(.caption)
                .buttonStyle(.plain)
        }
        .padding(12)
        .frame(width: 290)
        .background(VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow))

        let popover = NSPopover()
        popover.behavior = .transient
        popover.contentSize = NSSize(width: 314, height: 220)
        popover.contentViewController = NSHostingController(rootView: panel)
        self.popover = popover

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            button.image = NSImage(systemSymbolName: "speaker.wave.2.fill",
                                   accessibilityDescription: "Capsule Output")
            button.action = #selector(togglePopover(_:))
            button.target = self
        }
        statusItem = item
    }

    @objc private func togglePopover(_ sender: AnyObject?) {
        guard let button = statusItem?.button, let popover = popover else { return }
        if popover.isShown {
            popover.performClose(sender)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }
}
