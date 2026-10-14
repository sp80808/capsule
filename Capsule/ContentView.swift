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
                
                // Output routing and hardware master volume, distinct from per-app controls.
                SystemOutputControl(output: .shared)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)

                Divider()
                    .opacity(0.3)
                    .padding(.horizontal, 20)

                // App Volume Controls
                ScrollView {
                    VStack(spacing: 16) {
                        ForEach(audioManager.audioApps) { app in
                            AppVolumeControl(app: app)
                                .padding(.horizontal, 20)
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
                // App icon placeholder
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


// Hardware master controls. The menu bar reuses this panel, not the entire app mixer.
struct SystemOutputControl: View {
    @ObservedObject var output: SystemOutputController

    private var selected: SystemOutputController.OutputDevice? {
        output.devices.first { $0.id == output.currentDeviceID }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Text("System Output")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)

                if selected?.isEqMac == true {
                    Text("eqMac")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(.green)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.green.opacity(0.14)))
                }

                Spacer()

                Menu {
                    ForEach(output.devices) { device in
                        Button {
                            output.selectOutput(device.id)
                        } label: {
                            Label(device.name,
                                  systemImage: device.id == output.currentDeviceID
                                  ? "checkmark.circle.fill" : "speaker.wave.2")
                        }
                    }
                    if output.devices.isEmpty {
                        Text("No outputs available")
                    }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "airplayaudio")
                        Text(output.currentDeviceName)
                            .lineLimit(1)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 9))
                    }
                    .font(.system(size: 11, weight: .medium))
                }
                .menuStyle(.borderlessButton)
                .fixedSize(horizontal: false, vertical: true)
                .help("Select default audio output")
            }

            PillSlider(
                value: $output.volume,
                isMuted: $output.isMuted,
                canMute: output.supportsMute,
                onValueChanged: { output.setVolume($0) },
                onMuteChanged: { output.setMuted($0) },
                onScrubbingChanged: { output.isScrubbing = $0 }
            )
            .disabled(!output.supportsVolume)

            if !output.supportsVolume {
                Text("Hardware volume is unavailable for this output.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if let message = output.errorMessage {
                Text(message)
                    .font(.caption)
                    .foregroundColor(.orange)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.primary.opacity(0.055))
        )
    }
}
