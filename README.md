# Capsule

A beautiful native macOS audio mixer with SwiftUI, designed to match macOS Sonoma/Ventura aesthetics.

## Features

- 🎨 **Modern macOS Design**: Uses ultraThinMaterial backgrounds and native design patterns
- 🎚️ **Custom Pill Sliders**: Thick, high-radius capsule sliders with smooth animations
- 🎵 **Multiple Audio Channels**: Control System, Music, Browser, Communications, and Games separately
- 🔊 **Master Volume Control**: Global volume control for all channels
- ✨ **Elastic Animations**: Native "elastic" bounce on all interactions using spring animations
- 🌓 **Material Design**: Floating panels with subtle shadows and SF Symbols 6 icons
- 🎯 **Mute Controls**: Quick mute/unmute for individual channels

## Design Specifications

This app follows strict Apple Design guidelines:

- **Background**: `.ultraThinMaterial` for a native translucent look
- **Icons**: SF Symbols 6 for all app icons
- **Sliders**: Custom thick, high-radius "pill" capsule sliders (no standard sliders)
- **Spacing**: Subtle inter-item spacing (12-16pt between components)
- **Shadows**: `.shadow(color: .black.opacity(0.15), radius: 10)` on floating panels
- **Animations**: Spring animations with `response: 0.3, dampingFraction: 0.6` for elastic bounce

## Building

This is a Swift Package Manager project for macOS 13.0+:

```bash
swift build
swift run
```

## Requirements

- macOS 13.0 (Ventura) or later
- Swift 5.9+
- Xcode 15.0+ (for development)

## Architecture

The app consists of:

- `CapsuleApp.swift` - Main app entry point
- `AudioMixerView.swift` - Main UI with all panels and controls
- `PillSlider.swift` - Custom pill-style slider component
- `AudioChannel.swift` - Data model for audio channels

## License

MIT
