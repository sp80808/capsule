# Core Audio Integration Guide

## Overview

Capsule uses macOS Core Audio framework for audio device management and is designed to integrate with virtual audio drivers like eqMac for per-app audio control.

## Current Implementation

### AudioManager.swift

The `AudioManager` class provides:

1. **Audio Device Enumeration**
   - Lists all audio devices using Core Audio APIs
   - Retrieves device names and IDs
   - Uses `kAudioHardwarePropertyDevices` property

2. **Per-App Audio Models**
   - `AudioApp` class represents individual applications
   - Tracks volume, mute state, and playback status
   - Observable for SwiftUI integration

3. **Real-time Monitoring**
   - Timer-based updates for app status
   - Foundation for audio level monitoring

## Integrating with eqMac Driver

To integrate with the eqMac driver for true per-app audio tapping:

### Step 1: Install eqMac Driver

The eqMac driver creates a virtual audio device that can intercept per-app audio.

```bash
# Install eqMac or its driver component
# Follow eqMac documentation for driver installation
```

### Step 2: Audio Session Capture

```swift
// Enumerate audio sessions per app
func getAudioSessions() -> [AudioSession] {
    // Use Core Audio to find all active audio sessions
    // Match sessions to running applications
}
```

### Step 3: Volume Control Integration

```swift
func setAppVolume(appID: String, volume: Float) {
    // Use eqMac driver API or Core Audio to set per-app volume
    // This may require:
    // 1. Creating a virtual audio graph
    // 2. Routing app audio through the graph
    // 3. Applying volume transformations
}
```

### Step 4: Audio Level Monitoring

```swift
// Monitor audio levels in real-time
func getAppAudioLevel(appID: String) -> Float {
    // Query the audio driver for current level
    // Update UI with audio visualization
}
```

## Core Audio APIs Used

### Current APIs

- `AudioObjectGetPropertyDataSize`: Get size of property data
- `AudioObjectGetPropertyData`: Retrieve audio object properties
- `kAudioHardwarePropertyDevices`: List all audio devices
- `kAudioDevicePropertyDeviceNameCFString`: Get device name

### Additional APIs for Full Integration

- `AudioDeviceCreateIOProcID`: Create audio I/O callback
- `AudioDeviceStart/Stop`: Control audio streaming
- `AudioUnitSetProperty`: Configure audio processing
- `kAudioDevicePropertyStreamConfiguration`: Stream setup

## System Permissions

The app requires these entitlements (already configured):

- `com.apple.security.audio-input`: Capture audio
- `com.apple.security.device.audio-input`: Access audio devices

## Alternative Approaches

If eqMac driver integration is complex, consider:

1. **Background Music Driver**: Open-source alternative
2. **BlackHole**: Virtual audio driver for routing
3. **Loopback**: Commercial solution with good APIs

## Testing

Test audio functionality with:

```bash
# List audio devices
system_profiler SPAudioDataType

# Check running audio apps
lsof | grep CoreAudio
```

## References

- [Core Audio Programming Guide](https://developer.apple.com/library/archive/documentation/MusicAudio/Conceptual/CoreAudioOverview/)
- [eqMac GitHub](https://github.com/bitgapp/eqMac)
- [Audio Hardware Services](https://developer.apple.com/documentation/coreaudio/audio_hardware_services)
