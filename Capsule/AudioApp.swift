//
//  AudioApp.swift
//  Capsule
//
//  Model for one audio-producing application in the mixer.
//

import AppKit
import Combine
import Foundation

final class AudioApp: ObservableObject, Identifiable, Equatable {

    /// Stable identity — the bundle identifier when the process has one, so the
    /// row keeps its focus, selection and scroll position across refreshes.
    /// (This used to be a fresh `UUID()` on every refresh, which threw all of
    /// that away.)
    let id: String

    let name: String
    let bundleIdentifier: String?
    let processIdentifier: pid_t

    /// SF Symbol used when the app has no icon available.
    let symbolName: String

    @Published var icon: NSImage?
    @Published var volume: Double
    @Published var isMuted: Bool
    @Published var isPlaying: Bool
    /// Normalised 0…1 output level, used by the row's level meter.
    @Published var level: Double

    init(
        id: String,
        name: String,
        bundleIdentifier: String? = nil,
        processIdentifier: pid_t = 0,
        symbolName: String? = nil,
        icon: NSImage? = nil,
        volume: Double = 0.8,
        isMuted: Bool = false,
        isPlaying: Bool = false,
        level: Double = 0
    ) {
        self.id = id
        self.name = name
        self.bundleIdentifier = bundleIdentifier
        self.processIdentifier = processIdentifier
        self.symbolName = symbolName ?? AppSymbol.symbol(forBundleIdentifier: bundleIdentifier, name: name)
        self.icon = icon
        self.volume = Self.clamp(volume)
        self.isMuted = isMuted
        self.isPlaying = isPlaying
        self.level = level
    }

    // MARK: - Derived state

    var percent: Int { Int((volume * 100).rounded()) }

    /// Volume the app is actually heard at.
    var effectiveVolume: Double { isMuted ? 0 : volume }

    /// The app is silenced either explicitly or by sliding to zero.
    var isSilenced: Bool { isMuted || volume <= 0.001 }

    /// True when the process behind this row is still running.
    var isRunning: Bool {
        guard processIdentifier != 0 else { return bundleIdentifier != nil }
        return NSRunningApplication(processIdentifier: processIdentifier) != nil
    }

    static func clamp(_ value: Double) -> Double { min(max(value, 0), 1) }

    // MARK: - Equatable

    static func == (lhs: AudioApp, rhs: AudioApp) -> Bool { lhs.id == rhs.id }
}

// MARK: - Icon fallbacks

/// Maps well-known bundle identifiers onto SF Symbols, used when an app icon
/// cannot be loaded (or in previews).
enum AppSymbol {
    static func symbol(forBundleIdentifier bundleIdentifier: String?, name: String) -> String {
        if let bundleIdentifier, let symbol = table[bundleIdentifier.lowercased()] {
            return symbol
        }
        switch name.lowercased() {
        case let value where value.contains("music"): return "music.note"
        case let value where value.contains("safari"): return "safari.fill"
        case let value where value.contains("chrome"): return "globe"
        case let value where value.contains("zoom"): return "video.fill"
        case let value where value.contains("slack"): return "message.fill"
        case let value where value.contains("terminal"): return "terminal.fill"
        default: return "app.fill"
        }
    }

    private static let table: [String: String] = [
        "com.apple.music": "music.note",
        "com.apple.safari": "safari.fill",
        "com.apple.facetime": "video.fill",
        "com.apple.quicktimeplayerx": "play.rectangle.fill",
        "com.apple.podcasts": "mic.fill",
        "com.apple.tv": "tv.fill",
        "com.apple.mail": "envelope.fill",
        "com.apple.mobilesms": "message.fill",
        "com.apple.photos": "photo.fill",
        "com.apple.dt.xcode": "hammer.fill",
        "com.apple.terminal": "terminal.fill",
        "com.spotify.client": "music.note.list",
        "com.google.chrome": "globe",
        "org.mozilla.firefox": "globe",
        "com.microsoft.edgemac": "globe",
        "com.tinyspeck.slackmacgap": "message.fill",
        "us.zoom.xos": "video.fill",
        "com.hnc.discord": "bubble.left.and.bubble.right.fill",
        "org.videolan.vlc": "play.fill",
        "com.colliderli.iina": "play.fill",
        "com.microsoft.teams": "person.2.fill",
        "com.microsoft.teams2": "person.2.fill",
        "com.obsproject.obs-studio": "dot.radiowaves.left.and.right",
        "com.brave.browser": "globe",
        "com.tencent.xinwechat": "message.fill",
        "net.whatsapp.whatsapp": "message.fill"
    ]
}
