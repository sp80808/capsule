import SwiftUI

struct AudioMixerView: View {
    @StateObject private var audioChannels = AudioChannels()
    @State private var masterVolume: Double = 75
    
    var body: some View {
        ZStack {
            // Background with ultraThinMaterial
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HeaderView()
                    .padding(.horizontal, 24)
                    .padding(.vertical, 20)
                
                ScrollView {
                    VStack(spacing: 16) {
                        // Master Volume Panel
                        MasterVolumePanel(masterVolume: $masterVolume)
                            .padding(.horizontal, 24)
                        
                        // Channel Controls
                        VStack(spacing: 12) {
                            ForEach($audioChannels.channels) { $channel in
                                ChannelControlCard(channel: $channel)
                                    .padding(.horizontal, 24)
                            }
                        }
                    }
                    .padding(.vertical, 16)
                }
            }
        }
    }
}

struct HeaderView: View {
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "waveform.circle.fill")
                .font(.system(size: 32, weight: .medium))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.blue, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .symbolRenderingMode(.hierarchical)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Capsule")
                    .font(.system(size: 24, weight: .bold))
                
                Text("Audio Mixer")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            HStack(spacing: 8) {
                ControlButton(icon: "speaker.wave.2.fill", isActive: true)
                ControlButton(icon: "gearshape.fill", isActive: false)
            }
        }
    }
}

struct ControlButton: View {
    let icon: String
    let isActive: Bool
    
    @State private var isHovered = false
    @State private var scale: CGFloat = 1.0
    
    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                scale = 0.9
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    scale = 1.0
                }
            }
        }) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(isActive ? .blue : .secondary)
                .frame(width: 36, height: 36)
                .background(
                    Circle()
                        .fill(isHovered ? Color.white.opacity(0.1) : Color.clear)
                )
        }
        .buttonStyle(.plain)
        .scaleEffect(scale)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
    }
}

struct MasterVolumePanel: View {
    @Binding var masterVolume: Double
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "speaker.wave.3.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.blue)
                
                Text("Master Volume")
                    .font(.system(size: 16, weight: .semibold))
                
                Spacer()
            }
            
            PillSlider(
                value: $masterVolume,
                range: 0...100,
                label: "Output Level",
                icon: "speaker.wave.2.fill"
            )
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 4)
        )
    }
}

struct ChannelControlCard: View {
    @Binding var channel: AudioChannel
    @State private var scale: CGFloat = 1.0
    
    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                // Channel Icon
                ZStack {
                    Circle()
                        .fill(channelColor.opacity(0.2))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: channel.icon)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(channelColor)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(channel.name)
                        .font(.system(size: 15, weight: .semibold))
                    
                    Text(channel.isMuted ? "Muted" : "Active")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(channel.isMuted ? .red : .secondary)
                }
                
                Spacer()
                
                // Mute Button
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        channel.isMuted.toggle()
                        scale = 0.9
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                            scale = 1.0
                        }
                    }
                }) {
                    Image(systemName: channel.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(channel.isMuted ? .red : .secondary)
                        .frame(width: 36, height: 36)
                        .background(
                            Circle()
                                .fill(channel.isMuted ? Color.red.opacity(0.1) : Color.white.opacity(0.05))
                        )
                }
                .buttonStyle(.plain)
                .scaleEffect(scale)
            }
            
            // Volume Slider
            PillSlider(
                value: $channel.volume,
                range: 0...100,
                label: "Volume",
                icon: "slider.horizontal.3"
            )
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 4)
        )
        .opacity(channel.isMuted ? 0.6 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: channel.isMuted)
    }
    
    private var channelColor: Color {
        switch channel.color {
        case "blue": return .blue
        case "pink": return .pink
        case "purple": return .purple
        case "green": return .green
        case "orange": return .orange
        default: return .blue
        }
    }
}

#Preview {
    AudioMixerView()
        .frame(width: 600, height: 700)
}
