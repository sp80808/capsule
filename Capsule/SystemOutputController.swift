//
//  SystemOutputController.swift
//  Capsule
//
//  Default output routing and hardware volume, separate from per-app mixing.
//

import Foundation
import Combine
import CoreAudio
import AudioToolbox

final class SystemOutputController: ObservableObject {
    static let shared = SystemOutputController()

    struct OutputDevice: Identifiable, Hashable {
        let id: AudioObjectID
        let name: String
        let uid: String
        var isEqMac: Bool {
            name.localizedCaseInsensitiveContains("eqmac") ||
            uid.localizedCaseInsensitiveContains("eqmac")
        }
    }

    @Published private(set) var devices: [OutputDevice] = []
    @Published private(set) var currentDeviceID: AudioObjectID = kAudioObjectUnknown
    @Published private(set) var currentDeviceName = "System Output"
    @Published private(set) var supportsVolume = false
    @Published private(set) var supportsMute = false
    @Published var volume: Double = 0.5
    @Published var isMuted = false
    @Published private(set) var errorMessage: String?

    var isScrubbing = false {
        didSet { if !isScrubbing { readCurrentState() } }
    }

    private let systemObject = AudioObjectID(kAudioObjectSystemObject)
    private let listenerQueue = DispatchQueue.main
    private var systemListener: AudioObjectPropertyListenerBlock?
    private var deviceListener: AudioObjectPropertyListenerBlock?
    private var systemAddresses: [AudioObjectPropertyAddress] = []
    private var deviceAddresses: [AudioObjectPropertyAddress] = []

    private init() {
        refreshDevices()
        observeSystemChanges()
    }

    deinit {
        detachDeviceListener(from: currentDeviceID)
        if let block = systemListener {
            for item in systemAddresses {
                var address = item
                AudioObjectRemovePropertyListenerBlock(systemObject, &address, listenerQueue, block)
            }
        }
    }

    private func address(
        _ selector: AudioObjectPropertySelector,
        scope: AudioObjectPropertyScope = kAudioDevicePropertyScopeOutput,
        element: AudioObjectPropertyElement = kAudioObjectPropertyElementMain
    ) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: element)
    }

    private func isWritable(_ proposed: AudioObjectPropertyAddress, on device: AudioObjectID) -> Bool {
        var property = proposed
        guard AudioObjectHasProperty(device, &property) else { return false }
        var writable = DarwinBoolean(false)
        return AudioObjectIsPropertySettable(device, &property, &writable) == noErr && writable.boolValue
    }

    private func volumeAddresses(on device: AudioObjectID) -> [AudioObjectPropertyAddress] {
        let virtual = address(kAudioHardwareServiceDeviceProperty_VirtualMainVolume)
        if isWritable(virtual, on: device) { return [virtual] }
        let main = address(kAudioDevicePropertyVolumeScalar)
        if isWritable(main, on: device) { return [main] }
        return [AudioObjectPropertyElement(1), AudioObjectPropertyElement(2)]
            .map { address(kAudioDevicePropertyVolumeScalar, element: $0) }
            .filter { isWritable($0, on: device) }
    }

    private func muteAddresses(on device: AudioObjectID) -> [AudioObjectPropertyAddress] {
        let main = address(kAudioDevicePropertyMute)
        if isWritable(main, on: device) { return [main] }
        return [AudioObjectPropertyElement(1), AudioObjectPropertyElement(2)]
            .map { address(kAudioDevicePropertyMute, element: $0) }
            .filter { isWritable($0, on: device) }
    }

    func setVolume(_ rawValue: Double) {
        let target = max(0, min(1, rawValue))
        let available = volumeAddresses(on: currentDeviceID)
        guard !available.isEmpty else { return }
        var scalar = Float32(target)
        let size = UInt32(MemoryLayout<Float32>.size)
        var succeeded = true
        for item in available {
            var property = item
            if AudioObjectSetPropertyData(currentDeviceID, &property, 0, nil, size, &scalar) != noErr {
                succeeded = false
            }
        }
        if succeeded {
            volume = target
            errorMessage = nil
            if target > 0 && isMuted { setMuted(false) }
        } else {
            errorMessage = "This output rejected the volume change."
            if !isScrubbing { readCurrentState() }
        }
    }

    func setMuted(_ muted: Bool) {
        let available = muteAddresses(on: currentDeviceID)
        guard !available.isEmpty else { return }
        var value: UInt32 = muted ? 1 : 0
        let size = UInt32(MemoryLayout<UInt32>.size)
        var succeeded = true
        for item in available {
            var property = item
            if AudioObjectSetPropertyData(currentDeviceID, &property, 0, nil, size, &value) != noErr {
                succeeded = false
            }
        }
        if succeeded {
            isMuted = muted
            errorMessage = nil
        } else {
            errorMessage = "This output rejected the mute change."
            readCurrentState()
        }
    }

    func selectOutput(_ deviceID: AudioObjectID) {
        guard devices.contains(where: { $0.id == deviceID }) else { return }
        var property = address(kAudioHardwarePropertyDefaultOutputDevice,
                               scope: kAudioObjectPropertyScopeGlobal)
        guard isWritable(property, on: systemObject) else {
            errorMessage = "macOS does not permit changing the output."
            return
        }
        var selected = deviceID
        let size = UInt32(MemoryLayout<AudioObjectID>.size)
        if AudioObjectSetPropertyData(systemObject, &property, 0, nil, size, &selected) == noErr {
            errorMessage = nil
            syncDefaultOutput()
        } else {
            errorMessage = "Unable to switch the output device."
        }
    }

    func refreshDevices() {
        var property = address(kAudioHardwarePropertyDevices, scope: kAudioObjectPropertyScopeGlobal)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(systemObject, &property, 0, nil, &size) == noErr else { return }
        let count = Int(size) / MemoryLayout<AudioObjectID>.size
        var ids = [AudioObjectID](repeating: kAudioObjectUnknown, count: count)
        guard count > 0,
              AudioObjectGetPropertyData(systemObject, &property, 0, nil, &size, &ids) == noErr else { return }

        devices = ids.filter { hasOutputStreams($0) }.map {
            OutputDevice(id: $0,
                         name: stringProperty(kAudioObjectPropertyName, on: $0) ?? "Unknown Output",
                         uid: stringProperty(kAudioDevicePropertyDeviceUID, on: $0) ?? "")
        }
        syncDefaultOutput()
    }

    private func hasOutputStreams(_ id: AudioObjectID) -> Bool {
        var property = address(kAudioDevicePropertyStreams)
        var size: UInt32 = 0
        return AudioObjectGetPropertyDataSize(id, &property, 0, nil, &size) == noErr && size > 0
    }

    private func stringProperty(_ selector: AudioObjectPropertySelector, on id: AudioObjectID) -> String? {
        var property = address(selector, scope: kAudioObjectPropertyScopeGlobal)
        var value: CFString = "" as CFString
        var size = UInt32(MemoryLayout<CFString>.size)
        guard AudioObjectGetPropertyData(id, &property, 0, nil, &size, &value) == noErr else { return nil }
        return value as String
    }

    private func syncDefaultOutput() {
        var property = address(kAudioHardwarePropertyDefaultOutputDevice,
                               scope: kAudioObjectPropertyScopeGlobal)
        var selected = kAudioObjectUnknown
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        guard AudioObjectGetPropertyData(systemObject, &property, 0, nil, &size, &selected) == noErr else {
            errorMessage = "No default output is available."
            return
        }
        if selected != currentDeviceID {
            detachDeviceListener(from: currentDeviceID)
            currentDeviceID = selected
            isScrubbing = false
            attachDeviceListener(to: selected)
        }
        currentDeviceName = devices.first(where: { $0.id == selected })?.name ?? "System Output"
        readCurrentState()
    }

    private func readFloat(_ proposed: AudioObjectPropertyAddress) -> Float32? {
        var property = proposed
        guard AudioObjectHasProperty(currentDeviceID, &property) else { return nil }
        var value: Float32 = 0
        var size = UInt32(MemoryLayout<Float32>.size)
        return AudioObjectGetPropertyData(currentDeviceID, &property, 0, nil, &size, &value) == noErr ? value : nil
    }

    private func readMute(_ proposed: AudioObjectPropertyAddress) -> Bool? {
        var property = proposed
        guard AudioObjectHasProperty(currentDeviceID, &property) else { return nil }
        var value: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        return AudioObjectGetPropertyData(currentDeviceID, &property, 0, nil, &size, &value) == noErr ? value != 0 : nil
    }

    private func readCurrentState() {
        guard currentDeviceID != kAudioObjectUnknown else {
            supportsVolume = false
            supportsMute = false
            return
        }
        supportsVolume = !volumeAddresses(on: currentDeviceID).isEmpty
        supportsMute = !muteAddresses(on: currentDeviceID).isEmpty
        guard !isScrubbing else { return }
        if let scalar = readFloat(address(kAudioHardwareServiceDeviceProperty_VirtualMainVolume))
            ?? readFloat(address(kAudioDevicePropertyVolumeScalar)) {
            volume = Double(max(0, min(1, scalar)))
        } else {
            let channels = [AudioObjectPropertyElement(1), AudioObjectPropertyElement(2)]
                .compactMap { readFloat(address(kAudioDevicePropertyVolumeScalar, element: $0)) }
            if !channels.isEmpty {
                volume = Double(channels.reduce(0, +) / Float32(channels.count))
            }
        }
        isMuted = readMute(address(kAudioDevicePropertyMute))
            ?? readMute(address(kAudioDevicePropertyMute, element: 1))
            ?? readMute(address(kAudioDevicePropertyMute, element: 2))
            ?? false
    }

    private func observeSystemChanges() {
        let block: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            self?.refreshDevices()
        }
        systemListener = block
        for selector in [kAudioHardwarePropertyDevices, kAudioHardwarePropertyDefaultOutputDevice] {
            var property = address(selector, scope: kAudioObjectPropertyScopeGlobal)
            if AudioObjectAddPropertyListenerBlock(systemObject, &property, listenerQueue, block) == noErr {
                systemAddresses.append(property)
            }
        }
    }

    private func attachDeviceListener(to id: AudioObjectID) {
        guard id != kAudioObjectUnknown else { return }
        let block: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            self?.readCurrentState()
        }
        deviceListener = block
        let properties = [
            address(kAudioHardwareServiceDeviceProperty_VirtualMainVolume),
            address(kAudioDevicePropertyVolumeScalar),
            address(kAudioDevicePropertyVolumeScalar, element: 1),
            address(kAudioDevicePropertyVolumeScalar, element: 2),
            address(kAudioDevicePropertyMute),
            address(kAudioDevicePropertyMute, element: 1),
            address(kAudioDevicePropertyMute, element: 2)
        ]
        for item in properties {
            var property = item
            if AudioObjectHasProperty(id, &property) &&
               AudioObjectAddPropertyListenerBlock(id, &property, listenerQueue, block) == noErr {
                deviceAddresses.append(property)
            }
        }
    }

    private func detachDeviceListener(from id: AudioObjectID) {
        if id != kAudioObjectUnknown, let block = deviceListener {
            for item in deviceAddresses {
                var property = item
                AudioObjectRemovePropertyListenerBlock(id, &property, listenerQueue, block)
            }
        }
        deviceAddresses.removeAll()
        deviceListener = nil
    }
}
