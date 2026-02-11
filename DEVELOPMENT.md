# Development Guide

## Project Structure

```
Capsule/
├── Capsule.xcodeproj/          # Xcode project file
├── Capsule/                    # Main application source
│   ├── CapsuleApp.swift        # App entry point and menu bar integration
│   ├── ContentView.swift       # Main UI view with frosted glass
│   ├── Views/                  # UI components
│   │   ├── VisualEffectView.swift      # AppKit wrapper for vibrancy
│   │   └── CapsuleVolumeControl.swift  # Volume control capsules
│   ├── Audio/                  # Audio routing and management
│   │   └── AudioManager.swift  # CoreAudio integration
│   ├── Models/                 # Data models
│   │   └── AppAudioItem.swift  # App audio representation
│   ├── Assets.xcassets/        # App resources
│   ├── Info.plist              # App configuration
│   └── Capsule.entitlements    # App permissions
└── README.md
```

## Key Design Decisions

### UI/UX Design

1. **Frosted Glass Effect**: Uses `NSVisualEffectView` with `.hudWindow` material for authentic macOS vibrancy
2. **Capsule Controls**: 44pt height pill-shaped sliders with rounded corners (22pt radius)
3. **Bounce Animations**: Spring animations with 0.3 response and 0.6 damping for natural feel
4. **SF Symbols**: Native icons for consistency with macOS design language
5. **Menu Bar Integration**: Uses `NSStatusItem` and `NSPopover` for native Control Centre-like behaviour

### Architecture

1. **SwiftUI-First**: Modern declarative UI with Combine for reactive updates
2. **AppKit Integration**: Bridged via `NSViewRepresentable` for platform-specific features
3. **Observable Pattern**: `@ObservableObject` for state management and real-time updates
4. **Modular Structure**: Separated concerns (UI, Audio, Models) for maintainability

### Audio Implementation

The current implementation provides a foundation for CoreAudio integration:

1. **AudioManager**: Singleton managing audio sessions and app discovery
2. **Process Audio Routing**: Placeholder for virtual audio driver communication
3. **Volume Control**: Real-time volume adjustment framework
4. **Mute Functionality**: Per-app mute state management

## British Spelling

Throughout the codebase, British English spelling is used in comments and documentation:
- "colour" instead of "color" (in comments)
- "behaviour" instead of "behavior"
- "customise" instead of "customize"
- "visualise" instead of "visualize"

## Building the Project

### Requirements

- macOS 13.0 or later
- Xcode 15.0 or later
- Swift 5.9 or later

### Build Steps

1. Open `Capsule.xcodeproj` in Xcode
2. Select the Capsule target
3. Build and run (⌘R)
4. The app will appear in the menu bar as a speaker icon

## Future Enhancements

### Driver Integration

To achieve true per-app audio control, a virtual audio driver is required:

1. **DriverKit Driver**: Modern macOS driver using DriverKit framework
2. **Audio Routing**: Intercept audio at the process level before mixing
3. **Volume Application**: Apply per-process volume multipliers in real-time
4. **IPC**: Inter-process communication between app and driver

### Additional Features

1. **Keyboard Shortcuts**: Global hotkeys for quick access
2. **App Icons**: Display actual app icons instead of SF Symbols
3. **Audio Visualisation**: Real-time waveform or level meters
4. **Presets**: Save and load volume configurations
5. **System Audio Separation**: Independent control of system sounds

## Testing

### Manual Testing

1. Launch the app
2. Click the menu bar icon
3. Test volume slider interactions
4. Verify bounce animations on drag
5. Test mute/unmute functionality
6. Verify frosted glass effect

### UI Testing

The bounce animation should feel natural:
- Scale increases to 1.1 on drag start
- Returns to 1.0 on drag end
- Spring animation provides natural overshoot

## Code Style

- SwiftUI modifiers in logical order
- Private functions prefixed with `private`
- Constants defined at type level
- Comprehensive inline documentation
- British spelling in comments

## Performance Considerations

1. **Low Latency**: CoreAudio callbacks require minimal processing time
2. **Efficient UI**: SwiftUI updates only when observable properties change
3. **Background Work**: Audio monitoring on background queue
4. **Memory Management**: Proper cleanup of audio sessions

## Security

The app requires specific entitlements:
- Audio input access for monitoring
- No sandboxing (required for system-wide audio access)
- Hardened runtime for distribution

## Troubleshooting

### App doesn't appear in menu bar
- Check LSUIElement is set to YES in Info.plist
- Verify menu bar isn't hidden in System Preferences

### Audio not detected
- Grant microphone permissions in System Preferences
- Check entitlements are properly configured

### Build errors
- Ensure deployment target is macOS 13.0+
- Verify Swift version is 5.9+
