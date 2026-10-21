//
//  StatusBarController.swift
//  Capsule
//
//  The menu bar surface: a status item that toggles the mixer popover on
//  left-click, shows a utility menu on right-click, plus the detached mixer
//  window.
//

import AppKit
import Combine
import CoreAudio
import SwiftUI

final class StatusBarController: NSObject, MixerPresenting, NSPopoverDelegate {

    private let manager: AudioManager
    private let statusItem: NSStatusItem
    private let popover: NSPopover
    private var mixerWindow: NSWindow?
    private var glyphSubscription: AnyCancellable?

    private enum Layout {
        static let popoverSize = NSSize(width: 360, height: 540)
        static let windowSize = NSSize(width: 460, height: 620)
    }

    init(manager: AudioManager) {
        self.manager = manager
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        self.popover = NSPopover()
        super.init()

        popover.behavior = .transient
        popover.animates = true
        popover.delegate = self
        popover.contentSize = Layout.popoverSize
        popover.contentViewController = NSHostingController(
            rootView: MixerView(manager: manager, compact: true)
        )

        configureButton()
        updateGlyph(manager.statusGlyph)

        glyphSubscription = manager.$statusGlyph
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] glyph in
                self?.updateGlyph(glyph)
            }
    }

    // MARK: - Status item

    private func configureButton() {
        guard let button = statusItem.button else { return }
        button.target = self
        button.action = #selector(statusItemClicked(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        button.toolTip = "Capsule"
    }

    private func updateGlyph(_ symbolName: String) {
        guard let button = statusItem.button else { return }
        let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: "Capsule")
        image?.isTemplate = true
        button.image = image
    }

    @objc private func statusItemClicked(_ sender: AnyObject?) {
        if isContextMenuEvent {
            showStatusMenu()
            return
        }
        togglePopover()
    }

    private var isContextMenuEvent: Bool {
        guard let event = NSApp.currentEvent else { return false }
        if event.type == .rightMouseUp || event.type == .rightMouseDown { return true }
        return event.type == .leftMouseUp && event.modifierFlags.contains(.control)
    }

    // MARK: - Popover

    func presentMixer() {
        showPopover()
    }

    private func togglePopover() {
        if popover.isShown {
            popover.performClose(nil)
        } else {
            showPopover()
        }
    }

    private func showPopover() {
        guard let button = statusItem.button else { return }
        manager.refreshDevices()

        if !popover.isShown {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
        popover.contentViewController?.view.window?.makeKey()
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - Detached window

    func presentMixerWindow() {
        let window = mixerWindow ?? makeWindow()
        mixerWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func makeWindow() -> NSWindow {
        let window = NSWindow(
            contentViewController: NSHostingController(
                rootView: ContentView(manager: manager)
            )
        )
        window.title = "Capsule"
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.isReleasedWhenClosed = false
        window.setContentSize(Layout.windowSize)
        window.center()
        return window
    }

    // MARK: - Status menu

    private func showStatusMenu() {
        statusItem.menu = makeStatusMenu()
        statusItem.button?.performClick(nil)
        // Detach again so the next left click toggles the popover instead of
        // opening the menu.
        statusItem.menu = nil
    }

    private func makeStatusMenu() -> NSMenu {
        let menu = NSMenu()

        menu.addItem(
            item(
                title: "Show Capsule Mixer",
                action: #selector(openMixerFromMenu),
                keyEquivalent: "c",
                modifiers: [.command, .shift]
            )
        )
        menu.addItem(
            item(
                title: "Open Capsule Window",
                action: #selector(openWindowFromMenu)
            )
        )
        menu.addItem(.separator())

        let focus = manager.shortcutTarget
        let focusName = focus?.name ?? "App"

        let muteItem = item(
            title: focus == nil ? "Mute App" : (focus?.isMuted == true ? "Unmute \(focusName)" : "Mute \(focusName)"),
            action: #selector(toggleMuteFromMenu),
            keyEquivalent: "m",
            modifiers: [.command]
        )
        muteItem.isEnabled = focus != nil
        menu.addItem(muteItem)

        let soloItem = item(
            title: manager.soloedAppID == focus?.id ? "Restore Other Apps" : "Mute All Others",
            action: #selector(toggleSoloFromMenu),
            keyEquivalent: "m",
            modifiers: [.command, .option]
        )
        soloItem.isEnabled = focus != nil && manager.apps.count > 1
        menu.addItem(soloItem)

        menu.addItem(
            item(
                title: "Unmute All Apps",
                action: #selector(unmuteAllFromMenu),
                keyEquivalent: "m",
                modifiers: [.command, .shift]
            )
        )
        menu.addItem(
            item(
                title: "Mute All Apps",
                action: #selector(muteAllFromMenu)
            )
        )

        let deviceMenu = NSMenu()
        let devices = manager.devices.isEmpty ? AudioDeviceService.outputDevices() : manager.devices
        for device in devices {
            let deviceItem = NSMenuItem(title: device.name, action: #selector(selectDeviceFromMenu(_:)), keyEquivalent: "")
            deviceItem.target = self
            deviceItem.representedObject = device.id
            deviceItem.state = device.isDefault ? .on : .off
            deviceMenu.addItem(deviceItem)
        }
        if devices.isEmpty {
            deviceMenu.addItem(NSMenuItem(title: "No output devices", action: nil, keyEquivalent: ""))
        }
        let deviceItem = NSMenuItem(title: "Output Device", action: nil, keyEquivalent: "")
        deviceItem.submenu = deviceMenu
        menu.addItem(deviceItem)

        menu.addItem(.separator())
        menu.addItem(
            item(title: "Settings…", action: #selector(openSettingsFromMenu), keyEquivalent: ",")
        )
        menu.addItem(.separator())
        menu.addItem(
            item(title: "Quit Capsule", action: #selector(quitFromMenu), keyEquivalent: "q")
        )

        return menu
    }

    private func item(
        title: String,
        action: Selector,
        keyEquivalent: String = "",
        modifiers: NSEvent.ModifierFlags = [.command]
    ) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: keyEquivalent)
        item.target = self
        item.keyEquivalentModifierMask = modifiers
        return item
    }

    // MARK: - Menu actions

    @objc private func openMixerFromMenu() {
        showPopover()
    }

    @objc private func openWindowFromMenu() {
        presentMixerWindow()
    }

    @objc private func toggleMuteFromMenu() {
        manager.toggleMuteFocused()
    }

    @objc private func toggleSoloFromMenu() {
        manager.toggleSoloFocused()
    }

    @objc private func unmuteAllFromMenu() {
        manager.unmuteAll()
    }

    @objc private func muteAllFromMenu() {
        manager.muteAll()
    }

    @objc private func selectDeviceFromMenu(_ sender: NSMenuItem) {
        guard let deviceID = sender.representedObject as? AudioDeviceID else { return }
        guard let device = manager.devices.first(where: { $0.id == deviceID }) else { return }
        manager.selectDevice(device)
    }

    @objc private func openSettingsFromMenu() {
        NSApp.activate(ignoringOtherApps: true)
        Self.openSettingsWindow()
    }

    @objc private func quitFromMenu() {
        NSApp.terminate(nil)
    }

    /// The Settings scene selector moved in macOS 14; try both.
    static func openSettingsWindow() {
        let selectors = [
            Selector(("showSettingsWindow:")),
            Selector(("showPreferencesWindow:"))
        ]
        for selector in selectors where NSApp.responds(to: selector) {
            NSApp.sendAction(selector, to: nil, from: nil)
            return
        }
    }

    // MARK: - NSPopoverDelegate

    func popoverDidClose(_ notification: Notification) {
        // Nothing to tear down: the mixer view is kept alive so the next open is
        // instant and scroll position survives.
    }
}
