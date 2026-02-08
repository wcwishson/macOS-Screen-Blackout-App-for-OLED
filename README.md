# macOS Screen Blackout App for OLED

`OLEDBlackout` is a minimal macOS utility that shows pure black fullscreen windows on all displays to reduce OLED wear when you are away.

## Features

- Pure black fullscreen overlay on all connected displays
- High window level (`screenSaver`) to stay above normal app windows
- Hides cursor while active
- Hides Dock and menu bar while active
- Reasserts topmost/cursor-hide state every 5 seconds
- Quits on any mouse click (left, right, or other)
- Ignores keyboard input while active

## Download

Get the latest prebuilt app from Releases:

- [v1.0.0 Release](https://github.com/wcwishson/macOS-Screen-Blackout-App-for-OLED/releases/tag/v1.0.0)
- Asset: `OLEDBlackout-v1.0.0-macOS-arm64.zip`

## Install

1. Download and unzip the release zip.
2. Move `OLEDBlackout.app` to `/Applications`.
3. Launch once via right-click -> `Open` (required for unsigned apps).
4. Optionally pin it to Dock.

## Usage

1. Launch `OLEDBlackout`.
2. All screens turn black and cursor is hidden.
3. Click once anywhere to quit.

## Build From Source

Requirements:

- Xcode 15+
- macOS 12+
- Apple Silicon target in current release package

Build:

```bash
xcodebuild -project "OLEDBlackout.xcodeproj" -scheme OLEDBlackout -configuration Release -destination 'platform=macOS' build
```

The built app is placed in Xcode `DerivedData`.

## Notes and Limits

- The app is currently unsigned and not notarized.
- System-level dialogs (for example security prompts) may still appear above any third-party app by macOS design.
- If Dock icon or behavior looks stale after updating, replace the app in `/Applications` and re-add it to Dock.

## Project Structure

- `OLEDBlackout/` - Swift source and asset catalog
- `OLEDBlackout.xcodeproj/` - Xcode project

## License

No license file is included yet. Add a `LICENSE` file if you want explicit reuse terms.
