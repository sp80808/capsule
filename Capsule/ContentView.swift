//
//  ContentView.swift
//  Capsule
//
//  Main view for the audio mixer, displayed in the popover.
//  Follows Apple HIG design with frosted glass background.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var audioManager = AudioManager.shared
    
    var body: some View {
        ZStack {
            // Frosted glass background using VisualEffectView
            VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                headerView
                
                Divider()
                    .padding(.horizontal)
                
                // Scrollable list of apps with volume controls
                ScrollView {
                    VStack(spacing: 16) {
                        ForEach(audioManager.audioApps) { app in
                            CapsuleVolumeControl(appItem: app)
                                .padding(.horizontal)
                        }
                    }
                    .padding(.vertical, 16)
                }
            }
        }
        .frame(width: 360, height: 480)
    }
    
    private var headerView: some View {
        HStack {
            // SF Symbol icon
            Image(systemName: "speaker.wave.3.fill")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.accentColor)
            
            Text("Audio Mixer")
                .font(.system(size: 18, weight: .semibold))
            
            Spacer()
            
            // Settings button (placeholder for future features)
            Button(action: {}) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("Settings")
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
