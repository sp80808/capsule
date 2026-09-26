//
//  AudioManager.swift
//  Capsule
//
//  Manages audio devices and per-app audio control using Core Audio
//

import Foundation
import AVFoundation
import CoreAudio
import AppKit

class AudioManager: ObservableObject {
    static let shared = AudioManager()
    
    @Published var audioApps: [AudioApp] = []
    
    private var timer: Timer?
    
    private init() {
        // Initialize with real running applications
        updateRunningApps()
    }
    
    deinit {
        // Clean up timer to prevent memory leaks
        timer?.invalidate()
        timer = nil
    }
    
    func initialize() {
        // Start monitoring audio apps
        startMonitoring()
        
        // Listen for app launch/termination
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(applicationDidLaunch),
            name: NSWorkspace.didLaunchApplicationNotification,
            object: nil
        )
        
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(applicationDidTerminate),
            name: NSWorkspace.didTerminateApplicationNotification,
            object: nil
        )
    }
    
    @objc private func applicationDidLaunch(_ notification: Notification) {
        updateRunningApps()
    }
    
    @objc private func applicationDidTerminate(_ notification: Notification) {
        updateRunningApps()
    }
    
    private func updateRunningApps() {
        // Get all running applications
        let runningApps = NSWorkspace.shared.runningApplications
        
        // Filter for user-facing apps with valid bundle identifiers
        let filteredApps = runningApps.filter { app in
            guard let bundleID = app.bundleIdentifier,
                  app.activationPolicy == .regular,
                  let localizedName = app.localizedName,
                  !localizedName.isEmpty else {
                return false
            }
            
            // Filter out system apps and the Capsule app itself
            let systemApps = ["com.apple.finder", "com.apple.dock", "com.capsule.mixer"]
            return !systemApps.contains(bundleID)
        }
        
        // Common audio-capable apps with their SF Symbol icons
        let appIconMap: [String: String] = [
            "com.apple.Music": "music.note",
            "com.apple.safari": "safari",
            "com.spotify.client": "music.note.list",
            "com.google.Chrome": "globe",
            "us.zoom.xos": "video.fill",
            "com.tinyspeck.slackmacgap": "message.fill",
            "com.apple.TV": "tv",
            "com.microsoft.teams2": "person.3.fill",
            "org.mozilla.firefox": "globe",
            "com.brave.Browser": "shield",
            "com.apple.podcasts": "waveform",
            "com.apple.FaceTime": "video.fill"
        ]
        
        // Create or update AudioApp instances
        var newApps: [AudioApp] = []
        for app in filteredApps {
            guard let bundleID = app.bundleIdentifier,
                  let localizedName = app.localizedName else {
                continue
            }
            
            // Check if this app already exists in our list
            if let existingApp = audioApps.first(where: { $0.bundleIdentifier == bundleID }) {
                // Keep existing app with its current settings
                newApps.append(existingApp)
            } else {
                // Create new app with default settings
                let iconName = appIconMap[bundleID] ?? "app.fill"
                
                // Try to get the actual app icon from bundle
                var appIcon: NSImage? = nil
                if let bundlePath = app.bundleURL?.path, !bundlePath.isEmpty {
                    appIcon = NSWorkspace.shared.icon(forFile: bundlePath)
                }
                
                let newApp = AudioApp(
                    name: localizedName,
                    bundleIdentifier: bundleID,
                    iconName: iconName,
                    appIcon: appIcon,
                    volume: 0.7,
                    isPlaying: false
                )
                newApps.append(newApp)
            }
        }
        
        // Sort by name for consistency
        newApps.sort { $0.name.lowercased() < $1.name.lowercased() }
        
        // Update on main thread
        DispatchQueue.main.async {
            self.audioApps = newApps
        }
    }
    
    private func startMonitoring() {
        // Monitor audio apps every 2 seconds
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.updateAudioApps()
        }
    }
    
    private func updateAudioApps() {
        // Detect which apps are likely playing audio
        // This is a heuristic approach until driver integration
        DispatchQueue.main.async {
            let workspace = NSWorkspace.shared
            
            for app in self.audioApps {
                guard let bundleID = app.bundleIdentifier else { continue }
                
                // Find the running app
                if let runningApp = workspace.runningApplications.first(where: { $0.bundleIdentifier == bundleID }) {
                    // Heuristic: Mark common audio apps as potentially playing
                    let audioApps = [
                        "com.apple.Music",
                        "com.spotify.client",
                        "com.apple.podcasts",
                        "com.apple.TV"
                    ]
                    
                    if audioApps.contains(bundleID) && runningApp.isActive {
                        // Likely playing if the app is active and known to play audio
                        app.isPlaying = true
                    } else {
                        // For other apps, mark as potentially active but not guaranteed
                        app.isPlaying = false
                    }
                } else {
                    app.isPlaying = false
                }
            }
        }
    }
    
    func refreshAudioApps() {
        // Refresh the list of audio apps from running applications
        updateRunningApps()
    }
    
    func muteAllApps() {
        DispatchQueue.main.async {
            for app in self.audioApps {
                app.isMuted = true
            }
        }
    }
    
    func unmuteAllApps() {
        DispatchQueue.main.async {
            for app in self.audioApps {
                app.isMuted = false
            }
        }
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
    let bundleIdentifier: String?
    let iconName: String
    @Published var appIcon: NSImage?
    @Published var volume: Double
    @Published var isMuted: Bool
    @Published var isPlaying: Bool
    
    init(name: String, bundleIdentifier: String? = nil, iconName: String, appIcon: NSImage? = nil, volume: Double, isPlaying: Bool, isMuted: Bool = false) {
        self.name = name
        self.bundleIdentifier = bundleIdentifier
        self.iconName = iconName
        self.appIcon = appIcon
        self.volume = volume
        self.isPlaying = isPlaying
        self.isMuted = isMuted
    }
}

struct AudioDevice {
    let id: AudioDeviceID
    let name: String
}
