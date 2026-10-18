//
//  ContentView.swift
//  Capsule
//
//  Full-size mixer surface, hosted in the detached Capsule window. The menu bar
//  popover renders the same view in compact form.
//

import SwiftUI

struct ContentView: View {

    @ObservedObject var manager: AudioManager

    var body: some View {
        MixerView(manager: manager, compact: false)
    }
}

/// Sample data for Xcode previews — no live Core Audio or running apps needed.
enum CapsulePreview {

    static func makeManager() -> AudioManager {
        let defaults = UserDefaults(suiteName: "capsule.preview") ?? .standard
        let manager = AudioManager(store: VolumeStore(defaults: defaults))
        manager.replaceApps(with: [
            AudioApp(id: "com.apple.Music", name: "Music", volume: 0.7, isPlaying: true, level: 0.6),
            AudioApp(id: "com.apple.Safari", name: "Safari", volume: 0.5, level: 0),
            AudioApp(id: "com.spotify.client", name: "Spotify", volume: 0.8, isPlaying: true, level: 0.45),
            AudioApp(id: "com.google.Chrome", name: "Chrome", volume: 0.6, level: 0),
            AudioApp(id: "us.zoom.xos", name: "Zoom", volume: 0.4, isMuted: true, level: 0)
        ])
        return manager
    }
}

#Preview("Capsule window") {
    ContentView(manager: CapsulePreview.makeManager())
}
