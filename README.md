# Capsule 🎛️

A beautiful native macOS audio mixer with per-app volume control, featuring a sleek Control Center-inspired design.

![macOS](https://img.shields.io/badge/macOS-13.0+-blue.svg)
![Swift](https://img.shields.io/badge/Swift-5.0-orange.svg)
![SwiftUI](https://img.shields.io/badge/SwiftUI-Native-green.svg)

## Features

- 🎨 **Native macOS Design**: Control Center-inspired pill sliders with frosted glass effects
- 🔊 **Per-App Audio Control**: Individual volume control for each application
- 🎵 **Real-time Monitoring**: See which apps are currently playing audio
- 🖼️ **SF Symbols**: Beautiful system icons for each app
- ✨ **Smooth Animations**: Spring-based animations for a polished feel
- 🌙 **Dark Mode**: Fully supports macOS appearance modes

## Design

Capsule features a modern macOS UI built entirely with SwiftUI:

- **Thick Pill Sliders**: Custom-designed volume sliders with a distinctive pill shape
- **Frosted Glass Background**: Native `NSVisualEffectView` for that authentic macOS look
- **SF Symbols**: System icons that automatically adapt to your macOS appearance
- **Smooth Interactions**: Drag to adjust volume, double-tap to mute

## Requirements

- macOS 13.0 (Ventura) or later
- Xcode 15.0 or later (for building)

## Building

1. Clone the repository:
   ```bash
   git clone https://github.com/sp80808/capsule.git
   cd capsule
   ```

2. Open in Xcode:
   ```bash
   open Capsule.xcodeproj
   ```

3. Build and run (⌘R)

## Architecture

The app is structured with clean separation of concerns:

- **CapsuleApp.swift**: Main app entry point and delegate
- **ContentView.swift**: Main UI with frosted glass and app list
- **PillSlider.swift**: Custom pill-shaped slider component
- **AudioManager.swift**: Core Audio integration for audio device management

### Audio Integration

The current implementation includes:
- Core Audio framework integration for device enumeration
- Foundation for per-app audio tapping (ready for eqMac driver integration)
- Sample app data for UI demonstration

### Future Enhancements

To integrate with eqMac driver for actual per-app audio tapping:

1. Install and configure the eqMac audio driver
2. Implement audio session capture per application
3. Hook up volume controls to actual audio streams
4. Add real-time audio level visualization

## Usage

- **Adjust Volume**: Drag the pill slider left or right
- **Mute/Unmute**: Double-tap on a slider
- **Refresh Apps**: Click the refresh button in the header

## License

MIT License - feel free to use this project as you wish!

## Credits

Inspired by macOS Control Center design and the eqMac audio driver project.
