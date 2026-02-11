# Audio Driver Architecture

## Overview

Capsule requires a virtual audio driver to achieve per-application audio control. This document outlines the architecture for such a driver, similar to eqMac's implementation.

## Driver Architecture

### High-Level Design

```
┌─────────────────────────────────────────────────────────────┐
│                     macOS Audio Stack                       │
├─────────────────────────────────────────────────────────────┤
│  Application Audio  │  Application Audio  │  System Audio   │
│   (Music.app)       │   (Safari.app)      │   (Alerts)      │
└──────────┬──────────┴──────────┬──────────┴────────┬────────┘
           │                     │                    │
           ▼                     ▼                    ▼
    ┌──────────────────────────────────────────────────────┐
    │         Virtual Audio Device (CapsuleAudio)          │
    │  ┌───────────┐  ┌───────────┐  ┌───────────┐       │
    │  │ Process 1 │  │ Process 2 │  │ Process N │       │
    │  │  Volume   │  │  Volume   │  │  Volume   │       │
    │  └─────┬─────┘  └─────┬─────┘  └─────┬─────┘       │
    │        └──────────┬──────────────────┘              │
    │                   ▼                                  │
    │            Audio Mixer Engine                        │
    └──────────────────┬───────────────────────────────────┘
                       │
                       ▼
              ┌─────────────────┐
              │  Hardware Audio │
              │   Output Device │
              └─────────────────┘
```

## Components

### 1. DriverKit Virtual Audio Device

**Purpose**: Create a virtual audio output device that applications can use.

**Implementation**:
- Use DriverKit (modern macOS driver framework)
- Implements `IOAudioDevice` for system integration
- Appears as a selectable audio device in System Preferences
- All audio routed through this device can be intercepted

**Key Classes**:
- `CapsuleAudioDevice`: Main driver class
- `CapsuleAudioEngine`: Audio processing engine
- `CapsuleAudioStream`: Per-process audio stream handler

### 2. Audio Process Identification

**Purpose**: Identify which process is producing audio.

**Implementation**:
```swift
// Pseudo-code for process identification
func identifyAudioSource(audioBuffer: AudioBuffer) -> ProcessInfo {
    // Use CoreAudio's process ID from audio session
    let processID = getAudioSessionProcessID()
    let processInfo = ProcessInfo(processID: processID)
    
    // Get app metadata
    processInfo.name = getProcessName(processID)
    processInfo.bundleID = getBundleIdentifier(processID)
    processInfo.icon = getApplicationIcon(processID)
    
    return processInfo
}
```

**Technologies**:
- `AudioObjectPropertyAddress` with `kAudioHardwarePropertyProcesses`
- NSRunningApplication for process metadata
- Kernel-level PID tracking for accuracy

### 3. Per-Process Volume Control

**Purpose**: Apply volume adjustments to specific application audio streams.

**Implementation**:
```swift
// Pseudo-code for volume application
func processAudioBuffer(
    buffer: AudioBufferList,
    processID: pid_t,
    volumeMultiplier: Float
) -> AudioBufferList {
    guard !isMuted(processID) else {
        return silentBuffer()
    }
    
    let scaledBuffer = applyGain(buffer, gain: volumeMultiplier)
    return scaledBuffer
}
```

**Real-Time Processing**:
- Runs in audio I/O thread (high priority)
- Minimal latency (<10ms)
- Lock-free data structures for thread safety
- SIMD optimisations for volume multiplication

### 4. Audio Mixer

**Purpose**: Combine all processed audio streams into final output.

**Implementation**:
```swift
// Pseudo-code for audio mixing
func mixAudioStreams(streams: [ProcessAudioStream]) -> AudioBuffer {
    var mixedBuffer = createSilentBuffer()
    
    for stream in streams {
        let processedBuffer = processAudioBuffer(
            buffer: stream.buffer,
            processID: stream.processID,
            volumeMultiplier: getVolume(stream.processID)
        )
        
        mixedBuffer = addBuffers(mixedBuffer, processedBuffer)
    }
    
    // Prevent clipping
    return normaliseBuffer(mixedBuffer)
}
```

**Features**:
- 32-bit float processing for quality
- Automatic gain control to prevent clipping
- Support for multiple sample rates
- Channel mapping (stereo, 5.1, etc.)

### 5. IPC (Inter-Process Communication)

**Purpose**: Communication between the UI app and the driver.

**Implementation Options**:

**Option A: XPC Services**
```swift
// User space app → Driver
protocol CapsuleDriverProtocol {
    func setVolume(processID: pid_t, volume: Float)
    func setMute(processID: pid_t, muted: Bool)
    func getActiveProcesses() -> [ProcessInfo]
}
```

**Option B: IOKit User Client**
```swift
// Direct kernel communication
class CapsuleUserClient: IOUserClient {
    func setProcessVolume(processID: pid_t, volume: Float) {
        // Send command to kernel extension
        IOConnectCallScalarMethod(
            connect,
            kSetVolumeSelector,
            [processID, Float32(volume)],
            ...
        )
    }
}
```

## Data Flow

### Setting Volume (User → Driver)

1. User adjusts slider in SwiftUI UI
2. `AppAudioItem.setVolume()` called
3. `AudioManager` sends IPC message to driver
4. Driver updates volume multiplier for process
5. Next audio callback applies new volume
6. Audio output reflects change (<10ms latency)

### Audio Processing (Driver)

1. Application writes audio to virtual device
2. Driver's IOProc callback receives buffer
3. Process ID extracted from audio session
4. Volume multiplier retrieved from lookup table
5. SIMD multiply applied to samples
6. Mixed with other process buffers
7. Output to hardware device

## CoreAudio Integration

### Device Registration

```swift
// Simplified driver initialisation
func registerVirtualDevice() {
    var deviceDescription = AudioDeviceDescription()
    deviceDescription.name = "Capsule Audio"
    deviceDescription.manufacturer = "Capsule"
    deviceDescription.sampleRate = 48000.0
    deviceDescription.channels = 2
    
    AudioObjectCreate(deviceDescription, &deviceID)
}
```

### Audio I/O

```swift
// Audio processing callback
let ioProc: AudioDeviceIOProc = { (
    device,
    now,
    inputData,
    inputTime,
    outputData,
    outputTime,
    clientData
) in
    let driver = Unmanaged<CapsuleDriver>
        .fromOpaque(clientData!)
        .takeUnretainedValue()
    
    driver.processAudio(outputData, outputTime)
    
    return kAudioHardwareNoError
}
```

## Performance Optimisations

### 1. Lock-Free Data Structures

Use atomic operations for volume lookups:
```swift
class VolumeTable {
    private var volumes: [pid_t: Atomic<Float>] = [:]
    
    func getVolume(_ pid: pid_t) -> Float {
        return volumes[pid]?.load(ordering: .relaxed) ?? 1.0
    }
}
```

### 2. SIMD Processing

Vectorised audio processing:
```swift
func applyGain(_ buffer: UnsafeMutablePointer<Float>, 
               count: Int, 
               gain: Float) {
    vDSP_vsmul(buffer, 1, [gain], buffer, 1, vDSP_Length(count))
}
```

### 3. Buffer Reuse

Minimise allocations in audio thread:
```swift
class BufferPool {
    private var freeBuffers: [AudioBuffer] = []
    
    func acquire() -> AudioBuffer {
        return freeBuffers.popLast() ?? allocateNew()
    }
    
    func release(_ buffer: AudioBuffer) {
        freeBuffers.append(buffer)
    }
}
```

## Security Considerations

1. **Code Signing**: Driver must be signed with Apple Developer ID
2. **Notarisation**: Required for distribution outside App Store
3. **SIP Compatibility**: Works with System Integrity Protection enabled
4. **Sandboxing**: Driver runs in restricted environment
5. **Privacy**: No audio data stored or transmitted

## Alternative Approaches

### User-Space Audio Loopback

Instead of a kernel driver, use:
- Virtual audio devices via CoreAudio
- Loopback through user-space process
- Higher latency but easier deployment

### System Extension (DriverKit)

Modern approach:
- No kernel code required
- Better security model
- Easier to distribute
- Supported on macOS 10.15+

## References

- [CoreAudio Programming Guide](https://developer.apple.com/library/archive/documentation/MusicAudio/Conceptual/CoreAudioOverview/)
- [DriverKit Documentation](https://developer.apple.com/documentation/driverkit)
- [Real-Time Audio Programming](https://www.rossbencina.com/code/real-time-audio-programming-101-time-waits-for-nothing)
- [eqMac Implementation](https://github.com/bitgapp/eqMac) - Open source reference

## Implementation Status

Current state: **Foundation implemented**
- ✅ UI and animations complete
- ✅ SwiftUI app structure ready
- ✅ CoreAudio framework integrated
- ⏳ Driver implementation (requires macOS development environment)
- ⏳ IPC between app and driver
- ⏳ Real process audio detection

Next steps: Implement DriverKit extension and establish IPC.
