//
//  AudioManager.swift
//  Capsule
//
//  Manages audio devices and per-app audio control using Core Audio
//

import Foundation
import AVFoundation
import CoreAudio

class AudioManager: ObservableObject {
    static let shared = AudioManager()
    
    @Published var audioApps: [AudioApp] = []
    
    private var timer: Timer?
    
    private init() {
        // Initialize with sample apps for demonstration
        setupSampleApps()
    }
    
    deinit {
        // Clean up timer to prevent memory leaks
        timer?.invalidate()
        timer = nil
    }
    
    func initialize() {
        // Start monitoring audio apps
        startMonitoring()
    }
    
    private func setupSampleApps() {
        // Sample apps for demonstration
        // In a real implementation, this would query actual running apps with audio
        audioApps = [
            AudioApp(name: "Music", iconName: "music.note", volume: 0.7, isPlaying: true),
            AudioApp(name: "Safari", iconName: "safari", volume: 0.5, isPlaying: false),
            AudioApp(name: "Spotify", iconName: "music.note.list", volume: 0.8, isPlaying: true),
            AudioApp(name: "Chrome", iconName: "globe", volume: 0.6, isPlaying: false),
            AudioApp(name: "Zoom", iconName: "video.fill", volume: 0.4, isPlaying: false),
            AudioApp(name: "Slack", iconName: "message.fill", volume: 0.3, isPlaying: false),
        ]
    }
    
    private func startMonitoring() {
        // Monitor audio apps every 2 seconds
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.updateAudioApps()
        }
    }
    
    private func updateAudioApps() {
        // In a real implementation, this would:
        // 1. Query Core Audio for active audio sessions
        // 2. Get per-app audio levels
        // 3. Update the audioApps array
        
        // TEMPORARY: Simulate activity changes for demonstration purposes
        // Replace this with actual Core Audio monitoring when driver is integrated
        DispatchQueue.main.async {
            for app in self.audioApps {
                if app.isPlaying {
                    // Randomly toggle playing state to simulate audio activity
                    // TODO: Replace with actual audio level detection
                    app.isPlaying = Bool.random()
                }
            }
        }
    }
    
    func refreshAudioApps() {
        // Refresh the list of audio apps
        setupSampleApps()
    }
    
    // MARK: - Core Audio Integration
    // This is where eqMac driver integration would happen
    
    func setAppVolume(appID: String, volume: Float) {
        // TODO: Integrate with audio driver to set per-app volume
        // This would use Core Audio APIs or eqMac driver APIs
        print("Setting volume for \(appID) to \(volume)")
    }
    
    func getAudioDevices() -> [AudioDevice] {
        var devices: [AudioDevice] = []
        
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        var dataSize: UInt32 = 0
        var status = AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &dataSize
        )
        
        if status == noErr {
            let deviceCount = Int(dataSize) / MemoryLayout<AudioDeviceID>.size
            var deviceIDs = [AudioDeviceID](repeating: 0, count: deviceCount)
            
            status = AudioObjectGetPropertyData(
                AudioObjectID(kAudioObjectSystemObject),
                &propertyAddress,
                0,
                nil,
                &dataSize,
                &deviceIDs
            )
            
            if status == noErr {
                for deviceID in deviceIDs {
                    if let deviceName = getDeviceName(deviceID: deviceID) {
                        devices.append(AudioDevice(id: deviceID, name: deviceName))
                    }
                }
            }
        }
        
        return devices
    }
    
    private func getDeviceName(deviceID: AudioDeviceID) -> String? {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceNameCFString,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        var deviceName: CFString = "" as CFString
        var dataSize = UInt32(MemoryLayout<CFString>.size)
        
        let status = AudioObjectGetPropertyData(
            deviceID,
            &propertyAddress,
            0,
            nil,
            &dataSize,
            &deviceName
        )
        
        return status == noErr ? (deviceName as String) : nil
    }
}

// MARK: - Models

class AudioApp: ObservableObject, Identifiable {
    let id = UUID()
    let name: String
    let iconName: String
    @Published var volume: Double
    @Published var isMuted: Bool
    @Published var isPlaying: Bool
    
    init(name: String, iconName: String, volume: Double, isPlaying: Bool, isMuted: Bool = false) {
        self.name = name
        self.iconName = iconName
        self.volume = volume
        self.isPlaying = isPlaying
        self.isMuted = isMuted
    }
}

struct AudioDevice {
    let id: AudioDeviceID
    let name: String
}
