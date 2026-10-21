//
//  MixSnapshot.swift
//  Capsule
//
//  Two small value types with no AppKit dependencies, so they can be unit
//  tested directly: a saved mix, and per-output-device master volume memory.
//

import Foundation

/// A named, recallable mix: the per-app levels and mute states at a moment.
struct MixSnapshot: Codable, Identifiable, Equatable {

    var id: UUID
    var name: String
    var createdAt: Date
    var levels: [String: VolumeStore.Level]

    init(
        id: UUID = UUID(),
        name: String,
        createdAt: Date = Date(),
        levels: [String: VolumeStore.Level] = [:]
    ) {
        self.id = id
        self.name = MixSnapshot.normalize(name)
        self.createdAt = createdAt
        self.levels = levels
    }

    var appCount: Int { levels.count }

    /// Trims whitespace and falls back to a timestamp so a snapshot is never
    /// stored under an empty name.
    static func normalize(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return fallbackName() }
        return trimmed
    }

    static func fallbackName(date: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return "Mix \(formatter.string(from: date))"
    }
}

/// Remembers the master volume per output device, so plugging in headphones
/// does not blast you at the level your speakers were at.
struct DeviceVolumeMemory: Codable, Equatable {

    private var levels: [String: Double] = [:]

    init() {}

    mutating func remember(_ volume: Double, for deviceName: String) {
        levels[deviceName] = min(max(volume, 0), 1)
    }

    func volume(for deviceName: String) -> Double? {
        levels[deviceName]
    }

    var deviceNames: [String] {
        levels.keys.sorted()
    }

    var isEmpty: Bool { levels.isEmpty }
}
