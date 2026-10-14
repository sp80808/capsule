# Capsule 🎛️

A beautiful native macOS audio mixer with per-app volume control, featuring a sleek Control Center-inspired design.

![macOS](https://img.shields.io/badge/macOS-12.0+-blue.svg)
![Swift](https://img.shields.io/badge/Swift-5.0-orange.svg)
![SwiftUI](https://img.shields.io/badge/SwiftUI-Native-green.svg)

## Features

- 🔉 **System Output Control**: Select default output and set hardware volume/mute when supported
- 🧭 **Menu Bar Access**: Native menu bar panel on macOS 13+, AppKit status popover on macOS 12
- 🖱️ **Tactile Scrolling**: Adjust pill sliders with trackpad or mouse wheel
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

- macOS 12.0 (Monterey) or later
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
- **AudioManager.swift**: Per-app mixer state (currently demonstration data)
- **SystemOutputController.swift**: Core Audio output discovery, system volume/mute, device switching, property listeners

### Audio Integration

The current implementation includes:
- Live Core Audio output enumeration and default-output routing
- Hardware master volume/mute for devices that expose writable Core Audio properties (not all interfaces do)
- Virtual main volume preference, main scalar fallback, and writable channel 1/2 fallback
- Property-listener updates for external volume and device changes; refresh is suspended while dragging
- Per-app audio tapping remains a future integration; the per-app mixer currently uses demonstration data

**Note:** Recognising eqMac by device name/UID only displays a status indicator. It does not provide access to eqMac's DSP or per-app routing API. Core Audio hardware volume does not imply software per-app mixing. Test device switching and permissions on physical macOS machines before shipping.

### Future Enhancements

To integrate with eqMac driver for actual per-app audio tapping:

1. Install and configure the eqMac audio driver
2. Implement audio session capture per application
3. Hook up volume controls to actual audio streams
4. Add real-time audio level visualization

## Usage

- **System Output**: Choose an output using the device menu; hardware volume and mute only work when supported
- **Adjust Volume**: Drag the pill slider or use trackpad / mouse wheel scrolling
- **Mute/Unmute**: Double-tap on a slider
- **Refresh Apps**: Click the refresh button in the header

## License

MIT License - feel free to use this project as you wish!

## Credits

Inspired by macOS Control Center design and the eqMac audio driver project.
