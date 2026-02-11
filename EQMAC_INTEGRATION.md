# eqMac Driver Integration

## Overview

eqMac is an open-source system-wide audio equalizer for macOS that includes a custom audio driver capable of tapping per-app audio. This guide explains how to integrate Capsule with eqMac's driver.

## eqMac Architecture

eqMac consists of:
1. **Audio Driver**: Kernel extension or DriverKit driver that intercepts audio
2. **Engine**: Core audio processing and routing
3. **UI**: User interface for controls

For Capsule, we're interested in the driver's per-app audio tapping capability.

## Integration Approaches

### Option 1: Use eqMac's Driver Directly

**Pros**: Full control, direct integration
**Cons**: Complex, requires driver installation, may need reverse engineering

**Steps**:
1. Study eqMac's driver source code (if available)
2. Understand the IPC mechanism between driver and app
3. Implement similar communication in Capsule
4. Route per-app audio through the driver

### Option 2: Build on eqMac's Codebase

**Pros**: Leverage existing work, proven solution
**Cons**: May include unnecessary features, larger dependency

**Steps**:
1. Fork eqMac repository
2. Extract driver and engine components
3. Adapt UI to Capsule's pill-style design
4. Remove equalizer features if not needed

### Option 3: Use Audio Server Plugin

**Pros**: macOS native, no kernel extension
**Cons**: More limited access, complex setup

**Steps**:
1. Create Audio Server Plugin
2. Tap into audio sessions
3. Route audio with volume control
4. Update UI from audio events

## Recommended Approach

**Use Background Music as reference**, as it's similar but open-source:

Background Music (https://github.com/kyleneideck/BackgroundMusic) provides:
- Per-app volume control
- Audio device driver
- Documented codebase
- Active maintenance

### Implementation Plan

#### Phase 1: Driver Setup
```swift
// AudioDriverManager.swift
import CoreAudio
import AudioToolbox

class AudioDriverManager {
    private var deviceID: AudioDeviceID?
    
    func installDriver() -> Bool {
        // Install virtual audio device
        // This creates a loopback device
    }
    
    func createAudioGraph() {
        // Set up audio processing graph
        // Input: system audio
        // Processing: per-app volume
        // Output: speakers
    }
}
```

#### Phase 2: Per-App Audio Capture
```swift
// PerAppAudioCapture.swift
import CoreAudio

class PerAppAudioCapture {
    func getActiveAudioApps() -> [AudioApp] {
        // Query Core Audio for active sessions
        // Match to running applications
        // Return list of apps with audio
    }
    
    func getAppAudioSession(bundleID: String) -> AudioSession? {
        // Get specific app's audio session
        // Return session for monitoring/control
    }
}
```

#### Phase 3: Volume Control
```swift
// VolumeController.swift
extension AudioManager {
    func setAppVolume(bundleID: String, volume: Float) {
        // Get app's audio session
        guard let session = getAppAudioSession(bundleID: bundleID) else { return }
        
        // Apply volume to audio graph
        // This modifies the audio stream in real-time
        applyVolumeToSession(session, volume: volume)
    }
    
    private func applyVolumeToSession(_ session: AudioSession, volume: Float) {
        // Use Audio Unit to apply gain
        // volume range: 0.0 (mute) to 1.0 (full)
    }
}
```

#### Phase 4: Real-time Monitoring
```swift
// AudioLevelMonitor.swift
class AudioLevelMonitor {
    func startMonitoring(bundleID: String) {
        // Set up audio tap
        // Calculate RMS/peak levels
        // Update UI in real-time
    }
    
    func getAudioLevel(bundleID: String) -> Float {
        // Return current audio level
        // Used for visualization
    }
}
```

## Core Audio APIs Required

### Device Management
```swift
// List all audio devices
AudioObjectGetPropertyDataSize(
    AudioObjectID(kAudioObjectSystemObject),
    &propertyAddress,
    0, nil, &dataSize
)

// Get device properties
AudioObjectGetPropertyData(
    deviceID,
    &propertyAddress,
    0, nil, &dataSize, &property
)
```

### Audio Graph
```swift
// Create processing graph
var graph: AUGraph?
NewAUGraph(&graph)

// Add nodes (input, effect, output)
AUGraphAddNode(graph, &desc, &node)

// Connect nodes
AUGraphConnectNodeInput(graph, sourceNode, 0, destNode, 0)

// Start processing
AUGraphStart(graph)
```

### Volume Control
```swift
// Set volume on audio unit
AudioUnitSetProperty(
    audioUnit,
    kAudioUnitProperty_Volume,
    kAudioUnitScope_Global,
    0,
    &volume,
    UInt32(MemoryLayout<Float>.size)
)
```

## Alternative: Use ScreenCaptureKit for Audio

macOS 13+ introduces `ScreenCaptureKit` which can capture per-app audio:

```swift
import ScreenCaptureKit

class ScreenCaptureAudioManager {
    func captureAppAudio(bundleID: String) async {
        // Get shareable content
        let content = try await SCShareableContent.current
        
        // Find app's windows
        let app = content.applications.first { $0.bundleIdentifier == bundleID }
        
        // Create filter
        let filter = SCContentFilter(
            desktopIndependentWindow: app?.windows.first
        )
        
        // Create configuration
        let config = SCStreamConfiguration()
        config.capturesAudio = true
        config.excludesCurrentProcessAudio = true
        
        // Start stream
        let stream = SCStream(filter: filter, configuration: config, delegate: self)
        try await stream.startCapture()
    }
}
```

**Pros of ScreenCaptureKit**:
- Native macOS 13+ API
- No driver installation
- Apple-supported
- Security framework integration

**Cons**:
- Requires macOS 13+
- Limited to window-based capture
- May not capture all audio sources

## Testing the Integration

### Unit Tests
```swift
import XCTest

class AudioDriverTests: XCTestCase {
    func testDriverInstallation() {
        let manager = AudioDriverManager()
        XCTAssertTrue(manager.installDriver())
    }
    
    func testAppDiscovery() {
        let apps = AudioManager.shared.getActiveAudioApps()
        XCTAssertGreaterThan(apps.count, 0)
    }
    
    func testVolumeControl() {
        AudioManager.shared.setAppVolume(bundleID: "com.apple.Music", volume: 0.5)
        // Verify volume was applied
    }
}
```

### Manual Testing
1. Play audio in multiple apps
2. Check if Capsule detects all apps
3. Adjust volume slider
4. Verify audio volume changes
5. Test mute/unmute
6. Check for audio glitches

## Security Considerations

### Entitlements Needed
```xml
<!-- Capsule.entitlements -->
<key>com.apple.security.audio-input</key>
<true/>
<key>com.apple.security.device.audio-input</key>
<true/>
<key>com.apple.security.temporary-exception.audio-unit-host</key>
<true/>
```

### User Permissions
Request these at runtime:
- Microphone access (for audio capture)
- Screen recording (if using ScreenCaptureKit)
- Accessibility (for app monitoring)

### Privacy
- Only capture audio when Capsule is active
- Don't record or save audio data
- Display clear indicators when capturing
- Respect system privacy settings

## Performance Optimization

### Reduce Latency
- Use low-latency audio processing
- Minimize buffer sizes
- Process audio on dedicated thread

### Efficient Updates
- Update UI at 30-60 Hz, not audio rate
- Batch audio level calculations
- Use background queues for heavy work

### Memory Management
- Reuse audio buffers
- Release inactive audio sessions
- Monitor for memory leaks in audio callbacks

## Troubleshooting

### Common Issues

**Driver not loading**:
- Check System Preferences > Security & Privacy
- Verify entitlements are correct
- Check for conflicting audio drivers

**No apps detected**:
- Ensure apps are actually playing audio
- Check Core Audio permissions
- Verify audio session enumeration

**Volume changes not working**:
- Confirm audio routing is correct
- Check audio unit connection
- Verify volume range (0.0-1.0)

**Audio glitches**:
- Increase buffer size
- Check for dropped audio frames
- Reduce CPU usage elsewhere

## Next Steps

1. **Study Reference Implementations**
   - Background Music source code
   - eqMac public components
   - Apple's Core Audio examples

2. **Start with Simple Case**
   - Detect one app's audio
   - Control its volume
   - Then expand to multiple apps

3. **Iterate on UI**
   - Connect real audio data to sliders
   - Add audio level visualization
   - Polish animations and feedback

4. **Test Thoroughly**
   - Test with various apps
   - Check edge cases
   - Monitor system resources

## Resources

- [Core Audio Programming Guide](https://developer.apple.com/library/archive/documentation/MusicAudio/Conceptual/CoreAudioOverview/)
- [eqMac GitHub](https://github.com/bitgapp/eqMac)
- [Background Music](https://github.com/kyleneideck/BackgroundMusic)
- [ScreenCaptureKit](https://developer.apple.com/documentation/screencapturekit)
- [Audio Unit Programming Guide](https://developer.apple.com/library/archive/documentation/MusicAudio/Conceptual/AudioUnitProgrammingGuide/)

## License Considerations

If using code from eqMac or Background Music:
- Check their licenses (GPL, MIT, etc.)
- Ensure Capsule's license is compatible
- Give proper attribution
- Follow open-source requirements

Both projects are open-source, but verify specific license terms before integrating.
