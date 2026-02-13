//
//  PillSlider.swift
//  Capsule
//
//  Custom pill-shaped slider with thick design
//

import SwiftUI

struct PillSlider: View {
    @Binding var value: Double
    @Binding var isMuted: Bool
    
    @State private var isDragging = false
    
    private let height: CGFloat = 48
    private let handleSize: CGFloat = 36
    
    // Computed property for animation tracking - more efficient than creating arrays
    private var animationValue: Double {
        // Combine value and muted state into a single hashable value for animation
        value + (isMuted ? 1000.0 : 0.0)
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background pill
                Capsule()
                    .fill(Color.white.opacity(0.08))
                    .frame(height: height)
                
                // Active fill
                if !isMuted {
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.blue.opacity(0.6),
                                    Color.purple.opacity(0.6)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(handleSize, CGFloat(value) * geometry.size.width), height: height)
                }
                
                // Handle
                HStack {
                    Spacer()
                    
                    ZStack {
                        Circle()
                            .fill(Color.white)
                            .frame(width: handleSize, height: handleSize)
                            .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                        
                        Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                            .font(.system(size: 14))
                            .foregroundColor(isMuted ? .gray : .blue)
                    }
                }
                .frame(width: max(handleSize, CGFloat(value) * geometry.size.width), alignment: .trailing)
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        isDragging = true
                        let newValue = min(max(0, gesture.location.x / geometry.size.width), 1)
                        value = newValue
                        
                        // Unmute if dragging
                        if isMuted && newValue > 0 {
                            isMuted = false
                        }
                    }
                    .onEnded { _ in
                        isDragging = false
                    }
            )
            .onTapGesture(count: 2) {
                // Double tap to toggle mute
                withAnimation(.spring(response: 0.3)) {
                    isMuted.toggle()
                }
            }
        }
        .frame(height: height)
        // Single animation using computed property - more efficient than array creation
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: animationValue)
    }
}

struct PillSlider_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            PillSlider(value: .constant(0.7), isMuted: .constant(false))
            PillSlider(value: .constant(0.3), isMuted: .constant(false))
            PillSlider(value: .constant(0.5), isMuted: .constant(true))
        }
        .padding()
        .frame(width: 400)
        .background(Color.black)
    }
}
