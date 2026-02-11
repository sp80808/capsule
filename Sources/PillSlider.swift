import SwiftUI

struct PillSlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    let label: String
    let icon: String
    
    @State private var isDragging = false
    @State private var scale: CGFloat = 1.0
    
    private var normalizedValue: CGFloat {
        CGFloat((value - range.lowerBound) / (range.upperBound - range.lowerBound))
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)
                
                Text(label)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                Text("\(Int(value))%")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.primary)
                    .monospacedDigit()
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background pill
                    Capsule()
                        .fill(.ultraThinMaterial)
                        .overlay(
                            Capsule()
                                .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
                        )
                        .frame(height: 32)
                    
                    // Fill pill
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.blue.opacity(0.8),
                                    Color.blue.opacity(0.6)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(
                            width: max(32, geometry.size.width * normalizedValue),
                            height: 32
                        )
                        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: value)
                    
                    // Thumb
                    Circle()
                        .fill(.white)
                        .frame(width: 24, height: 24)
                        .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                        .scaleEffect(scale)
                        .position(
                            x: max(16, min(geometry.size.width - 16, 
                                geometry.size.width * normalizedValue)),
                            y: 16
                        )
                }
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { gesture in
                            if !isDragging {
                                isDragging = true
                                withAnimation(.spring(response: 0.2, dampingFraction: 0.5)) {
                                    scale = 1.15
                                }
                            }
                            
                            let newValue = range.lowerBound + (gesture.location.x / geometry.size.width) * (range.upperBound - range.lowerBound)
                            value = min(max(newValue, range.lowerBound), range.upperBound)
                        }
                        .onEnded { _ in
                            isDragging = false
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                scale = 1.0
                            }
                        }
                )
            }
            .frame(height: 32)
        }
    }
}
