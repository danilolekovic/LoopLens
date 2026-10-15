# LoopLens

LoopLens is a lightweight, native macOS screen recorder for turning a display
or selected region into a polished animated GIF.

The app is being built in Swift with SwiftUI, AppKit, ScreenCaptureKit,
AVFoundation, and Image I/O. Its signature interactions will include
trackpad-driven zoom effects and a circular cursor gesture that highlights an
area before fading away.

## Status

LoopLens is in early development. The current build includes:

- Discover capturable displays and windows with ScreenCaptureKit.
- Capture a full display or drag-select a screen region; selecting a region starts recording immediately.
- Record through a temporary H.264 working file.
- Keep a click-through border around the selected region while recording.
- Pinch over the recording region to zoom toward the pointer; the cyan inset shows the live crop and snaps back to the original border when zoomed out.
- Automatically save endlessly looping GIFs at selectable sizes and frame rates.
- Play the temporary recording immediately, then preview the finished animated GIF in the app.
- Control recording from a compact floating controller or the menu bar.
- Optionally include or exclude LoopLens controls from the recording.

Editable effect timelines, trimming, and more advanced GIF optimization are
planned next.

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

The app uses the macOS App Sandbox. Intermediate movies remain in the system
temporary directory. Finished GIFs are saved to `Documents/LoopLens` by
default; choose a different output folder in LoopLens Settings.

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
