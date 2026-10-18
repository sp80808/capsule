//
//  AudioDeviceService.swift
//  Capsule
//
//  Core Audio device enumeration plus master volume/mute/device switching.
//  Unlike per-app capture, all of this works through public Core Audio APIs
//  without an audio driver.
//

import AVFoundation
import CoreAudio
import Foundation

struct AudioDevice: Identifiable, Equatable, Hashable {
    let id: AudioDeviceID
    let name: String
    var isDefault: Bool = false
}

enum AudioDeviceService {

    // MARK: - Enumeration

    /// Every output device the system can see, sorted by name.
    static func outputDevices() -> [AudioDevice] {
        var address = propertyAddress(kAudioHardwarePropertyDevices)
        var dataSize: UInt32 = 0

        let sizeStatus = AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &dataSize
        )
        guard sizeStatus == noErr else { return [] }

        let count = Int(dataSize) / MemoryLayout<AudioDeviceID>.size
        guard count > 0 else { return [] }

        var deviceIDs = [AudioDeviceID](repeating: 0, count: count)
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &dataSize,
            &deviceIDs
        )
        guard status == noErr else { return [] }

        let defaultID = defaultOutputDeviceID()
        var devices: [AudioDevice] = []
        devices.reserveCapacity(count)

        for deviceID in deviceIDs {
            guard isAlive(deviceID), isOutputDevice(deviceID), let name = name(of: deviceID) else { continue }
            devices.append(AudioDevice(id: deviceID, name: name, isDefault: deviceID == defaultID))
        }

        return devices.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    static func defaultOutputDeviceID() -> AudioDeviceID? {
        var address = propertyAddress(kAudioHardwarePropertyDefaultOutputDevice)
        var deviceID: AudioDeviceID = 0
        var dataSize = UInt32(MemoryLayout<AudioDeviceID>.size)

        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &dataSize,
            &deviceID
        )
        guard status == noErr, deviceID != kAudioObjectUnknown else { return nil }
        return deviceID
    }

    /// Routes system audio to another device.
    @discardableResult
    static func setDefaultOutputDevice(_ deviceID: AudioDeviceID) -> Bool {
        var address = propertyAddress(kAudioHardwarePropertyDefaultOutputDevice)
        var target = deviceID
        let status = AudioObjectSetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            UInt32(MemoryLayout<AudioDeviceID>.size),
            &target
        )
        return status == noErr
    }

    // MARK: - Master volume

    /// 0…1, or nil when the device exposes no software volume (many external
    /// DACs are hardware-only).
    static func volume(of deviceID: AudioDeviceID) -> Double? {
        var master = propertyAddress(kAudioDevicePropertyVolumeScalar)
        if hasProperty(deviceID, &master), let value = readFloat(deviceID, &master) {
            return Double(value)
        }

        var channelVolumes: [Float] = []
        for channel: AudioObjectPropertyElement in 1...2 {
            var channelAddress = propertyAddress(kAudioDevicePropertyVolumeScalar, element: channel)
            if hasProperty(deviceID, &channelAddress), let value = readFloat(deviceID, &channelAddress) {
                channelVolumes.append(value)
            }
        }
        guard !channelVolumes.isEmpty else { return nil }
        let total = channelVolumes.reduce(0, +)
        return Double(total / Float(channelVolumes.count))
    }

    @discardableResult
    static func setVolume(_ value: Double, on deviceID: AudioDeviceID) -> Bool {
        let clamped = Float(min(max(value, 0), 1))

        var master = propertyAddress(kAudioDevicePropertyVolumeScalar)
        if hasProperty(deviceID, &master) {
            return writeFloat(clamped, deviceID, &master)
        }

        var wroteAnything = false
        for channel: AudioObjectPropertyElement in 1...2 {
            var channelAddress = propertyAddress(kAudioDevicePropertyVolumeScalar, element: channel)
            if hasProperty(deviceID, &channelAddress) {
                wroteAnything = writeFloat(clamped, deviceID, &channelAddress) || wroteAnything
            }
        }
        return wroteAnything
    }

    static func isMuted(_ deviceID: AudioDeviceID) -> Bool {
        var address = propertyAddress(kAudioDevicePropertyMute)
        guard hasProperty(deviceID, &address) else { return false }
        return (readUInt32(deviceID, &address) ?? 0) != 0
    }

    @discardableResult
    static func setMuted(_ muted: Bool, on deviceID: AudioDeviceID) -> Bool {
        var address = propertyAddress(kAudioDevicePropertyMute)
        guard hasProperty(deviceID, &address) else { return false }
        return writeUInt32(muted ? 1 : 0, deviceID, &address)
    }

    // MARK: - Helpers

    private static func propertyAddress(
        _ selector: AudioObjectPropertySelector,
        scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal,
        element: AudioObjectPropertyElement = kAudioObjectPropertyElementMain
    ) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: element)
    }

    private static func hasProperty(_ deviceID: AudioDeviceID, _ address: inout AudioObjectPropertyAddress) -> Bool {
        var hasProperty: DarwinBoolean = false
        let status = AudioObjectHasPropertyData(deviceID, &address, &hasProperty)
        return status == noErr && hasProperty.boolValue
    }

    private static func readFloat(
        _ deviceID: AudioDeviceID,
        _ address: inout AudioObjectPropertyAddress
    ) -> Float? {
        var value: Float32 = 0
        var dataSize = UInt32(MemoryLayout<Float32>.size)
        let status = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &dataSize, &value)
        return status == noErr ? value : nil
    }

    private static func writeFloat(
        _ value: Float,
        _ deviceID: AudioDeviceID,
        _ address: inout AudioObjectPropertyAddress
    ) -> Bool {
        var payload = value
        let status = AudioObjectSetPropertyData(
            deviceID,
            &address,
            0,
            nil,
            UInt32(MemoryLayout<Float32>.size),
            &payload
        )
        return status == noErr
    }

    private static func readUInt32(
        _ deviceID: AudioDeviceID,
        _ address: inout AudioObjectPropertyAddress
    ) -> UInt32? {
        var value: UInt32 = 0
        var dataSize = UInt32(MemoryLayout<UInt32>.size)
        let status = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &dataSize, &value)
        return status == noErr ? value : nil
    }

    private static func writeUInt32(
        _ value: UInt32,
        _ deviceID: AudioDeviceID,
        _ address: inout AudioObjectPropertyAddress
    ) -> Bool {
        var payload = value
        let status = AudioObjectSetPropertyData(
            deviceID,
            &address,
            0,
            nil,
            UInt32(MemoryLayout<UInt32>.size),
            &payload
        )
        return status == noErr
    }

    private static func isAlive(_ deviceID: AudioDeviceID) -> Bool {
        var address = propertyAddress(kAudioDevicePropertyDeviceIsAlive)
        guard hasProperty(deviceID, &address) else { return true }
        return (readUInt32(deviceID, &address) ?? 0) != 0
    }

    /// A device is an output device when its output stream configuration has at
    /// least one channel.
    private static func isOutputDevice(_ deviceID: AudioDeviceID) -> Bool {
        var address = propertyAddress(kAudioDevicePropertyStreamConfiguration, scope: kAudioObjectPropertyScopeOutput)
        var dataSize: UInt32 = 0

        let sizeStatus = AudioObjectGetPropertyDataSize(deviceID, &address, 0, nil, &dataSize)
        guard sizeStatus == noErr, dataSize > 0 else { return false }

        let buffer = UnsafeMutableRawPointer.allocate(
            byteCount: Int(dataSize),
            alignment: MemoryLayout<AudioBufferList>.alignment
        )
        defer { buffer.deallocate() }

        let status = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &dataSize, buffer)
        guard status == noErr else { return false }

        let list = buffer.assumingMemoryBound(to: AudioBufferList.self)
        let buffers = UnsafeMutableAudioBufferListPointer(list)
        let channels = buffers.reduce(0) { $0 + Int($1.mNumberChannels) }
        return channels > 0
    }

    private static func name(of deviceID: AudioDeviceID) -> String? {
        var address = propertyAddress(kAudioDevicePropertyDeviceNameCFString)
        var deviceName: CFString = "" as CFString
        var dataSize = UInt32(MemoryLayout<CFString>.size)

        let status = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &dataSize, &deviceName)
        guard status == noErr else { return nil }

        let name = deviceName as String
        return name.isEmpty ? nil : name
    }
}
