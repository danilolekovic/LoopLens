# LoopLens

LoopLens is a lightweight, native macOS screen recorder for turning a display
or selected region into a polished animated GIF.

The app is being built in Swift with SwiftUI, AppKit, ScreenCaptureKit,
AVFoundation, and Image I/O. Its signature interactions will include
trackpad-driven zoom effects and a circular cursor gesture that highlights an
area before fading away.

## Status

LoopLens is in early development. The first milestone is a dependable capture
pipeline:

- Discover capturable displays and windows with ScreenCaptureKit.
- Capture a full display or selected region.
- Record cursor and gesture events on a separate effect timeline.
- Render effects non-destructively.
- Export a trimmed, optimized GIF.

## Requirements

- macOS 14.6 or later
- Xcode 16 or later
- Screen Recording permission

## Getting started

1. Open `LoopLens.xcodeproj` in Xcode.
2. Select the `LoopLens` scheme and the `My Mac` destination.
3. Build and run with **Command-R**.
4. Grant Screen Recording permission when macOS requests it.
5. Restart LoopLens if macOS requests a restart after granting permission.

The app uses the macOS App Sandbox. GIFs will be written only to locations the
user chooses through the system save panel.

## Architecture

Screen frames and interaction events are captured independently. Cursor,
zoom, and highlight events are stored on an effect timeline and applied during
rendering, keeping the source recording reusable and the effects editable.

```text
ScreenCaptureKit -> source recording -> frame renderer -> GIF encoder
                            ^                 ^
Input events --------> effect timeline ------+
```

## License

LoopLens is available under the [MIT License](LICENSE).
