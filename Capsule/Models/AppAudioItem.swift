//
//  AppAudioItem.swift
//  Capsule
//
//  Model representing an application with audio output.
//  Tracks volume, mute state, and app metadata.
//

import Foundation
import Combine

class AppAudioItem: ObservableObject, Identifiable {
    let id: String
    let name: String
    let iconName: String
    
    @Published var volume: Double
    @Published var isMuted: Bool
    
    init(id: String, name: String, iconName: String, volume: Double = 1.0, isMuted: Bool = false) {
        self.id = id
        self.name = name
        self.iconName = iconName
        self.volume = volume
        self.isMuted = isMuted
    }
    
    /// Set the volume level (0.0 to 1.0)
    func setVolume(_ newVolume: Double) {
        volume = max(0.0, min(1.0, newVolume))
        // In a full implementation, this would communicate with the audio driver
        // to actually change the process audio level
    }
    
    /// Toggle mute state
    func toggleMute() {
        isMuted.toggle()
        // In a full implementation, this would communicate with the audio driver
    }
}
