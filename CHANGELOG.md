# Changelog

All notable changes to FocusLens are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] — 2026-05-14

**Build 1** · First public release.

### Added

#### Core
- Native macOS menu bar agent (no Dock icon)
- Per-screen active-window detection — every connected display tracks its own focused window
- AX-based focus tracking with `CGWindowList` z-order fallback
- Smooth animated cutout transitions between focused windows
- Multi-display support with hot-swap monitor handling
- Drag-and-drop awareness — overlay fades during a drag operation

#### Visual modes
- **Deep** mode — full-screen frosted-glass dim, heavy tint coverage
- **Ambient** mode — subtle vertical-fade gradient backdrop
- Real Gaussian blur via `NSVisualEffectView` with continuous 0–50 radius mapping
- Opacity slider 10–100%
- Soft-light film grain with high-frequency 2048×2048 noise source
- Grayscale background filter (Core Image `CIColorControls`)
- Animated shader modes: Static, Breathing (opacity), Drift (xy translation), Pulse (scale)
- Configurable fade duration (50–1000 ms)

#### Tint system
- 9 Apple system color swatches + rainbow custom-color picker
- **As System** mode — overlay tint follows macOS accent color live
- Optional gradient tint with custom second color + 0–360° angle
- Hex color input/output round-trip

#### Gestures
- 2D cursor shake detection (any direction — horizontal, vertical, diagonal, circular)
- 5-tick sensitivity slider (Very Low → Very High)
- Shake-to-peek with configurable modifier key (⇧ / ⌥ / ⌘ / none)
- 60 Hz polling implementation (no Input Monitoring permission required)

#### Shortcuts (global)
- Toggle overlay
- Open settings
- Exclude current app
- Carbon `RegisterEventHotKey` based — works system-wide

#### Rules
- Excluded apps list — overlay disables automatically when an excluded app is focused
- Add apps via file picker or from running-apps menu
- "Highlight all windows of same app" — keeps every window of the active app clear
- "Hide Dock" toggle — overlay excludes Dock area when off; hides Dock entirely when on
- "Hide Menu Bar" toggle — same behavior for the menu bar strip

#### UI
- Control Center–inspired settings window with sidebar navigation
- Material-backed tile cards (CCCard, CCRow, SliderRow components)
- Onboarding tile on first run with dismissible tips
- 4-state menu bar icon (off / deep / ambient / excluded-current)
- Right-click menu bar context menu with current-app indicator

#### Automation
- URL scheme `focuslens://`
  - `focuslens://toggle`
  - `focuslens://enable`
  - `focuslens://disable`
  - `focuslens://settings`
- AppleScript-driveable via `open` command

#### System integration
- `SMAppService` Launch at Login
- Accessibility permission onboarding with live polling (auto-resume after grant)
- Stable across rebuilds with signed Developer ID builds

### Technical
- macOS 14.0 deployment target
- Swift 5.9, SwiftUI for settings, AppKit for overlay windows
- No external dependencies — Apple frameworks only
- XcodeGen-based project generation (`project.yml`)
- MIT licensed

### Known limitations
- Module-cache–based Accessibility permission resets require remove + re-add after unsigned rebuilds
- True variable Gaussian blur radius would need a private `CABackdropLayer` — `NSVisualEffectView` material steps used instead
- Sparkle auto-updater not yet wired up

---

[Unreleased]: https://github.com/parththummar/FocusLens/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/parththummar/FocusLens/releases/tag/v1.0.0
