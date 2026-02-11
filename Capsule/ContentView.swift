//
//  ContentView.swift
//  Capsule
//
//  Main view with frosted glass and pill sliders
//

import SwiftUI

struct ContentView: View {
    @StateObject private var audioManager = AudioManager.shared
    
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
                
                // App Volume Controls
                ScrollView {
                    VStack(spacing: 16) {
                        if audioManager.audioApps.isEmpty {
                            // Empty state
                            VStack(spacing: 12) {
                                Image(systemName: "speaker.slash.fill")
                                    .font(.system(size: 48))
                                    .foregroundColor(.secondary.opacity(0.5))
                                
                                Text("No Applications Running")
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                                
                                Text("Launch apps to see their audio controls")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 100)
                        } else {
                            ForEach(audioManager.audioApps) { app in
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
            .help("Refresh audio apps")
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
