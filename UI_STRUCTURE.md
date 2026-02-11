# Capsule UI Structure

```
┌─────────────────────────────────────────────────────────────┐
│  [🌊] Capsule                              [🔊] [⚙️]         │  Header
│      Audio Mixer                                             │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  ┌───────────────────────────────────────────────────────┐  │
│  │ [🔊] Master Volume                                     │  │  Master Panel
│  │                                                         │  │  (ultraThinMaterial
│  │ [🔊] Output Level                        75%           │  │   + shadow)
│  │ ╭─────────────────────────────●────────╮              │  │  
│  │ ╰─────────────────────────────────────╯              │  │  Pill Slider
│  └───────────────────────────────────────────────────────┘  │  (32pt height)
│                                                               │
│  ┌───────────────────────────────────────────────────────┐  │
│  │ [🔵]  System                            [🔊]           │  │  Channel Card
│  │   🔵   Active                                          │  │  (ultraThinMaterial
│  │                                                         │  │   + shadow)
│  │ [📊] Volume                              75%           │  │
│  │ ╭─────────────────────────────●────────╮              │  │  Pill Slider
│  │ ╰─────────────────────────────────────╯              │  │
│  └───────────────────────────────────────────────────────┘  │
│                                                               │
│  ┌───────────────────────────────────────────────────────┐  │
│  │ [💗]  Music                             [🔊]           │  │  Channel Card
│  │   🎵   Active                                          │  │
│  │                                                         │  │
│  │ [📊] Volume                              60%           │  │
│  │ ╭──────────────────────●──────────────╮              │  │  Pill Slider
│  │ ╰─────────────────────────────────────╯              │  │
│  └───────────────────────────────────────────────────────┘  │
│                                                               │
│  ┌───────────────────────────────────────────────────────┐  │
│  │ [💜]  Browser                           [🔊]           │  │  Channel Card
│  │   🌐   Active                                          │  │
│  │                                                         │  │
│  │ [📊] Volume                              50%           │  │
│  │ ╭────────────────●─────────────────────╮              │  │  Pill Slider
│  │ ╰─────────────────────────────────────╯              │  │
│  └───────────────────────────────────────────────────────┘  │
│                                                               │
│  ┌───────────────────────────────────────────────────────┐  │
│  │ [💚]  Comms                             [🔊]           │  │  Channel Card
│  │   🎤   Active                                          │  │
│  │                                                         │  │
│  │ [📊] Volume                              80%           │  │
│  │ ╭───────────────────────────●──────────╮              │  │  Pill Slider
│  │ ╰─────────────────────────────────────╯              │  │
│  └───────────────────────────────────────────────────────┘  │
│                                                               │
│  ┌───────────────────────────────────────────────────────┐  │
│  │ [🧡]  Games                             [🔊]           │  │  Channel Card
│  │   🎮   Active                                          │  │
│  │                                                         │  │
│  │ [📊] Volume                              90%           │  │
│  │ ╭─────────────────────────────────●────╮              │  │  Pill Slider
│  │ ╰─────────────────────────────────────╯              │  │
│  └───────────────────────────────────────────────────────┘  │
│                                                               │
└─────────────────────────────────────────────────────────────┘

## Visual Features

### Materials & Effects
- Background: ultraThinMaterial (translucent native macOS blur)
- Panels: Rounded rectangles with ultraThinMaterial
- Shadows: .black.opacity(0.15), radius 10, offset (0, 4)

### Pill Sliders
- Shape: Capsule (infinite corner radius)
- Height: 32pt (thick, substantial)
- Background: ultraThinMaterial with white 0.1 opacity stroke
- Fill: Blue gradient (0.8 → 0.6 opacity)
- Thumb: White circle (24pt) with shadow
- Animation: Spring (response: 0.3, dampingFraction: 0.6)

### Spacing
- Card spacing: 12pt
- Section spacing: 16pt
- Horizontal padding: 24pt
- Vertical padding: 18-20pt
- Label spacing: 6-8pt

### Typography
- App title: 24pt bold
- Section headers: 16pt semibold
- Channel names: 15pt semibold
- Labels: 12pt medium
- Values: 12pt semibold monospaced

### Interactions
- Hover: Subtle background change on buttons
- Press: Scale 1.0 → 0.9 → 1.0 with elastic bounce
- Drag: Thumb scales to 1.15 during drag
- All animations: Spring with elastic bounce
- Mute toggle: Smooth opacity fade + color change

### Colors
- System: Blue
- Music: Pink
- Browser: Purple
- Comms: Green
- Games: Orange
- Muted: Red with 0.6 opacity overlay

### Icons (SF Symbols 6)
- App: waveform.circle.fill
- System: speaker.wave.3.fill
- Music: music.note
- Browser: globe
- Comms: mic.fill
- Games: gamecontroller.fill
- Settings: gearshape.fill
- Slider: slider.horizontal.3
- Mute: speaker.slash.fill
```

## Interaction Behavior

1. **Slider Drag:**
   - Touch/click anywhere on pill
   - Thumb scales up (1.0 → 1.15)
   - Value updates with spring animation
   - Release: thumb scales back (1.15 → 1.0)

2. **Mute Button:**
   - Click triggers scale animation
   - Icon switches: speaker ↔ speaker.slash
   - Card fades to 0.6 opacity when muted
   - Background changes to red tint when muted

3. **Control Buttons:**
   - Hover: Background highlight appears
   - Click: Scale down then bounce back
   - Active state: Blue color
   - Inactive: Secondary gray

4. **All Animations:**
   - Spring-based (elastic bounce)
   - Response time: 0.2-0.3 seconds
   - Damping fraction: 0.5-0.7 (creates bounce)
   - Natural, native macOS feel
