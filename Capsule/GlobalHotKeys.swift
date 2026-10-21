//
//  GlobalHotKeys.swift
//  Capsule
//
//  System-wide shortcuts via the Carbon hot key API. The SwiftUI menu commands
//  only fire while Capsule is frontmost, which is exactly when you do not need
//  them — these work from any app.
//
//  Defaults use ⌃⌥⌘ so they stay out of the way: ⌘M is "minimise" everywhere,
//  and ⌃⌥ is the VoiceOver modifier prefix.
//

import AppKit
import Carbon

/// Carbon's `eventParamErr` is declared in CarbonEvents.h but is not visible to
/// Swift, so the handler reports it by value.
private let eventParamError: OSStatus = -9878

enum HotKeyAction: String, CaseIterable, Identifiable {

    case muteSelected
    case soloSelected
    case unmuteAll
    case showMixer

    var id: String { rawValue }

    /// Stable numeric id carried in `EventHotKeyID.id`.
    var identifier: UInt32 {
        switch self {
        case .muteSelected: return 1
        case .soloSelected: return 2
        case .unmuteAll: return 3
        case .showMixer: return 4
        }
    }

    var title: String {
        switch self {
        case .muteSelected: return "Mute / unmute the selected app"
        case .soloSelected: return "Mute all other apps (solo)"
        case .unmuteAll: return "Unmute all apps"
        case .showMixer: return "Show the menu bar mixer"
        }
    }

    var keyCode: UInt32 {
        switch self {
        case .muteSelected, .soloSelected: return UInt32(kVK_ANSI_M)
        case .unmuteAll: return UInt32(kVK_ANSI_U)
        case .showMixer: return UInt32(kVK_ANSI_C)
        }
    }

    var modifiers: UInt32 {
        let base = UInt32(cmdKey | optionKey | controlKey)
        return self == .soloSelected ? base | UInt32(shiftKey) : base
    }

    /// Human-readable chord for the Settings list.
    var display: String {
        switch self {
        case .muteSelected: return "⌃⌥⌘M"
        case .soloSelected: return "⌃⌥⌘⇧M"
        case .unmuteAll: return "⌃⌥⌘U"
        case .showMixer: return "⌃⌥⌘C"
        }
    }

    init?(identifier: UInt32) {
        guard let match = HotKeyAction.allCases.first(where: { $0.identifier == identifier }) else {
            return nil
        }
        self = match
    }
}

final class GlobalHotKeyCenter {

    static let shared = GlobalHotKeyCenter()

    /// 'CAPS' — every hot key Capsule registers carries this signature.
    private static let signature: OSType = 0x43_41_50_53

    private var refs: [HotKeyAction: EventHotKeyRef] = [:]
    private var handlers: [HotKeyAction: () -> Void] = [:]
    private var eventHandler: EventHandlerRef?

    private(set) var isInstalled = false

    private init() {}

    /// Registers any hot keys that are not registered yet and refreshes their
    /// actions. Safe to call repeatedly.
    func install(_ actions: [HotKeyAction: () -> Void]) {
        installEventHandlerIfNeeded()

        for (action, handler) in actions {
            handlers[action] = handler

            guard refs[action] == nil else { continue }

            var hotKeyID = EventHotKeyID(signature: Self.signature, id: action.identifier)
            var ref: EventHotKeyRef?
            let status = RegisterEventHotKey(
                action.keyCode,
                action.modifiers,
                hotKeyID,
                GetEventDispatcherTarget(),
                0,
                &ref
            )

            if status == noErr, let ref {
                refs[action] = ref
            } else {
                #if DEBUG
                print("[Capsule] could not register \(action.display): \(status)")
                #endif
            }
        }

        isInstalled = !refs.isEmpty
    }

    func uninstall() {
        for ref in refs.values {
            UnregisterEventHotKey(ref)
        }
        refs.removeAll()
        handlers.removeAll()
        isInstalled = false
    }

    /// Called from the C event handler.
    fileprivate func handle(hotKeyIdentifier: UInt32) {
        guard let action = HotKeyAction(identifier: hotKeyIdentifier),
              let handler = handlers[action]
        else { return }

        DispatchQueue.main.async {
            handler()
        }
    }

    private func installEventHandlerIfNeeded() {
        guard eventHandler == nil else { return }

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let userData = Unmanaged.passUnretained(self).toOpaque()

        InstallEventHandler(
            GetEventDispatcherTarget(),
            { _, event, userData -> OSStatus in
                guard let event, let userData else { return eventParamError }

                let center = Unmanaged<GlobalHotKeyCenter>.fromOpaque(userData).takeUnretainedValue()

                var hotKeyID = EventHotKeyID()
                let status = GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )
                guard status == noErr else { return status }

                center.handle(hotKeyIdentifier: hotKeyID.id)
                return noErr
            },
            1,
            &eventType,
            userData,
            &eventHandler
        )
    }
}
