# Capsule

### A Native Audio Mixer for macOS

Capsule reimagines audio routing on the Mac. Built from the ground up to integrate seamlessly with the eqMac driver ecosystem, it delivers a sophisticated yet effortless experience for mixing, routing, and processing system audio streams.

---

## What Makes It Special

### Native Experience
Capsule is designed exclusively for macOS, utilising Apple's Core Audio framework to deliver pristine audio quality with minimal latency. Unlike cross-platform alternatives, every interaction feels distinctly Mac-like—from the intuitive interface to the deep system integration.

### Effortless eqMac Integration
Leveraging the power of the eqMac virtual audio driver, Capsule taps directly into your system's audio pipeline. This means you can route, mix, and process audio from any application without cumbersome workarounds or third-party plugins. The eqMac driver acts as a secure bridge between your applications and Capsule, capturing audio in real-time whilst maintaining the integrity of your original signal.

### Developer-Friendly Architecture
Whether you're building audio applications or integrating virtual audio streams into your workflow, Capsule provides clean APIs and straightforward access to the underlying audio engine. Hook into the virtual audio stream with just a few lines of code.

---

## How It Works

Capsule works in harmony with the eqMac driver to create a complete audio routing solution:

1. **Audio Capture**: The eqMac driver, a macOS System Audio Server Plug-in, captures system-wide audio in user space (not kernel space), ensuring security and stability.

2. **Stream Processing**: Captured audio is passed to Capsule through a secure memory tunnel, where you can apply routing, mixing, and effects processing.

3. **Output Management**: Processed audio is then routed to your selected output device—whether that's speakers, headphones, or another virtual destination.

This architecture provides low-latency performance whilst maintaining the highest audio quality standards.

---

## Quick Start

### For Developers

Integrate Capsule into your audio workflow in minutes:

#### Prerequisites
- macOS 11.0 (Big Sur) or later
- eqMac driver installed ([download here](https://github.com/bitgapp/eqMac))
- Xcode 13.0+ (for Swift development)

#### Hooking Into the Virtual Audio Stream

```swift
import CoreAudio
import AVFoundation

// Configure your audio engine
let audioEngine = AVAudioEngine()
let inputNode = audioEngine.inputNode

// Set up the input format to match eqMac's virtual device
let hardwareSampleRate = inputNode.outputFormat(forBus: 0).sampleRate
let inputFormat = AVAudioFormat(standardFormatWithSampleRate: hardwareSampleRate, 
                                 channels: 2)

// Install a tap to access the audio stream
inputNode.installTap(onBus: 0, 
                     bufferSize: 4096, 
                     format: inputFormat) { (buffer, time) in
    // Process your audio buffer here
    // This is where you can mix, analyse, or transform the stream
    processAudioBuffer(buffer)
}

// Start the engine
do {
    try audioEngine.start()
} catch {
    print("Unable to start audio engine: \(error.localizedDescription)")
}
```

#### Selecting the eqMac Virtual Device

To route audio through eqMac's driver programmatically:

```swift
import AVFoundation

func setEqMacAsInput() {
    let session = AVAudioSession.sharedInstance()
    
    // Find the eqMac virtual device
    let availableInputs = AVCaptureDevice.devices(for: .audio)
    
    if let eqMacDevice = availableInputs.first(where: { 
        $0.localizedName.contains("eqMac") 
    }) {
        do {
            try session.setPreferredInput(eqMacDevice)
            try session.setActive(true)
            print("Successfully configured eqMac as input source")
        } catch {
            print("Error setting up audio session: \(error)")
        }
    }
}
```

#### Creating a Simple Audio Mixer

```swift
import AVFoundation

class SimpleMixer {
    private let audioEngine = AVAudioEngine()
    private let mixer = AVAudioMixerNode()
    
    init() {
        audioEngine.attach(mixer)
        
        // Connect mixer to output
        audioEngine.connect(mixer, 
                          to: audioEngine.mainMixerNode, 
                          format: nil)
    }
    
    func addAudioSource(url: URL, volume: Float = 1.0) {
        let player = AVAudioPlayerNode()
        audioEngine.attach(player)
        
        // Connect player to mixer
        audioEngine.connect(player, to: mixer, format: nil)
        
        // Configure audio file and schedule playback
        if let audioFile = try? AVAudioFile(forReading: url) {
            player.scheduleFile(audioFile, at: nil)
            player.volume = volume
            player.play()
        }
    }
    
    func start() throws {
        try audioEngine.start()
    }
}
```

### For Users

1. **Install eqMac**: Download and install the eqMac driver from [bitgapp/eqMac](https://github.com/bitgapp/eqMac)
2. **Configure Virtual Device**: In System Preferences → Sound, select "eqMac" as your output device
3. **Launch Capsule**: Open Capsule to begin routing and mixing your audio streams
4. **Enjoy**: Experience seamless, low-latency audio processing with a truly native Mac experience

---

## Technical Architecture

### Core Components

**Audio Engine**  
Built on `AVAudioEngine` and Core Audio, providing a modern, Swift-native interface to macOS audio processing.

**eqMac Driver Integration**  
Interfaces with the eqMac virtual audio device (System Audio Server Plug-in), which operates in user space for enhanced security. The driver captures system audio and makes it available through standard Core Audio APIs.

**Virtual Routing Layer**  
Manages audio stream routing between sources (applications, system audio, input devices) and destinations (output devices, processing chains, recordings).

**DSP Pipeline**  
Supports real-time audio effects, equalisation, and mixing operations with sample-accurate timing.

### Why User Space Matters

Traditional audio drivers operated in kernel space, which posed security risks and stability concerns. The eqMac driver follows Apple's modern architecture by running as a System Audio Server Plug-in in user space. This means:

- **Enhanced Security**: Driver issues can't compromise the kernel
- **Better Stability**: Crashes are isolated and recoverable
- **Easier Development**: Standard debugging and profiling tools work seamlessly
- **System Integrity**: No kernel extensions required (SIP friendly)

---

## Design Philosophy

Capsule embodies the principle that professional audio tools needn't be complicated. Every feature is purposefully designed to feel intuitive whilst maintaining the depth that audio professionals demand.

The interface follows macOS design guidelines, utilising system fonts, standard controls, and familiar patterns. This isn't just aesthetic—it's functional. When tools feel native, they become extensions of your creative process rather than obstacles in your workflow.

---

## System Requirements

- macOS 11.0 (Big Sur) or later
- eqMac driver installed
- 8GB RAM recommended
- Apple Silicon or Intel processor

---

## Licence

Copyright © 2026. All rights reserved.

---

## Learn More

- [eqMac Project](https://github.com/bitgapp/eqMac) - The driver that powers Capsule's audio capture
- [Core Audio Documentation](https://developer.apple.com/documentation/coreaudio) - Apple's audio framework
- [AVFoundation Guide](https://developer.apple.com/documentation/avfoundation) - Modern audio and video APIs

---

**Capsule**. Native audio mixing, reimagined.
