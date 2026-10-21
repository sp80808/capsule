//
//  PillSlider.swift
//  Capsule
//
//  Custom pill-shaped slider with thick design.
//

import AppKit
import SwiftUI

struct PillSlider: View {

    @Binding var value: Double
    @Binding var isMuted: Bool

    /// Name used in the accessibility label, e.g. the app or "System output".
    var accessibilityName: String = "Volume"

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var isDragging = false

    private let height: CGFloat = 44
    private let handleSize: CGFloat = 32

    private var clamped: Double { min(max(value, 0), 1) }

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let fillWidth = max(handleSize, CGFloat(clamped) * width)

            ZStack(alignment: .leading) {
                // Track
                Capsule()
                    .fill(CapsuleTheme.track)
                    .frame(height: height)

                // Filled portion
                if !isMuted && clamped > 0.001 {
                    Capsule()
                        .fill(CapsuleTheme.fillGradient)
                        .frame(width: fillWidth, height: height)
                }

                // Handle
                HStack {
                    Spacer()
                    handle
                }
                .frame(width: fillWidth, alignment: .trailing)
            }
            .contentShape(Capsule())
            .gesture(dragGesture(width: width))
            .onTapGesture(count: 2) {
                withAnimation(.spring(response: 0.3)) { isMuted.toggle() }
            }
        }
        .frame(height: height)
        // Suppress the spring while dragging so the fill tracks the pointer
        // instead of lagging behind it, and drop animation entirely for users
        // who asked macOS to reduce motion.
        .animation(isDragging || reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.7), value: value)
        .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.7), value: isMuted)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(accessibilityName) volume"))
        .accessibilityValue(Text(isMuted ? "muted, \(percent) percent" : "\(percent) percent"))
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment:
                isMuted = false
                value = min(1, clamped + 0.05)
            case .decrement:
                value = max(0, clamped - 0.05)
            @unknown default:
                break
            }
        }
        .accessibilityAction(named: Text(isMuted ? "Unmute" : "Mute")) {
            isMuted.toggle()
        }
    }

    private var percent: Int { Int((clamped * 100).rounded()) }

    private var handle: some View {
        ZStack {
            Circle()
                .fill(CapsuleTheme.handle)
                .frame(width: handleSize, height: handleSize)
                .shadow(color: .black.opacity(0.25), radius: 3, x: 0, y: 1)

            Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(isMuted ? .red : CapsuleTheme.handleGlyph)
        }
    }

    /// Drag to set the level. Hold ⌥ for 1% steps, ⇧ for 10% steps.
    private func dragGesture(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { gesture in
                if !isDragging { isDragging = true }
                guard width > 0 else { return }

                var next = Double(gesture.location.x / width)
                next = min(max(next, 0), 1)

                let modifiers = NSEvent.modifierFlags
                if modifiers.contains(.option) {
                    next = (next * 100).rounded() / 100
                } else if modifiers.contains(.shift) {
                    next = (next * 10).rounded() / 10
                }

                value = next
                if isMuted && next > 0.001 { isMuted = false }
            }
            .onEnded { _ in
                isDragging = false
            }
    }
}

#Preview {
    VStack(spacing: 20) {
        PillSlider(value: .constant(0.7), isMuted: .constant(false), accessibilityName: "Music")
        PillSlider(value: .constant(0.3), isMuted: .constant(false), accessibilityName: "Safari")
        PillSlider(value: .constant(0.5), isMuted: .constant(true), accessibilityName: "Spotify")
    }
    .padding()
    .frame(width: 400)
}
