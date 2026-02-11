# Capsule

A system-wide audio mixer for macOS that mimics the native Control Centre UI.

## Features

- **Per-App Volume Control**: Adjust volume for individual applications independently
- **Native macOS Design**: Follows Apple Human Interface Guidelines with frosted glass effects
- **Capsule Controls**: Thick, pill-shaped volume sliders with native bounce animations
- **Menu Bar Integration**: Accessible from the menu bar, just like Control Centre
- **CoreAudio Integration**: Built on CoreAudio and AudioToolbox for high-performance audio routing

## Design

- **SwiftUI**: Modern declarative UI framework
- **VisualEffectView**: Vibrancy and translucency (frosted glass effect)
- **SF Symbols**: Native icon system for consistent design
- **Bounce Animations**: Native spring animations for interactive feedback

## Requirements

- macOS 13.0 or later
- Xcode 15.0 or later

## Architecture

The application uses a virtual audio driver architecture (similar to eqMac) to intercept process-level audio and provide per-app volume control. The UI is built with SwiftUI and follows Apple's design language.

### Components

- **CapsuleApp**: Main application entry point with menu bar integration
- **ContentView**: Main popover view with frosted glass background
- **CapsuleVolumeControl**: Individual volume control capsules with animations
- **AudioManager**: CoreAudio integration and audio routing management
- **AppAudioItem**: Model representing an application with audio output

## Building

Open `Capsule.xcodeproj` in Xcode and build the project. The app will appear in the menu bar when launched.

## Note

This is a demonstration implementation. Full driver integration for per-app audio routing would require additional system-level components and possibly kernel extensions (or modern DriverKit drivers) to intercept audio at the process level.

## License

TBD
