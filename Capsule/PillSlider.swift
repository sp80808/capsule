//
//  PillSlider.swift
//  Capsule
//
//  Tactile pill volume control with mouse/trackpad scrolling and drag callbacks.
//

import SwiftUI
import AppKit

struct PillSlider: View {
    @Binding var value: Double
    @Binding var isMuted: Bool

    var canMute: Bool
    var onValueChanged: ((Double) -> Void)?
    var onMuteChanged: ((Bool) -> Void)?
    var onScrubbingChanged: ((Bool) -> Void)?

    @State private var isDragging = false
    @State private var isHovering = false

    init(
        value: Binding<Double>,
        isMuted: Binding<Bool>,
        canMute: Bool = true,
        onValueChanged: ((Double) -> Void)? = nil,
        onMuteChanged: ((Bool) -> Void)? = nil,
        onScrubbingChanged: ((Bool) -> Void)? = nil
    ) {
        _value = value
        _isMuted = isMuted
        self.canMute = canMute
        self.onValueChanged = onValueChanged
        self.onMuteChanged = onMuteChanged
        self.onScrubbingChanged = onScrubbingChanged
    }

    var body: some View {
        HStack(spacing: 8) {
            Button(action: toggleMute) {
                Image(systemName: speakerIcon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(isMuted ? .secondary : .accentColor)
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(Color.primary.opacity(0.08)))
            }
            .buttonStyle(.plain)
            .disabled(!canMute)
            .accessibilityLabel(isMuted ? "Unmute" : "Mute")

            GeometryReader { geo in
                let width = max(1, geo.size.width)
                let fraction = CGFloat(max(0, min(1, isMuted ? 0 : value)))

                ZStack(alignment: .leading) {
                    Capsule(style: .continuous)
                        .fill(Color.primary.opacity(0.10))
                        .overlay {
                            Capsule(style: .continuous)
                                .strokeBorder(Color.primary.opacity(0.15), lineWidth: 1)
                        }

                    Capsule(style: .continuous)
                        .fill(LinearGradient(
                            colors: [Color.accentColor.opacity(0.70), Color.accentColor],
                            startPoint: .leading,
                            endPoint: .trailing
                        ))
                        .frame(width: width * fraction)
                        .animation(isDragging ? nil : .spring(response: 0.22, dampingFraction: 0.82),
                                   value: fraction)

                    HStack {
                        Spacer()
                        Text(isMuted ? "MUTE" : "\(Int((value * 100).rounded()))%")
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundColor(.primary.opacity(0.85))
                            .padding(.trailing, 12)
                    }
                    .allowsHitTesting(false)
                }
                .frame(height: isDragging ? 38 : (isHovering ? 36 : 32))
                .frame(maxHeight: .infinity)
                .contentShape(Capsule(style: .continuous))
                .onHover { hover in
                    withAnimation(.easeOut(duration: 0.15)) { isHovering = hover }
                }
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { gesture in
                            if !isDragging {
                                isDragging = true
                                onScrubbingChanged?(true)
                            }
                            updateVolume(Double(max(0, min(1, gesture.location.x / width))))
                        }
                        .onEnded { _ in
                            isDragging = false
                            onScrubbingChanged?(false)
                        }
                )
                .background(
                    ScrollWheelHandler { delta in
                        let change = Double(delta) * 0.008
                        if abs(change) > 0.0005 {
                            updateVolume(value + change)
                        }
                    }
                )
                .accessibilityLabel("Volume")
                .accessibilityValue(isMuted ? "Muted" : "\(Int((value * 100).rounded())) percent")
                .accessibilityAdjustableAction { direction in
                    switch direction {
                    case .increment: updateVolume(value + 0.05)
                    case .decrement: updateVolume(value - 0.05)
                    @unknown default: break
                    }
                }
            }
            .frame(height: 46)
        }
        .frame(height: 48)
    }

    private func updateVolume(_ proposed: Double) {
        let clamped = max(0, min(1, proposed))
        value = clamped
        onValueChanged?(clamped)
        if clamped > 0 && isMuted {
            isMuted = false
            onMuteChanged?(false)
        }
    }

    private func toggleMute() {
        guard canMute else { return }
        isMuted.toggle()
        onMuteChanged?(isMuted)
    }

    private var speakerIcon: String {
        if isMuted || value <= 0.001 { return "speaker.slash.fill" }
        if value < 0.33 { return "speaker.wave.1.fill" }
        if value < 0.66 { return "speaker.wave.2.fill" }
        return "speaker.wave.3.fill"
    }
}

private struct ScrollWheelHandler: NSViewRepresentable {
    var onScroll: (CGFloat) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = Catcher()
        view.onScroll = onScroll
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {
        (view as? Catcher)?.onScroll = onScroll
    }

    private final class Catcher: NSView {
        var onScroll: ((CGFloat) -> Void)?

        override func scrollWheel(with event: NSEvent) {
            let delta = event.hasPreciseScrollingDeltas
                ? event.scrollingDeltaY * 0.25
                : event.scrollingDeltaY
            onScroll?(delta)
        }
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
    }
}
