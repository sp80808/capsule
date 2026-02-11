//
//  CapsuleVolumeControl.swift
//  Capsule
//
//  A thick, pill-shaped volume control "capsule" with native bounce animations.
//  Follows Apple HIG design guidelines for sliders and controls.
//

import SwiftUI

struct CapsuleVolumeControl: View {
    @ObservedObject var appItem: AppAudioItem
    @State private var isDragging = false
    @State private var bounceScale: CGFloat = 1.0
    
    private let capsuleHeight: CGFloat = 44
    private let capsuleCornerRadius: CGFloat = 22
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // App info header
            HStack(spacing: 12) {
                // App icon placeholder (using SF Symbol)
                Image(systemName: appItem.iconName)
                    .font(.system(size: 24))
                    .foregroundColor(.accentColor)
                    .frame(width: 32, height: 32)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(appItem.name)
                        .font(.system(size: 14, weight: .medium))
                    
                    Text("\(Int(appItem.volume * 100))%")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Mute button
                Button(action: toggleMute) {
                    Image(systemName: appItem.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                        .font(.system(size: 16))
                        .foregroundColor(appItem.isMuted ? .secondary : .accentColor)
                }
                .buttonStyle(.plain)
                .help(appItem.isMuted ? "Unmute" : "Mute")
            }
            
            // The capsule slider
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background capsule
                    Capsule()
                        .fill(Color.secondary.opacity(0.2))
                        .frame(height: capsuleHeight)
                    
                    // Filled portion capsule
                    Capsule()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.accentColor.opacity(0.8),
                                    Color.accentColor
                                ]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(capsuleHeight, geometry.size.width * appItem.volume), height: capsuleHeight)
                    
                    // Drag handle (thumb)
                    Circle()
                        .fill(Color.white)
                        .frame(width: capsuleHeight - 8, height: capsuleHeight - 8)
                        .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                        .offset(x: max(4, (geometry.size.width - capsuleHeight + 8) * appItem.volume))
                        .scaleEffect(bounceScale)
                        .animation(.spring(response: 0.3, dampingFraction: 0.6, blendDuration: 0), value: bounceScale)
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            if !isDragging {
                                isDragging = true
                                withAnimation(.spring(response: 0.2, dampingFraction: 0.5)) {
                                    bounceScale = 1.1
                                }
                            }
                            
                            let newVolume = max(0, min(1, value.location.x / geometry.size.width))
                            appItem.setVolume(newVolume)
                        }
                        .onEnded { _ in
                            isDragging = false
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                bounceScale = 1.0
                            }
                        }
                )
            }
            .frame(height: capsuleHeight)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.secondary.opacity(0.05))
        )
    }
    
    private func toggleMute() {
        withAnimation(.easeInOut(duration: 0.2)) {
            appItem.toggleMute()
        }
    }
}

#Preview {
    CapsuleVolumeControl(appItem: AppAudioItem(
        id: "preview",
        name: "Music",
        iconName: "music.note",
        volume: 0.7,
        isMuted: false
    ))
    .padding()
    .frame(width: 360)
}
