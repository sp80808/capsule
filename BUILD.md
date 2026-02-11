# Building and Running Capsule

## Prerequisites

- macOS 13.0 (Ventura) or later
- Xcode 15.0 or later

## Quick Start

1. **Clone the Repository**
   ```bash
   git clone https://github.com/sp80808/capsule.git
   cd capsule
   ```

2. **Open in Xcode**
   ```bash
   open Capsule.xcodeproj
   ```
   
   Or launch Xcode and use File > Open, then select `Capsule.xcodeproj`

3. **Select Target**
   - In Xcode, select "Capsule" scheme at the top
   - Choose "My Mac" as the destination

4. **Build and Run**
   - Press `⌘R` or click the Play button
   - The app should launch with the audio mixer interface

## First Launch

On first launch, macOS may ask for permissions:
- **Microphone Access**: Required for audio monitoring
- **Audio Input**: Required to tap into per-app audio

Grant these permissions for full functionality.

## Project Structure

```
capsule/
├── Capsule.xcodeproj/          # Xcode project file
│   └── project.pbxproj
├── Capsule/                     # Source code
│   ├── CapsuleApp.swift        # App entry point
│   ├── ContentView.swift       # Main UI view
│   ├── PillSlider.swift        # Custom slider component
│   ├── AudioManager.swift      # Audio integration
│   ├── Info.plist              # App metadata
│   ├── Capsule.entitlements    # Permissions
│   └── Assets.xcassets/        # Images and colors
├── README.md                    # Project overview
├── DESIGN.md                    # UI specifications
└── AUDIO_INTEGRATION.md         # Audio implementation guide
```

## Troubleshooting

### Build Errors

**Issue**: "No such module 'SwiftUI'"
- **Solution**: Ensure you're running macOS 13.0+ and Xcode 15.0+

**Issue**: Signing errors
- **Solution**: Go to Project Settings > Signing & Capabilities, select your development team

### Runtime Issues

**Issue**: App doesn't show audio apps
- **Solution**: Currently displays sample apps. See AUDIO_INTEGRATION.md for implementing real audio capture

**Issue**: Volume changes don't affect actual audio
- **Solution**: This requires eqMac driver integration. The UI is functional; backend integration is pending.

## Development Workflow

### Making Changes

1. Open the project in Xcode
2. Edit Swift files in the left sidebar
3. Build with `⌘B` to check for errors
4. Run with `⌘R` to see changes

### Live Preview

SwiftUI provides live previews:
1. Open any `.swift` file
2. Press `⌥⌘↩` to show preview
3. Click "Resume" if preview is paused
4. See changes in real-time as you edit

### Debugging

- Set breakpoints by clicking line numbers
- Run with debugger attached (⌘R)
- View console output in bottom panel
- Use `print()` statements for logging

## Testing UI

The app includes sample data to test the UI:
- 6 sample applications with different states
- Volume controls that update the UI
- Mute/unmute functionality
- Refresh button to reset sample data

Interact with the pill sliders:
- **Drag** horizontally to adjust volume
- **Double-tap** to mute/unmute
- **Click refresh** to reset to defaults

## Next Steps

### Implementing Real Audio Control

To make Capsule control actual audio:

1. **Review AUDIO_INTEGRATION.md** for technical details
2. **Install audio driver** (eqMac or alternative)
3. **Implement audio session capture** in AudioManager.swift
4. **Connect volume controls** to audio streams
5. **Test with real applications**

### Customization

Easy customizations to try:
- **Colors**: Edit gradients in PillSlider.swift
- **Icons**: Change SF Symbols in ContentView.swift  
- **Animations**: Adjust spring parameters in PillSlider.swift
- **Layout**: Modify spacing and sizes in ContentView.swift

## Performance

The app is optimized for smooth performance:
- SwiftUI lazy rendering
- Efficient audio monitoring (2-second intervals)
- Hardware-accelerated animations
- Native macOS visual effects

## Contributing

Contributions welcome! Areas that need work:
- Full eqMac driver integration
- Real-time audio level visualization
- App icon extraction from bundles
- Menu bar compact mode
- Keyboard shortcuts

## Support

For issues or questions:
1. Check existing documentation (README, DESIGN, AUDIO_INTEGRATION)
2. Review the code comments
3. Open an issue on GitHub

## Building for Release

To create a release build:

1. Product > Archive in Xcode
2. Window > Organizer
3. Select your archive
4. Click "Distribute App"
5. Choose "Copy App" for local distribution
6. Or "Developer ID" for wider distribution

Note: Wider distribution requires an Apple Developer account and code signing.
