//
//  Theme.swift
//  Capsule
//
//  Shared visual constants. Every colour here adapts to the user's appearance
//  (the original design hard-coded white overlays, which disappeared in Light
//  Mode).
//

import SwiftUI

enum CapsuleTheme {
    /// Corner radius used by app cards.
    static let cardCornerRadius: CGFloat = 16

    /// Vertical gap between app cards.
    static let cardSpacing: CGFloat = 14

    /// Horizontal inset of the mixer content.
    static let gutter: CGFloat = 16

    /// Blue → purple brand gradient, used for slider fills and the focus ring.
    static let fillGradient = LinearGradient(
        colors: [
            Color(red: 0.24, green: 0.55, blue: 1.00),
            Color(red: 0.62, green: 0.36, blue: 0.98)
        ],
        startPoint: .leading,
        endPoint: .trailing
    )

    /// Empty part of a slider track.
    static var track: Color { Color.primary.opacity(0.10) }

    /// Card background — subtle in both appearances.
    static var cardFill: Color { Color.primary.opacity(0.05) }

    /// Card hairline border.
    static var cardBorder: Color { Color.primary.opacity(0.10) }

    /// Slider handle. Inverts with the appearance so it always contrasts with
    /// the frosted material behind it.
    static var handle: Color { Color(nsColor: .textColor) }

    /// Glyph drawn inside the slider handle (inverse of `handle`).
    static var handleGlyph: Color { Color(nsColor: .windowBackgroundColor) }

    /// Accent used for the selection/focus ring and level meters.
    static var accent: Color { Color(red: 0.35, green: 0.55, blue: 1.00) }

    /// Colour of the ring drawn around the app that keyboard shortcuts act on.
    static var focusRing: Color { accent.opacity(0.9) }
}

/// Frosted glass background — the native `NSVisualEffectView` material.
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
