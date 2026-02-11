# Capsule UI Design Specification

## Design Philosophy

Capsule's UI takes direct inspiration from macOS Control Center, featuring:
- Native macOS design language
- Frosted glass (vibrancy) effects
- Pill-shaped controls
- SF Symbols iconography
- Smooth, spring-based animations

## Components

### 1. Main Window

**Dimensions**: 400x600pt (minimum)
**Style**: Hidden title bar with content-size resizability
**Background**: `NSVisualEffectView` with `.hudWindow` material

```swift
.windowStyle(.hiddenTitleBar)
.windowResizability(.contentSize)
```

### 2. Header

**Layout**:
- Left: Speaker icon + "Capsule" title
- Right: Refresh button
- Divider below

**Typography**:
- Title: `.title` weight `.semibold`
- Icons: `.title2` and `.title3`

**Spacing**: 20pt horizontal, 20pt top, 15pt bottom

### 3. App Volume Control Cards

**Structure**: Individual cards for each app with:

#### Card Layout
- Padding: 16pt all sides
- Corner radius: 16pt
- Background: White 5% opacity with 10% stroke
- Spacing: 16pt between cards

#### Card Content
1. **App Header** (HStack)
   - App icon (32x32pt, rounded 8pt corners)
   - App name (`.headline`)
   - Playing status (`.caption`, secondary color)
   - Volume percentage (monospaced, `.body`)

2. **Pill Slider**
   - Height: 48pt
   - Full width with padding
   - Interactive drag gesture
   - Double-tap to mute

### 4. Pill Slider Component

**Specifications**:

#### Background Pill
- Shape: `Capsule()`
- Fill: White 8% opacity
- Height: 48pt

#### Active Fill
- Shape: `Capsule()`
- Gradient: Blue to purple (60% opacity)
- Width: Dynamic based on volume
- Minimum: 36pt (handle size)

#### Handle
- Shape: `Circle()`
- Size: 36x36pt
- Fill: White solid
- Shadow: 4pt radius, 2pt Y offset, 20% black
- Icon: Speaker or speaker.slash when muted
- Icon size: 14pt

**Interactions**:
- Drag: Adjust volume (0-100%)
- Double-tap: Toggle mute
- Animation: Spring with 0.3s response, 0.7 damping

### 5. Color Palette

**Primary Colors**:
- Blue: System blue with custom opacity
- Purple: System purple for gradients
- White: Used for overlays and text

**Opacity Levels**:
- Background overlay: 5%
- Stroke: 10%
- Active slider fill: 60%
- Inactive elements: 8%

**Gradients**:
```swift
LinearGradient(
    colors: [Color.blue, Color.purple],
    startPoint: .topLeading,
    endPoint: .bottomTrailing
)
```

### 6. SF Symbols Used

- `speaker.wave.3.fill` - Main app icon
- `speaker.wave.2.fill` - Normal volume
- `speaker.slash.fill` - Muted state
- `arrow.clockwise` - Refresh button
- `music.note` - Music apps
- `safari` - Safari browser
- `music.note.list` - Spotify
- `globe` - Chrome
- `video.fill` - Zoom
- `message.fill` - Messaging apps

### 7. Typography Scale

**Fonts**:
- `.title` - Main header (28pt)
- `.title2` - Icons (22pt)
- `.title3` - Action icons (20pt)
- `.headline` - App names (17pt bold)
- `.body` - Volume percentage (17pt)
- `.caption` - Status text (12pt)

**Font Modifiers**:
- `.fontWeight(.semibold)` - Headers
- `.fontWeight(.medium)` - Volume numbers
- `.monospacedDigit()` - Volume percentages

### 8. Animation Specifications

**Spring Animation**:
```swift
.animation(.spring(response: 0.3, dampingFraction: 0.7), value: value)
```

**Response**: 0.3 seconds
**Damping**: 0.7 (slightly bouncy)

**Applied to**:
- Volume slider position
- Mute state transitions
- Visual feedback

### 9. Spacing System

- Extra small: 2pt
- Small: 8pt
- Medium: 12pt
- Large: 16pt
- Extra large: 20pt

### 10. Accessibility

**Features**:
- VoiceOver support through native SwiftUI
- Keyboard navigation
- High contrast support
- Dynamic Type support (where applicable)
- Tooltips on interactive elements

**Help Text**:
- Refresh button: "Refresh audio apps"

## Implementation Notes

### Frosted Glass Effect

Uses `NSVisualEffectView` wrapper:

```swift
struct VisualEffectBlur: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }
}
```

**Material**: `.hudWindow` - Matches Control Center appearance
**Blending**: `.behindWindow` - Shows desktop behind

### Gesture Handling

Pill slider uses `DragGesture` with:
- `minimumDistance: 0` - Immediate response
- Normalized values (0.0 to 1.0)
- Automatic unmute on drag
- Constrained to bounds

### State Management

Uses SwiftUI's observation system:
- `@StateObject` for AudioManager
- `@ObservedObject` for individual AudioApps
- `@Published` for reactive updates
- `@Binding` for slider values

## Dark Mode Support

All colors and materials automatically adapt to:
- Light appearance
- Dark appearance
- High contrast modes

No manual theme switching needed - uses system appearance preferences.

## Performance Considerations

- ScrollView for efficient list rendering
- Lazy loading of app cards
- Debounced volume updates
- Efficient audio monitoring (2-second intervals)

## Future Design Enhancements

1. Audio level visualization in slider
2. Animated waveforms for active apps
3. Custom app icons from bundle
4. Compact mode for menu bar
5. Quick actions (e.g., mute all)
