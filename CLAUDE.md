# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Quiet Lens — native macOS menu bar app that dims/blurs every window except the focused one. Swift 5.9 + SwiftUI (settings) + AppKit (overlay windows). Min deployment macOS 14.0. Bundle ID `app.quiet.QuietLens`. MIT licensed.

## Build & run

The Xcode project is **generated** by [XcodeGen](https://github.com/yonaskolb/XcodeGen) from `project.yml` and **not committed**. After cloning or after editing `project.yml`:

```bash
xcodegen generate
```

Build / run / clean from CLI:

```bash
# Build Debug
xcodebuild -project QuietLens.xcodeproj -scheme QuietLens -configuration Debug -destination 'platform=macOS' build

# Build Release (produces signed .app with Assets.car bundled)
xcodebuild -project QuietLens.xcodeproj -scheme QuietLens -configuration Release -destination 'platform=macOS' build

# Clean
xcodebuild -project QuietLens.xcodeproj -scheme QuietLens clean
```

Built `.app` lands in `~/Library/Developer/Xcode/DerivedData/QuietLens-*/Build/Products/{Debug,Release}/Quiet Lens.app`.

No test target exists. No linter configured.

## Regenerating the app icon

Icons are generated procedurally by a Swift script (no Sketch/Figma source). To rebuild them:

```bash
swift /tmp/quietlens_icon.swift   # or run the script wherever you saved it
```

The script renders 10 PNGs into `QuietLens/Resources/Assets.xcassets/AppIcon.appiconset/` at exact pixel sizes (16/32/64/128/256/512/1024 px). Uses `CGContext` directly — do **not** use `NSImage(size:)` which doubles to HiDPI pixels.

## Architecture overview

Three coordinated layers. Understanding the interaction is more important than any one file:

### 1. Tracking layer (`Core/`)

- **`WindowTracker`** — observes `NSWorkspace.didActivateApplication` + `AXObserver` notifications (`kAXFocusedWindowChanged`, etc.). Reads focused window via `AXUIElementCopyAttributeValue`. Falls back to 0.5s polling. Emits `FocusedWindowInfo` (pid, bundleID, frame, windowNumber, allAppFrames) via `onFocusedWindowChanged` callback.
- **`ShakeDetector`** — 60Hz `Timer` polling `NSEvent.mouseLocation` (no Input Monitoring permission needed). 2D direction-reversal counting in a 0.6s sliding window. Triggers `onShake` or peek mode (when modifier held).
- **`HotkeyManager`** — Carbon `RegisterEventHotKey` for global shortcuts. Three IDs: toggle (1), settings (2), exclude (3). Re-registers when `Notification.Name.quietLensShortcutChanged` posts.
- **`AutomationHandler`** — routes `quietlens://{toggle|enable|disable|settings}` URL events. Apple Event handler installed in `AppDelegate`.

### 2. Overlay layer (`Overlay/` + `OverlayManager`)

- **`OverlayManager`** — central state machine. Owns one `OverlayWindow` per screen (`NSScreen` → `CGDirectDisplayID` dict). Drives visibility via `isEnabled && !isExcluded && !isPeeking && !isDragging`. Recomputes per-screen cutouts on every focus change.
- **Per-screen cutout selection** (`computePerScreenWindows`) — queries `CGWindowListCopyWindowInfo`, filters layer ≤ 0, on-screen, non-trivial size, alpha > 0. For each screen: prefers AX focused frame (if it lands on that screen), then topmost frontmost-app window, then any topmost window. With `highlightSameAppWindows` enabled, all windows of frontmost app become cutouts.
- **`OverlayWindow`** — borderless `NSWindow` at `screenSaver - 1` level, `ignoresMouseEvents = true`, `canJoinAllSpaces + stationary + fullScreenAuxiliary` collection behavior. Frame computed from `screen.frame` minus menu bar / Dock area (unless `autoHideMenuBar`/`autoHideDock` is on, in which case overlay extends to full screen and `NSApp.presentationOptions` hides them).
- **`BlurOverlayView`** — `NSVisualEffectView` (forced `.darkAqua` appearance to suppress system accent influence) + tint `CALayer` or `CAGradientLayer` + grain `CALayer` (2048px noise, softLight blend, nearest-neighbor scaling). Shader animations (`breathing`/`drift`/`pulse`) applied as `CABasicAnimation`/`CAKeyframeAnimation` on the view's layer.
- **`CutoutView`** — `CAShapeLayer` evenOdd mask on the blur view. Cutout corner radius 14, inset by -1.5 to cover anti-alias seam on modern macOS rounded windows. Path transitions animated when `duration > 0`.

### 3. Coordination (`AppDelegate`)

`AppDelegate` is the singleton orchestrator (`AppDelegate.shared`). It:

- Owns `OverlayManager`, `WindowTracker`, `ShakeDetector`, `HotkeyManager`, `AutomationHandler`.
- Subscribes to `QuietLensSettings.shared.objectWillChange` and on each tick calls `refreshAppearance + refreshGeometry + windowTracker.refresh + applyAutoHide`. **This is how every settings toggle takes effect at runtime** — there's no per-setting handler.
- Polls `AXIsProcessTrusted()` every 1.5s. On false→true flip, starts tracking, closes onboarding, and opens Settings (first-run welcome flow). On true→false, re-shows onboarding.

### Settings model (`Models/Settings.swift`)

Class is **`QuietLensSettings`**, not `Settings` — the latter collides with SwiftUI's `Settings` scene. All properties `@Published` with `didSet` writing through to `UserDefaults.standard` (not a custom suite — using bundle ID as suite name was a former bug). `applyPreset()` runs on tint-preset change to sync hex fields.

Enum types live alongside: `OverlayMode` (deep/ambient), `ShaderMode` (static/breathing/drift/pulse), `TintPreset` (12 curated gradient pairs), `ShakeModifier`, `MenuBarLeftClickAction`.

`effectiveTintColor` / `effectiveTintColor2` accessors return `NSColor.controlAccentColor` when `useSystemTint` is true, else parsed hex. Always use these — never read `tintColorHex` directly when rendering.

## Settings UI (Control Center style)

SwiftUI views in `Views/`. Sidebar nav drives a switch in `SettingsView.content`. Reusable components defined in `SettingsView.swift`:

- **`CCCard(title?)`** — labeled section card with `.regularMaterial` background and subtle white stroke.
- **`CCRow(icon, title, subtitle?) { trailing }`** — icon-circle + title (+ optional subtitle) + trailing control.
- **`SliderRow(icon, title, value, range, display)`** — labelled slider with monospaced value readout.
- **`TickSliderRow(icon, title, value, ticks, labels)`** — segmented capsule tick slider (used for shake sensitivity).
- **`ColorCircleRow(hex, useSystem, label?)`** — Apple system-color circles + rainbow custom picker + "As System" toggle.

The window itself is hosted by `AppDelegate.openSettings()` (not a SwiftUI `Scene`), so the `Settings { EmptyView() }` scene in `QuietLensApp` is just a placeholder to satisfy `App` protocol.

## Permissions gotcha (TCC + signature)

macOS TCC binds Accessibility grants to **code signature hash**, not bundle ID. After each unsigned rebuild the signature changes → old TCC entry no longer matches → `AXIsProcessTrusted()` returns false even when System Settings still shows the checkbox. Fix: user removes + re-adds Quiet Lens in System Settings → Privacy & Security → Accessibility, OR sign with a stable Developer ID.

The 1.5s poll in `AppDelegate.startAccessibilityPoll` exists specifically to handle this — when user fixes permission externally, app auto-recovers without restart. Onboarding shows the manual remove+re-add instructions verbatim.

## Working with project.yml

`project.yml` controls the generated Xcode project. Key bits:

- `info.properties` becomes Info.plist — `LSUIElement: true`, URL scheme `quietlens`, `CFBundleIconName: AppIcon`, `NSAccessibilityUsageDescription`.
- `settings.base.ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon` is required or Assets.car won't bundle.
- `ENABLE_APP_SANDBOX: NO` — accessibility API requires unsandboxed.
- Signing: `CODE_SIGN_STYLE: Automatic`, no explicit team (Xcode picks Personal Team or paid). Bundle prefix `app.quiet`.

After editing `project.yml`, always run `xcodegen generate` before building.

## Reset state during development

```bash
defaults delete app.quiet.QuietLens   # wipe all saved settings
```

If TCC permission seems "stuck" granted but app reports false, manually remove Quiet Lens from System Settings → Privacy & Security → Accessibility and re-add.
