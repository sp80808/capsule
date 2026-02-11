# Capsule UI Mockup

This document describes the visual appearance of Capsule's interface.

## Main Window

```
╔════════════════════════════════════════════════════════════╗
║  🔊 Capsule                                    🔄          ║
║ ──────────────────────────────────────────────────────────║
║                                                            ║
║  ┌──────────────────────────────────────────────────────┐ ║
║  │  🎵  Music                            Playing    70%  │ ║
║  │  ═══════════════════════════════════○                │ ║
║  └──────────────────────────────────────────────────────┘ ║
║                                                            ║
║  ┌──────────────────────────────────────────────────────┐ ║
║  │  🧭  Safari                             Idle    50%   │ ║
║  │  ══════════════════════○                             │ ║
║  └──────────────────────────────────────────────────────┘ ║
║                                                            ║
║  ┌──────────────────────────────────────────────────────┐ ║
║  │  🎼  Spotify                          Playing    80%  │ ║
║  │  ════════════════════════════════════○               │ ║
║  └──────────────────────────────────────────────────────┘ ║
║                                                            ║
║  ┌──────────────────────────────────────────────────────┐ ║
║  │  🌐  Chrome                             Idle    60%   │ ║
║  │  ═══════════════════════════○                        │ ║
║  └──────────────────────────────────────────────────────┘ ║
║                                                            ║
║  ┌──────────────────────────────────────────────────────┐ ║
║  │  📹  Zoom                               Idle    40%   │ ║
║  │  ═════════════════○                                  │ ║
║  └──────────────────────────────────────────────────────┘ ║
║                                                            ║
║  ┌──────────────────────────────────────────────────────┐ ║
║  │  💬  Slack                              Idle    30%   │ ║
║  │  ════════════○                                       │ ║
║  └──────────────────────────────────────────────────────┘ ║
║                                                            ║
╚════════════════════════════════════════════════════════════╝
```

## UI Element Breakdown

### Header
- **Left Side**: Speaker icon (🔊) + "Capsule" title
- **Right Side**: Refresh button (🔄)
- **Divider**: Subtle line separator

### App Volume Card

Each card contains:

```
┌────────────────────────────────────────────────────────────┐
│  [Icon]  App Name                    Status    Volume%     │
│  ════════════════════════════○                             │
│  ^                            ^                             │
│  Background pill              Handle (white circle)        │
│  with gradient fill                                        │
└────────────────────────────────────────────────────────────┘
```

**Card Structure**:
1. **Icon**: 32x32pt rounded square with gradient background
2. **App Name**: Bold headline font
3. **Status**: "Playing" or "Idle" in smaller, secondary text
4. **Volume %**: Monospaced digits (e.g., "70%")
5. **Pill Slider**: Thick (48pt) pill-shaped slider

### Pill Slider Details

```
Normal State (Unmuted):
════════════════════════════════════○
^                                    ^
Blue-purple gradient fill            White circular handle
(matches volume level)               with speaker icon

Muted State:
────────────────────────────────────○
                                     ^
                                     Handle with
                                     speaker.slash icon
```

**Slider Behavior**:
- **Drag Left/Right**: Adjusts volume 0-100%
- **Double-Tap**: Toggles mute/unmute
- **Visual Fill**: Gradient extends to handle position
- **Animation**: Smooth spring animation on interaction

## Color Scheme

### Backgrounds
- **Window**: Frosted glass effect (transparent, blurs content behind)
- **Cards**: Semi-transparent white (5% opacity)
- **Card Border**: Semi-transparent white (10% opacity)

### Colors
- **Primary Gradient**: Blue → Purple
- **Text Primary**: System primary (adapts to dark/light mode)
- **Text Secondary**: System secondary (gray)
- **Handle**: White with subtle shadow

### Opacity Levels
```
Background overlay:      ░ 5%
Card stroke:            ░░ 10%
Slider fill:          ░░░░░░ 60%
```

## Typography

```
Title (Capsule):    28pt, Semibold
App Name:           17pt, Bold
Status:             12pt, Regular
Volume:             17pt, Medium, Monospaced
```

## Spacing and Layout

```
Window:
├─ Horizontal padding: 20pt
├─ Top padding: 20pt
└─ Vertical spacing: 16pt between cards

Card:
├─ Internal padding: 16pt
├─ Corner radius: 16pt
└─ Content spacing: 12pt

Slider:
├─ Height: 48pt
├─ Handle size: 36pt
└─ Corner radius: 24pt (full pill shape)
```

## Dark Mode Support

The UI automatically adapts to macOS appearance:

**Light Mode**:
- Text: Dark gray
- Background: Light frosted glass
- Slider: Lighter colors

**Dark Mode**:
- Text: Light gray/white
- Background: Dark frosted glass
- Slider: Vibrant colors pop more

## SF Symbols Used

All icons are from Apple's SF Symbols library:

```
speaker.wave.3.fill    - Main app icon
speaker.wave.2.fill    - Normal volume state
speaker.slash.fill     - Muted state
arrow.clockwise        - Refresh apps
music.note             - Music/iTunes
safari                 - Safari browser
music.note.list        - Spotify/music apps
globe                  - Chrome/browsers
video.fill             - Zoom/video apps
message.fill           - Slack/messaging
```

## Animation Effects

1. **Slider Interaction**
   - Spring animation (0.3s response, 0.7 damping)
   - Handle follows finger/cursor smoothly
   - Fill animates to match position

2. **Mute Toggle**
   - Quick spring transition
   - Icon changes: speaker ↔ speaker.slash
   - Color change: gradient ↔ gray

3. **Window Appearance**
   - Frosted glass effect is always active
   - Blurs desktop/windows behind
   - Maintains vibrancy

## Interaction Patterns

### Mouse/Trackpad
- **Hover**: No hover effects (iOS-style, clean)
- **Click & Drag**: Slider responds immediately
- **Double-Click**: Toggle mute

### Keyboard (Future Enhancement)
- Tab: Navigate between apps
- Space: Toggle mute
- Arrow keys: Adjust volume

## Accessibility

- **VoiceOver**: All controls labeled
- **Keyboard**: Full keyboard navigation
- **Contrast**: Respects system settings
- **Motion**: Respects reduced motion preference

## Window Properties

```
Default Size:      400 × 600 pt
Minimum Size:      400 × 600 pt
Resizable:         Yes (content size)
Title Bar:         Hidden
Background:        Transparent with vibrancy
Level:             Normal
```

## Comparison to macOS Control Center

Capsule mirrors Control Center's design language:

**Similar**:
- Frosted glass background
- Pill-shaped controls
- SF Symbols icons
- Smooth animations
- Card-based layout

**Different**:
- Specialized for audio mixing
- Vertical scrolling list
- Per-app granular control
- Larger interactive areas

---

## Implementation Notes

This mockup represents the actual implementation in SwiftUI. All visual effects use native macOS APIs:

- `NSVisualEffectView` for frosted glass
- `Capsule()` shape for pill sliders
- `LinearGradient` for color fills
- SF Symbols through `Image(systemName:)`
- Spring animations through SwiftUI

The result is a truly native macOS app that feels at home in macOS Ventura and later.
