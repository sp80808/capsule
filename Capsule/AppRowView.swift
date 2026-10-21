//
//  AppRowView.swift
//  Capsule
//
//  One app card in the mixer: icon, name, live level meter, mute button,
//  pill slider — and the right-click context menu that jumps the menu bar
//  mixer to this app or silences everything else.
//

import AppKit
import SwiftUI

struct AppRowView: View {

    @ObservedObject var app: AudioApp
    @ObservedObject var manager: AudioManager

    @State private var isFlashing = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var motionAllowed: Bool { !reduceMotion }

    private var isFocused: Bool { manager.focusedAppID == app.id }
    private var isSoloed: Bool { manager.soloedAppID == app.id }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            slider
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: CapsuleTheme.cardCornerRadius)
                .fill(CapsuleTheme.cardFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: CapsuleTheme.cardCornerRadius)
                .strokeBorder(isFocused ? CapsuleTheme.focusRing : CapsuleTheme.cardBorder, lineWidth: isFocused ? 2 : 1)
        )
        .scaleEffect(isFlashing ? 1.015 : 1)
        .animation(
            motionAllowed ? .spring(response: 0.35, dampingFraction: 0.7) : nil,
            value: isFlashing
        )
        .onChange(of: manager.focusToken) { _ in flashIfFocused() }
        .appContextMenu(app: app, manager: manager)
        .accessibilityElement(children: .contain)
    }

    // MARK: - Pieces

    private var header: some View {
        HStack(spacing: 12) {
            icon

            VStack(alignment: .leading, spacing: 3) {
                Text(app.name)
                    .font(.headline)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    LevelMeter(level: app.isPlaying ? app.level : 0)
                    Text(statusText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            muteButton

            Text("\(app.percent)%")
                .font(.system(.body, design: .rounded))
                .fontWeight(.medium)
                .foregroundColor(.secondary)
                .monospacedDigit()
                .frame(width: 44, alignment: .trailing)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            // Selecting a row makes it the target of ⌘M / ⌥⌘M / ⌥↑ / ⌥↓.
            manager.requestFocus(app.id)
        }
        .help("Right-click for more actions")
    }

    private var slider: some View {
        PillSlider(
            value: Binding(
                get: { app.volume },
                set: { manager.setVolume($0, for: app) }
            ),
            isMuted: Binding(
                get: { app.isMuted },
                set: { manager.setMuted($0, for: app) }
            ),
            accessibilityName: app.name
        )
        // The slider covers the bottom of the card; give it the same menu so a
        // right-click anywhere on the card behaves identically.
        .appContextMenu(app: app, manager: manager)
    }

    @ViewBuilder
    private var icon: some View {
        Group {
            if let nsImage = app.icon {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                Image(systemName: app.symbolName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
            }
        }
        .frame(width: 32, height: 32)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(app.icon == nil ? AnyShapeStyle(CapsuleTheme.fillGradient) : AnyShapeStyle(Color.clear))
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var muteButton: some View {
        Button {
            manager.toggleMute(app)
        } label: {
            Image(systemName: app.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(app.isMuted ? .red : .secondary)
                .frame(width: 24, height: 24)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(app.isMuted ? "Unmute \(app.name)  ⌘M" : "Mute \(app.name)  ⌘M")
    }

    private var statusText: String {
        if isSoloed { return "Soloed" }
        if app.isMuted {
            if let countdown = manager.countdownText(app) {
                return "Muted · \(countdown) left"
            }
            return "Muted"
        }
        if app.volume <= 0.001 { return "Off" }
        return app.isPlaying ? "Playing" : "Idle"
    }

    private func flashIfFocused() {
        guard isFocused else { return }
        isFlashing = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            isFlashing = false
        }
    }
}

// MARK: - Context menu

extension View {
    /// Right-click menu shared by the card and its slider.
    func appContextMenu(app: AudioApp, manager: AudioManager) -> some View {
        contextMenu {
            AppContextMenu(app: app, manager: manager)
        }
    }
}

struct AppContextMenu: View {

    @ObservedObject var app: AudioApp
    @ObservedObject var manager: AudioManager

    var body: some View {
        // Jump the menu bar mixer to this app.
        Button {
            MixerPresenter.shared.showMixer(focusing: app)
        } label: {
            Label("Show in Menu Bar Mixer", systemImage: "menubar.rectangle")
        }
        .keyboardShortcut("o", modifiers: [.command, .shift])

        Button {
            MixerPresenter.shared.showMixerWindow(focusing: app)
        } label: {
            Label("Open in Capsule Window", systemImage: "macwindow")
        }

        Divider()

        Button {
            manager.toggleMute(app)
        } label: {
            Label(
                app.isMuted ? "Unmute \(app.name)" : "Mute \(app.name)",
                systemImage: app.isMuted ? "speaker.wave.2.fill" : "speaker.slash.fill"
            )
        }
        .keyboardShortcut("m", modifiers: .command)

        Button {
            manager.toggleSolo(app)
        } label: {
            Label(
                manager.soloedAppID == app.id ? "Restore Other Apps" : "Mute All Others",
                systemImage: "speaker.wave.1.fill"
            )
        }
        .keyboardShortcut("m", modifiers: [.command, .option])
        .disabled(manager.apps.count < 2)

        Button {
            manager.unmuteAll()
        } label: {
            Label("Unmute All Apps", systemImage: "speaker.wave.3.fill")
        }
        .keyboardShortcut("m", modifiers: [.command, .shift])

        Divider()

        Menu("Mute for") {
            ForEach([5, 15, 30, 60], id: \.self) { minutes in
                Button {
                    manager.mute(app, forMinutes: Double(minutes))
                } label: {
                    Text(minutes == 60 ? "1 hour" : "\(minutes) minutes")
                }
            }

            if manager.hasTimedMute(app) {
                Divider()

                Button {
                    manager.cancelTimedMute(app)
                } label: {
                    Label("Cancel Timed Mute", systemImage: "timer")
                }
            }
        }

        Divider()

        Menu("Set Volume") {
            ForEach([0, 10, 25, 50, 75, 100], id: \.self) { percent in
                Button {
                    manager.setVolume(Double(percent) / 100, for: app)
                } label: {
                    if app.percent == percent {
                        Text("\(percent)%  ✓")
                    } else {
                        Text("\(percent)%")
                    }
                }
            }
        }

        Divider()

        Button {
            manager.activate(app)
        } label: {
            Label("Activate \(app.name)", systemImage: "arrow.up.forward.app")
        }
        .disabled(app.processIdentifier == 0)

        Button {
            manager.toggleHidden(app)
        } label: {
            Label(
                manager.isHidden(app) ? "Show in Capsule" : "Hide from Capsule",
                systemImage: manager.isHidden(app) ? "eye" : "eye.slash"
            )
        }

        Button {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(app.name, forType: .string)
        } label: {
            Label("Copy Name", systemImage: "doc.on.doc")
        }
    }
}

// MARK: - Level meter

/// Four-segment playback meter. Sits next to the "Playing"/"Idle" caption.
struct LevelMeter: View {

    var level: Double

    private let segments = 4

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<segments, id: \.self) { index in
                Capsule()
                    .fill(index < litSegments ? CapsuleTheme.accent : Color.primary.opacity(0.18))
                    .frame(width: 3, height: 9)
            }
        }
        .animation(.easeOut(duration: 0.15), value: litSegments)
        .accessibilityHidden(true)
    }

    private var litSegments: Int {
        guard level > 0.02 else { return 0 }
        return min(segments, Int((level * Double(segments)).rounded(.up)))
    }
}
