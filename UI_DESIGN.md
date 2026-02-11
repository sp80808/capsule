# UI Design Specification

## Overview

Capsule follows the Apple Human Interface Guidelines (HIG) and mimics the native Control Centre design found in macOS. The interface uses SwiftUI with AppKit integration for platform-specific features.

## Visual Hierarchy

```
┌─────────────────────────────────────────┐
│  ┌────────────────────────────────────┐ │
│  │ 🔊 Audio Mixer            ⚙️       │ │  ← Header (36pt)
│  └────────────────────────────────────┘ │
│  ─────────────────────────────────────  │  ← Divider
│  ┌────────────────────────────────────┐ │
│  │ ┌───┐                              │ │
│  │ │🎵 │ Music                   70%  │ │
│  │ └───┘                         🔊   │ │
│  │  ╔═══════════════════════╗         │ │  ← Capsule (44pt height)
│  │  ║█████████████⚪        ║         │ │
│  │  ╚═══════════════════════╝         │ │
│  └────────────────────────────────────┘ │
│  ┌────────────────────────────────────┐ │
│  │ ┌───┐                              │ │
│  │ │🧭 │ Safari                  60%  │ │
│  │ └───┘                         🔊   │ │
│  │  ╔═══════════════════════╗         │ │
│  │  ║██████████⚪           ║         │ │
│  │  ╚═══════════════════════╝         │ │
│  └────────────────────────────────────┘ │
│  ┌────────────────────────────────────┐ │
│  │ ┌───┐                              │ │
│  │ │▶️ │ Spotify                 90%  │ │
│  │ └───┘                         🔊   │ │
│  │  ╔═══════════════════════╗         │ │
│  │  ║████████████████⚪      ║         │ │
│  │  ╚═══════════════════════╝         │ │
│  └────────────────────────────────────┘ │
│                                         │
│                 (scrollable)            │
│                                         │
└─────────────────────────────────────────┘
   360pt wide × 480pt tall
```

## Design Elements

### Window
- **Size**: 360pt × 480pt
- **Background**: Frosted glass effect using `NSVisualEffectView`
  - Material: `.hudWindow`
  - Blending Mode: `.behindWindow`
- **Behavior**: Transient popover (dismisses when clicking outside)
- **Position**: Anchored to menu bar status item

### Header
- **Height**: 36pt + padding
- **Elements**:
  - SF Symbol: `speaker.wave.3.fill` (20pt, accent colour)
  - Title: "Audio Mixer" (18pt, semibold)
  - Settings button: `gearshape.fill` (16pt, secondary colour)
- **Background**: Transparent
- **Divider**: System standard below header

### Volume Control Capsules

Each capsule is a self-contained card showing one application:

#### Card Container
- **Padding**: 16pt vertical between cards, 16pt horizontal from edges
- **Background**: Secondary colour at 5% opacity
- **Corner Radius**: 12pt
- **Shadow**: None (relies on frosted glass effect)

#### App Info Section
- **Icon**: 32pt × 32pt
  - Using SF Symbols temporarily
  - In production: actual app icon from bundle
- **App Name**: 14pt, medium weight
- **Volume Percentage**: 12pt, secondary colour
- **Mute Button**: 16pt SF Symbol
  - Unmuted: `speaker.wave.2.fill` (accent colour)
  - Muted: `speaker.slash.fill` (secondary colour)

#### Capsule Slider
- **Total Height**: 44pt
- **Corner Radius**: 22pt (half of height for pill shape)
- **Background Track**: Secondary colour at 20% opacity
- **Filled Track**: 
  - Gradient from accent colour 80% opacity to full
  - Width based on volume level
  - Minimum width: 44pt (maintains circular appearance at 0%)
- **Thumb (drag handle)**:
  - Size: 36pt × 36pt circle
  - Colour: White (`Color.white`)
  - Shadow: Black at 20% opacity, 4pt radius, 2pt Y offset
  - Position: Aligned with volume level
  - Offset: 4pt from edges at minimum

### Animations

#### Bounce Animation (on drag)
- **Trigger**: User starts dragging slider
- **Scale**: 1.0 → 1.1 (10% increase)
- **Spring Parameters**:
  - Response: 0.2s (drag start) / 0.3s (drag end)
  - Damping Fraction: 0.5 (start) / 0.6 (end)
- **Effect**: Natural overshoot and settle
- **Duration**: ~300-400ms total including oscillation

#### Volume Change
- **Update**: Immediate (no animation)
- **Visual**: Filled portion width changes instantly
- **Thumb Movement**: Follows drag gesture 1:1

#### Mute Toggle
- **Duration**: 200ms
- **Easing**: `.easeInOut`
- **Visual**: Icon crossfade

### Colour Palette

Following system colours for automatic light/dark mode support:

- **Accent**: `Color.accentColor` (system blue by default)
- **Primary Text**: `Color.primary`
- **Secondary Text**: `Color.secondary`
- **Background Tint**: `Color.secondary.opacity(0.05)`
- **Slider Track**: `Color.secondary.opacity(0.2)`
- **White Thumb**: `Color.white`

### Typography

Using San Francisco (SF) system font:

- **Header Title**: 18pt, Semibold
- **App Name**: 14pt, Medium
- **Volume %**: 12pt, Regular
- **Icons**: 16-24pt (SF Symbols)

### Spacing

- **Card Padding**: 16pt between cards
- **Horizontal Margin**: 16pt from window edges
- **Internal Padding**: 12pt within cards
- **Icon-Text Gap**: 12pt
- **Header Padding**: 16pt all sides

## Interaction Design

### Slider Interaction
1. **Hover**: No visual change (cursor remains arrow)
2. **Mouse Down**: Thumb scales to 1.1 with spring animation
3. **Drag**: Thumb follows cursor position horizontally
4. **Release**: Thumb scales back to 1.0 with spring animation
5. **Constraints**: Volume constrained to 0-100%

### Mute Button
1. **Hover**: No visual change
2. **Click**: Icon changes with 200ms fade
3. **State**: Toggle between muted/unmuted

### Settings Button
1. **Hover**: Slight opacity change
2. **Click**: Placeholder action (future feature)

### Menu Bar
1. **Icon**: `speaker.wave.3.fill` SF Symbol
2. **Click**: Toggle popover visibility
3. **State**: Popover anchored to status item

## Accessibility

- **VoiceOver**: All controls labelled
- **Help Tags**: Tooltips on mute and settings buttons
- **Keyboard**: Not yet implemented (future enhancement)
- **High Contrast**: Uses system colours for automatic support
- **Reduced Motion**: Respects system preference (animations disabled)

## Platform Features

### macOS Integration
- **Vibrancy**: True frosted glass using `NSVisualEffectView`
- **Menu Bar**: Native `NSStatusItem` integration
- **Popover**: Native `NSPopover` behaviour
- **SF Symbols**: System icon library
- **Dark Mode**: Automatic via system colours

### Window Behavior
- **LSUIElement**: App doesn't appear in Dock
- **Transient**: Popover dismisses on focus loss
- **Always on Top**: Popover appears above other windows
- **No Title Bar**: Seamless with menu bar

## Implementation Details

### SwiftUI Views
```
ContentView
├── VisualEffectView (background)
└── VStack
    ├── Header (HStack)
    └── ScrollView
        └── VStack
            └── CapsuleVolumeControl × N
```

### State Management
- `@StateObject`: AudioManager (singleton)
- `@ObservedObject`: AppAudioItem (per app)
- `@State`: Drag state, animations

### Performance
- **Lazy Loading**: Not needed (small list)
- **60 FPS**: Maintained during drag
- **Memory**: ~5MB typical usage
- **CPU**: <1% idle, ~5% during interaction

## Future Enhancements

1. **Actual App Icons**: Extract from running processes
2. **Search/Filter**: When many apps present
3. **Favourites**: Pin frequently used apps
4. **Global Hotkey**: Show/hide with keyboard
5. **Mini Mode**: Compact version with fewer details
6. **Themes**: Custom colour schemes
7. **Audio Visualisation**: Real-time waveforms
8. **Presets**: Save/restore configurations

## Comparison to Control Centre

### Similarities
- Frosted glass background
- Popover from menu bar
- Consistent with system design
- Native controls and animations
- SF Symbols throughout

### Differences
- Vertical scrolling (Control Centre uses sections)
- Per-app focus (Control Centre is system-wide)
- Thick capsule sliders (Control Centre uses standard sliders)
- Continuous animations (Control Centre more subtle)

## Testing the UI

To verify the implementation:

1. **Build**: Open in Xcode 15+ on macOS 13+
2. **Run**: App appears in menu bar
3. **Click**: Popover opens with mock apps
4. **Drag**: Test slider with bounce animation
5. **Mute**: Toggle mute buttons
6. **Resize**: Verify fixed 360×480 size
7. **Dark Mode**: Toggle and verify appearance
8. **Accessibility**: Test with VoiceOver

## Design Rationale

### Why Capsules?
- **Visual Weight**: Thick sliders are easier to grab
- **Distinctive**: Unique identity vs standard macOS sliders
- **Touchpad Friendly**: Larger target for precision gestures
- **Aesthetic**: Modern, playful, aligned with "Capsule" name

### Why Bounce?
- **Feedback**: Confirms interaction has begun
- **Playful**: Makes the app feel responsive and alive
- **Natural**: Spring physics feel organic
- **Apple Standard**: Used throughout iOS/macOS

### Why Frosted Glass?
- **macOS Identity**: Signature look since macOS Big Sur
- **Depth**: Creates visual hierarchy
- **Focus**: Subtle transparency keeps attention on content
- **Modern**: Aligns with current Apple design language

This design creates a cohesive, native-feeling macOS experience that users will find familiar and intuitive.
