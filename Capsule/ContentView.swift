//
//  ContentView.swift
//  Capsule
//
//  Main view with frosted glass and pill sliders
//

import SwiftUI

struct ContentView: View {
    @StateObject private var audioManager = AudioManager.shared
    @State private var searchText = ""
    
    var filteredApps: [AudioApp] {
        if searchText.isEmpty {
            return audioManager.audioApps
        } else {
            return audioManager.audioApps.filter { app in
                app.name.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var body: some View {
        ZStack {
            // Frosted glass background
            VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HeaderView()
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 15)
                
                Divider()
                    .opacity(0.3)
                    .padding(.horizontal, 20)
                
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    
                    TextField("Search apps...", text: $searchText)
                        .textFieldStyle(.plain)
                    
                    if !searchText.isEmpty {
                        Button(action: { searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(8)
                .background(Color.white.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                
                // App Volume Controls
                ScrollView {
                    VStack(spacing: 16) {
                        if filteredApps.isEmpty {
                            // Empty state
                            VStack(spacing: 12) {
                                Image(systemName: searchText.isEmpty ? "speaker.slash.fill" : "magnifyingglass")
                                    .font(.system(size: 48))
                                    .foregroundColor(.secondary.opacity(0.5))
                                
                                Text(searchText.isEmpty ? "No Applications Running" : "No Apps Found")
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                                
                                Text(searchText.isEmpty ? "Launch apps to see their audio controls" : "Try a different search term")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 100)
                        } else {
                            ForEach(filteredApps) { app in
                                AppVolumeControl(app: app)
                                    .padding(.horizontal, 20)
                            }
                        }
                    }
                    .padding(.vertical, 20)
                }
            }
        }
    }
}

struct HeaderView: View {
    var body: some View {
        HStack {
            Image(systemName: "speaker.wave.3.fill")
                .font(.title2)
                .foregroundColor(.primary)
            
            Text("Capsule")
                .font(.title)
                .fontWeight(.semibold)
            
            Spacer()
            
            Button(action: {
                AudioManager.shared.refreshAudioApps()
            }) {
                Image(systemName: "arrow.clockwise")
                    .font(.title3)
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("Refresh audio apps (⌘R)")
            .keyboardShortcut("r", modifiers: .command)
        }
    }
}

struct AppVolumeControl: View {
    @ObservedObject var app: AudioApp
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                // App icon - use real icon if available, otherwise use SF Symbol
                if let appIcon = app.appIcon {
                    Image(nsImage: appIcon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 32, height: 32)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    Image(systemName: app.iconName)
                        .font(.title3)
                        .foregroundColor(.white)
                        .frame(width: 32, height: 32)
                        .background(
                            LinearGradient(
                                colors: [Color.blue, Color.purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(app.name)
                        .font(.headline)
                    
                    Text(app.isPlaying ? "Playing" : "Idle")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Volume percentage
                Text("\(Int(app.volume * 100))%")
                    .font(.system(.body, design: .rounded))
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                    .monospacedDigit()
            }
            
            // Thick pill slider
            PillSlider(value: $app.volume, isMuted: $app.isMuted)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }
}

// Frosted glass visual effect
struct VisualEffectBlur: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .frame(width: 400, height: 600)
    }
}
