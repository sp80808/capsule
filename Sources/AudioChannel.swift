import Foundation

struct AudioChannel: Identifiable {
    let id = UUID()
    var name: String
    var icon: String
    var volume: Double
    var isMuted: Bool
    var color: String
}

class AudioChannels: ObservableObject {
    @Published var channels: [AudioChannel] = [
        AudioChannel(name: "System", icon: "speaker.wave.3.fill", volume: 75, isMuted: false, color: "blue"),
        AudioChannel(name: "Music", icon: "music.note", volume: 60, isMuted: false, color: "pink"),
        AudioChannel(name: "Browser", icon: "globe", volume: 50, isMuted: false, color: "purple"),
        AudioChannel(name: "Comms", icon: "mic.fill", volume: 80, isMuted: false, color: "green"),
        AudioChannel(name: "Games", icon: "gamecontroller.fill", volume: 90, isMuted: false, color: "orange"),
    ]
}
