# Capsule Code Documentation

## Developer Guide

This document provides in-depth code examples and architectural guidance for working with Capsule's audio engine and eqMac driver integration.

---

## Audio Engine Architecture

### Overview

Capsule's audio engine is built around Apple's `AVAudioEngine` class, which provides a modular, node-based architecture for audio processing. Each audio source, effect, or output is represented as a node in the graph, connected via audio buses.

```swift
import AVFoundation
import CoreAudio

/// The main audio processing engine for Capsule
/// Manages audio routing, mixing, and effects processing
class CapsuleAudioEngine {
    // MARK: - Properties
    
    /// The underlying AVAudioEngine instance
    private let engine: AVAudioEngine
    
    /// Main mixer node for combining multiple audio sources
    private let mainMixer: AVAudioMixerNode
    
    /// Format for audio processing (stereo, 44.1kHz or 48kHz)
    private var processingFormat: AVAudioFormat?
    
    // MARK: - Initialisation
    
    init() {
        self.engine = AVAudioEngine()
        self.mainMixer = AVAudioMixerNode()
        
        // Attach the main mixer to the engine
        engine.attach(mainMixer)
        
        // Connect mixer to output
        engine.connect(mainMixer, 
                      to: engine.mainMixerNode, 
                      format: nil)
        
        configureAudioSession()
    }
    
    // MARK: - Audio Session Configuration
    
    /// Configures the audio session for optimal performance
    /// Uses the eqMac virtual device when available
    private func configureAudioSession() {
        // Set up the audio format based on hardware capabilities
        let inputNode = engine.inputNode
        let hardwareSampleRate = inputNode.outputFormat(forBus: 0).sampleRate
        
        processingFormat = AVAudioFormat(
            standardFormatWithSampleRate: hardwareSampleRate,
            channels: 2
        )
    }
}
```

---

## Working with the eqMac Driver

### Understanding the Driver Architecture

The eqMac driver is a System Audio Server Plug-in that operates in user space. It creates a virtual audio device that can capture system audio and make it available to applications like Capsule.

#### Key Characteristics:

- **User Space**: Runs as a standard process, not a kernel extension
- **Low Latency**: Optimised for real-time audio processing
- **Secure Memory Tunnel**: Audio data is passed through protected memory regions
- **Standard Core Audio API**: Integrates seamlessly with existing audio code

### Detecting the eqMac Driver

```swift
import CoreAudio

/// Discovers audio devices and locates the eqMac virtual device
class AudioDeviceDiscovery {
    
    /// Represents an audio device in the system
    struct AudioDevice {
        let id: AudioDeviceID
        let name: String
        let manufacturer: String
        let isInput: Bool
        let isOutput: Bool
    }
    
    /// Retrieves all audio devices in the system
    /// - Returns: Array of AudioDevice objects
    static func getAllDevices() -> [AudioDevice] {
        var devices: [AudioDevice] = []
        
        // Get the property address for all devices
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        var dataSize: UInt32 = 0
        var status = AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &dataSize
        )
        
        guard status == noErr else { return devices }
        
        let deviceCount = Int(dataSize) / MemoryLayout<AudioDeviceID>.size
        var deviceIDs = [AudioDeviceID](repeating: 0, count: deviceCount)
        
        status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &dataSize,
            &deviceIDs
        )
        
        guard status == noErr else { return devices }
        
        // Enumerate each device and collect information
        for deviceID in deviceIDs {
            if let device = getDeviceInfo(for: deviceID) {
                devices.append(device)
            }
        }
        
        return devices
    }
    
    /// Finds the eqMac virtual device
    /// - Returns: The eqMac device if found, nil otherwise
    static func findEqMacDevice() -> AudioDevice? {
        let devices = getAllDevices()
        return devices.first { device in
            device.name.lowercased().contains("eqmac") ||
            device.manufacturer.lowercased().contains("eqmac")
        }
    }
    
    /// Retrieves detailed information for a specific device
    /// - Parameter deviceID: The device identifier
    /// - Returns: AudioDevice object if successful
    private static func getDeviceInfo(for deviceID: AudioDeviceID) -> AudioDevice? {
        // Get device name
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceName,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        var deviceName: CFString = "" as CFString
        var dataSize = UInt32(MemoryLayout<CFString>.size)
        
        var status = AudioObjectGetPropertyData(
            deviceID,
            &propertyAddress,
            0,
            nil,
            &dataSize,
            &deviceName
        )
        
        guard status == noErr else { return nil }
        
        // Get manufacturer
        propertyAddress.mSelector = kAudioDevicePropertyDeviceManufacturer
        var manufacturer: CFString = "" as CFString
        dataSize = UInt32(MemoryLayout<CFString>.size)
        
        status = AudioObjectGetPropertyData(
            deviceID,
            &propertyAddress,
            0,
            nil,
            &dataSize,
            &manufacturer
        )
        
        let manufacturerName = status == noErr ? manufacturer as String : ""
        
        // Check if device supports input/output
        let hasInput = hasStreams(for: deviceID, scope: kAudioDevicePropertyScopeInput)
        let hasOutput = hasStreams(for: deviceID, scope: kAudioDevicePropertyScopeOutput)
        
        return AudioDevice(
            id: deviceID,
            name: deviceName as String,
            manufacturer: manufacturerName,
            isInput: hasInput,
            isOutput: hasOutput
        )
    }
    
    /// Checks if a device has streams in the specified scope
    private static func hasStreams(for deviceID: AudioDeviceID, scope: AudioObjectPropertyScope) -> Bool {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreams,
            mScope: scope,
            mElement: kAudioObjectPropertyElementMain
        )
        
        var dataSize: UInt32 = 0
        let status = AudioObjectGetPropertyDataSize(
            deviceID,
            &propertyAddress,
            0,
            nil,
            &dataSize
        )
        
        return status == noErr && dataSize > 0
    }
}
```

### Setting the eqMac Device as System Default

```swift
import CoreAudio

/// Manages system audio device configuration
class AudioDeviceManager {
    
    /// Sets the specified device as the system default output
    /// - Parameter deviceID: The audio device identifier
    /// - Returns: True if successful, false otherwise
    static func setDefaultOutputDevice(_ deviceID: AudioDeviceID) -> Bool {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        var deviceIDCopy = deviceID
        let dataSize = UInt32(MemoryLayout<AudioDeviceID>.size)
        
        let status = AudioObjectSetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            dataSize,
            &deviceIDCopy
        )
        
        return status == noErr
    }
    
    /// Sets the eqMac device as the default output
    /// - Returns: True if successful, false if eqMac device not found
    static func setEqMacAsDefaultOutput() -> Bool {
        guard let eqMacDevice = AudioDeviceDiscovery.findEqMacDevice(),
              eqMacDevice.isOutput else {
            print("❌ eqMac device not found or doesn't support output")
            return false
        }
        
        let success = setDefaultOutputDevice(eqMacDevice.id)
        
        if success {
            print("✅ Successfully set eqMac as default output device")
        } else {
            print("❌ Failed to set eqMac as default output device")
        }
        
        return success
    }
}
```

---

## Audio Stream Processing

### Real-Time Audio Tap

Tapping into an audio stream allows you to access raw audio data for analysis, recording, or processing:

```swift
import AVFoundation

/// Processes audio streams in real-time
class AudioStreamProcessor {
    
    private let audioEngine: AVAudioEngine
    private var audioTap: AVAudioNode?
    
    /// Callback type for audio buffer processing
    typealias AudioBufferCallback = (AVAudioPCMBuffer, AVAudioTime) -> Void
    
    init() {
        self.audioEngine = AVAudioEngine()
    }
    
    /// Installs a tap on the input node to process audio buffers
    /// - Parameters:
    ///   - bufferSize: Size of the buffer (typically 4096 or 8192)
    ///   - callback: Closure called for each audio buffer
    func installInputTap(bufferSize: AVAudioFrameCount = 4096, 
                        callback: @escaping AudioBufferCallback) throws {
        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        
        // Remove any existing tap
        inputNode.removeTap(onBus: 0)
        
        // Install new tap
        inputNode.installTap(onBus: 0, 
                           bufferSize: bufferSize, 
                           format: format,
                           block: callback)
        
        // Start the engine if not already running
        if !audioEngine.isRunning {
            try audioEngine.start()
        }
    }
    
    /// Example: Calculate average amplitude (volume level)
    func startVolumeMonitoring() throws {
        try installInputTap { buffer, time in
            // Get audio data as float samples
            guard let channelData = buffer.floatChannelData else { return }
            let frameLength = Int(buffer.frameLength)
            
            // Calculate RMS (Root Mean Square) amplitude
            var sum: Float = 0.0
            let channelCount = Int(buffer.format.channelCount)
            
            for channel in 0..<channelCount {
                let samples = channelData[channel]
                for frame in 0..<frameLength {
                    let sample = samples[frame]
                    sum += sample * sample
                }
            }
            
            let rms = sqrt(sum / Float(frameLength * channelCount))
            
            // Convert to decibels
            let db = 20 * log10(rms)
            
            // Post notification with volume level
            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: NSNotification.Name("AudioVolumeUpdate"),
                    object: db
                )
            }
        }
    }
    
    /// Stops audio processing and removes taps
    func stop() {
        audioEngine.inputNode.removeTap(onBus: 0)
        if audioEngine.isRunning {
            audioEngine.stop()
        }
    }
}
```

### Audio Effects Processing

```swift
import AVFoundation

/// Provides various audio effects and DSP operations
class AudioEffectsProcessor {
    
    private let audioEngine: AVAudioEngine
    private let playerNode: AVAudioPlayerNode
    private let eqNode: AVAudioUnitEQ
    private let reverbNode: AVAudioUnitReverb
    
    init() {
        self.audioEngine = AVAudioEngine()
        self.playerNode = AVAudioPlayerNode()
        
        // Create EQ with 10 bands
        self.eqNode = AVAudioUnitEQ(numberOfBands: 10)
        
        // Create reverb effect
        self.reverbNode = AVAudioUnitReverb()
        
        setupAudioGraph()
    }
    
    /// Sets up the audio processing graph
    private func setupAudioGraph() {
        // Attach nodes to the engine
        audioEngine.attach(playerNode)
        audioEngine.attach(eqNode)
        audioEngine.attach(reverbNode)
        
        // Connect nodes: player → EQ → reverb → output
        audioEngine.connect(playerNode, to: eqNode, format: nil)
        audioEngine.connect(eqNode, to: reverbNode, format: nil)
        audioEngine.connect(reverbNode, to: audioEngine.mainMixerNode, format: nil)
    }
    
    /// Configures the equaliser with specific frequency bands
    func configureEqualiser() {
        // Define standard 10-band EQ frequencies (Hz)
        let frequencies: [Float] = [32, 64, 125, 250, 500, 1000, 2000, 4000, 8000, 16000]
        
        for (index, frequency) in frequencies.enumerated() {
            let band = eqNode.bands[index]
            band.frequency = frequency
            band.bandwidth = 1.0  // One octave
            band.bypass = false
            band.filterType = .parametric
            band.gain = 0.0  // Neutral position
        }
        
        eqNode.globalGain = 0.0
    }
    
    /// Sets the gain for a specific EQ band
    /// - Parameters:
    ///   - bandIndex: Index of the band (0-9)
    ///   - gainDB: Gain in decibels (-96 to +24)
    func setEQBandGain(_ bandIndex: Int, gainDB: Float) {
        guard bandIndex >= 0 && bandIndex < eqNode.bands.count else { return }
        
        let clampedGain = max(-96.0, min(24.0, gainDB))
        eqNode.bands[bandIndex].gain = clampedGain
    }
    
    /// Configures reverb settings
    /// - Parameter preset: Reverb preset type
    func setReverbPreset(_ preset: AVAudioUnitReverbPreset) {
        reverbNode.loadFactoryPreset(preset)
        reverbNode.wetDryMix = 20  // 20% wet, 80% dry
    }
    
    /// Starts audio processing
    func start() throws {
        try audioEngine.start()
        playerNode.play()
    }
}
```

---

## Multi-Channel Mixing

### Creating a Multi-Track Mixer

```swift
import AVFoundation

/// A multi-track audio mixer supporting multiple simultaneous sources
class MultiTrackMixer {
    
    /// Represents a single audio track in the mixer
    class Track {
        let player: AVAudioPlayerNode
        var volume: Float = 1.0
        var pan: Float = 0.0  // -1.0 (left) to 1.0 (right)
        var isMuted: Bool = false
        var isSoloed: Bool = false
        
        init() {
            self.player = AVAudioPlayerNode()
        }
    }
    
    private let audioEngine: AVAudioEngine
    private let mainMixer: AVAudioMixerNode
    private var tracks: [Track] = []
    private var hasSoloedTracks: Bool {
        tracks.contains { $0.isSoloed }
    }
    
    init() {
        self.audioEngine = AVAudioEngine()
        self.mainMixer = audioEngine.mainMixerNode
    }
    
    /// Adds a new track to the mixer
    /// - Returns: The index of the newly created track
    @discardableResult
    func addTrack() -> Int {
        let track = Track()
        
        // Attach player to engine
        audioEngine.attach(track.player)
        
        // Connect to main mixer
        audioEngine.connect(track.player, to: mainMixer, format: nil)
        
        tracks.append(track)
        return tracks.count - 1
    }
    
    /// Loads an audio file into a specific track
    /// - Parameters:
    ///   - fileURL: URL of the audio file
    ///   - trackIndex: Index of the track to load into
    func loadAudioFile(_ fileURL: URL, into trackIndex: Int) throws {
        guard trackIndex < tracks.count else {
            throw NSError(domain: "MultiTrackMixer", 
                         code: -1, 
                         userInfo: [NSLocalizedDescriptionKey: "Invalid track index"])
        }
        
        let track = tracks[trackIndex]
        let audioFile = try AVAudioFile(forReading: fileURL)
        
        track.player.scheduleFile(audioFile, at: nil)
    }
    
    /// Sets the volume for a specific track
    /// - Parameters:
    ///   - volume: Volume level (0.0 to 1.0)
    ///   - trackIndex: Index of the track
    func setVolume(_ volume: Float, for trackIndex: Int) {
        guard trackIndex < tracks.count else { return }
        
        let track = tracks[trackIndex]
        track.volume = max(0.0, min(1.0, volume))
        updateTrackPlayback(track)
    }
    
    /// Sets the pan position for a specific track
    /// - Parameters:
    ///   - pan: Pan position (-1.0 left to 1.0 right)
    ///   - trackIndex: Index of the track
    func setPan(_ pan: Float, for trackIndex: Int) {
        guard trackIndex < tracks.count else { return }
        
        let track = tracks[trackIndex]
        track.pan = max(-1.0, min(1.0, pan))
        updateTrackPlayback(track)
    }
    
    /// Mutes or unmutes a track
    func setMuted(_ muted: Bool, for trackIndex: Int) {
        guard trackIndex < tracks.count else { return }
        
        let track = tracks[trackIndex]
        track.isMuted = muted
        updateTrackPlayback(track)
    }
    
    /// Solos a track (mutes all other non-soloed tracks)
    func setSoloed(_ soloed: Bool, for trackIndex: Int) {
        guard trackIndex < tracks.count else { return }
        
        let track = tracks[trackIndex]
        track.isSoloed = soloed
        
        // Update all tracks to reflect solo state
        for t in tracks {
            updateTrackPlayback(t)
        }
    }
    
    /// Updates the actual playback parameters for a track
    private func updateTrackPlayback(_ track: Track) {
        // Determine if this track should be audible
        let shouldPlay = !track.isMuted && (!hasSoloedTracks || track.isSoloed)
        let effectiveVolume = shouldPlay ? track.volume : 0.0
        
        track.player.volume = effectiveVolume
        track.player.pan = track.pan
    }
    
    /// Starts playback of all tracks
    func play() throws {
        if !audioEngine.isRunning {
            try audioEngine.start()
        }
        
        for track in tracks {
            if !track.player.isPlaying {
                track.player.play()
            }
        }
    }
    
    /// Stops playback of all tracks
    func stop() {
        for track in tracks {
            track.player.stop()
        }
    }
}
```

---

## Performance Optimisation

### Buffer Management

For optimal performance, buffer sizes should be carefully chosen:

- **Small buffers (512-1024 frames)**: Lower latency, higher CPU usage
- **Medium buffers (2048-4096 frames)**: Balanced performance
- **Large buffers (8192+ frames)**: Higher latency, lower CPU usage

```swift
/// Adaptive buffer size selection based on system load
class BufferSizeManager {
    
    enum PerformanceMode {
        case lowLatency    // For live performance (512-1024)
        case balanced      // For general use (2048-4096)
        case powerSaving   // For background processing (8192+)
    }
    
    static func recommendedBufferSize(for mode: PerformanceMode) -> AVAudioFrameCount {
        switch mode {
        case .lowLatency:
            return 1024
        case .balanced:
            return 4096
        case .powerSaving:
            return 8192
        }
    }
}
```

### Memory Management

Always clean up audio resources properly:

```swift
class AudioResourceManager {
    
    /// Safely tears down an audio engine
    static func cleanupAudioEngine(_ engine: AVAudioEngine) {
        // Stop the engine
        if engine.isRunning {
            engine.stop()
        }
        
        // Remove all taps
        engine.inputNode.removeTap(onBus: 0)
        
        // Disconnect all nodes
        for node in engine.attachedNodes {
            engine.disconnectNodeOutput(node)
        }
        
        // Detach all nodes
        for node in engine.attachedNodes {
            if node != engine.inputNode && 
               node != engine.outputNode && 
               node != engine.mainMixerNode {
                engine.detach(node)
            }
        }
    }
}
```

---

## Error Handling

### Robust Audio Session Management

```swift
import AVFoundation

enum AudioEngineError: Error {
    case engineNotStarted
    case deviceNotFound
    case configurationFailed(String)
    case audioFileError(Error)
}

class RobustAudioEngine {
    
    private let engine: AVAudioEngine
    
    init() {
        self.engine = AVAudioEngine()
        setupNotifications()
    }
    
    /// Sets up notifications for audio interruptions and route changes
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleInterruption),
            name: AVAudioSession.interruptionNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRouteChange),
            name: AVAudioSession.routeChangeNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleEngineConfigurationChange),
            name: .AVAudioEngineConfigurationChange,
            object: engine
        )
    }
    
    /// Handles audio interruptions (phone calls, alerts, etc.)
    @objc private func handleInterruption(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }
        
        switch type {
        case .began:
            // Interruption began, pause audio
            engine.pause()
            
        case .ended:
            // Interruption ended, resume audio if appropriate
            if let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt {
                let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                if options.contains(.shouldResume) {
                    do {
                        try engine.start()
                    } catch {
                        print("Failed to restart engine after interruption: \(error)")
                    }
                }
            }
            
        @unknown default:
            break
        }
    }
    
    /// Handles audio route changes (headphones plugged in/out, etc.)
    @objc private func handleRouteChange(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else {
            return
        }
        
        switch reason {
        case .newDeviceAvailable:
            print("New audio device connected")
            
        case .oldDeviceUnavailable:
            print("Audio device disconnected")
            // Pause playback when headphones are removed
            engine.pause()
            
        default:
            break
        }
    }
    
    /// Handles audio engine configuration changes
    @objc private func handleEngineConfigurationChange(notification: Notification) {
        print("Audio engine configuration changed, reinitialising...")
        
        // Stop and restart the engine with new configuration
        if engine.isRunning {
            engine.stop()
            do {
                try engine.start()
            } catch {
                print("Failed to restart engine: \(error)")
            }
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
```

---

## Testing and Debugging

### Audio Level Monitoring

```swift
import AVFoundation

/// Utility for monitoring audio levels during development
class AudioLevelMonitor {
    
    private var engine: AVAudioEngine?
    
    /// Starts monitoring audio input levels
    /// Prints peak and RMS values every second
    func startMonitoring() {
        engine = AVAudioEngine()
        guard let engine = engine else { return }
        
        let inputNode = engine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        
        inputNode.installTap(onBus: 0, 
                           bufferSize: 4096, 
                           format: format) { buffer, time in
            self.analyseBuffer(buffer)
        }
        
        do {
            try engine.start()
            print("✅ Audio monitoring started")
        } catch {
            print("❌ Failed to start monitoring: \(error)")
        }
    }
    
    /// Analyses an audio buffer and prints statistics
    private func analyseBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData else { return }
        
        let frameLength = Int(buffer.frameLength)
        let channelCount = Int(buffer.format.channelCount)
        
        var peak: Float = 0.0
        var sumSquares: Float = 0.0
        
        for channel in 0..<channelCount {
            let samples = channelData[channel]
            for frame in 0..<frameLength {
                let sample = abs(samples[frame])
                peak = max(peak, sample)
                sumSquares += sample * sample
            }
        }
        
        let rms = sqrt(sumSquares / Float(frameLength * channelCount))
        let peakDB = 20 * log10(peak + 1e-10)
        let rmsDB = 20 * log10(rms + 1e-10)
        
        print("📊 Peak: \(String(format: "%.1f", peakDB)) dB | RMS: \(String(format: "%.1f", rmsDB)) dB")
    }
    
    func stopMonitoring() {
        engine?.inputNode.removeTap(onBus: 0)
        engine?.stop()
        engine = nil
        print("⏹ Audio monitoring stopped")
    }
}
```

---

## Best Practices

### 1. Always Handle Audio Interruptions

iOS and macOS applications can be interrupted by phone calls, alarms, or other system events. Always implement interruption handling.

### 2. Use Appropriate Buffer Sizes

Choose buffer sizes based on your use case. Smaller buffers reduce latency but increase CPU usage.

### 3. Clean Up Resources

Always remove audio taps, stop the engine, and disconnect nodes when finished to prevent memory leaks.

### 4. Test with Multiple Devices

Test your audio code with different audio devices, including the eqMac virtual device, physical audio interfaces, and built-in speakers.

### 5. Monitor Performance

Use Instruments to profile your audio code and identify bottlenecks. Audio processing should stay well below real-time limits.

### 6. Handle Sample Rate Changes

Audio devices may have different sample rates. Always query the actual hardware sample rate and configure your audio format accordingly.

---

## Additional Resources

- [Core Audio Overview](https://developer.apple.com/library/archive/documentation/MusicAudio/Conceptual/CoreAudioOverview/)
- [AVAudioEngine Documentation](https://developer.apple.com/documentation/avfaudio/avaudioengine)
- [eqMac GitHub Repository](https://github.com/bitgapp/eqMac)
- [Audio Unit Programming Guide](https://developer.apple.com/library/archive/documentation/MusicAudio/Conceptual/AudioUnitProgrammingGuide/)

---

*This documentation is maintained as part of the Capsule project. For questions or contributions, please open an issue on GitHub.*
