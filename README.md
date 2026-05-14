<div align="center">

<img src="FocusLens/Resources/Assets.xcassets/AppIcon.appiconset/icon_512x512.png" alt="FocusLens" width="128" height="128" />

# FocusLens

**Dim everything except your active window.**

A native macOS menu bar app that blurs every window except the one you're working in — so you can focus on one task at a time.

[![macOS](https://img.shields.io/badge/macOS-14.0+-000000?logo=apple&logoColor=white)](https://www.apple.com/macos/)
[![Swift](https://img.shields.io/badge/Swift-5.9-F05138?logo=swift&logoColor=white)](https://swift.org)
[![SwiftUI](https://img.shields.io/badge/SwiftUI-AppKit-2396F3?logo=swift&logoColor=white)](https://developer.apple.com/xcode/swiftui/)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Release](https://img.shields.io/github/v/release/parththummar/FocusLens?display_name=tag)](https://github.com/parththummar/FocusLens/releases)
[![Downloads](https://img.shields.io/github/downloads/parththummar/FocusLens/total.svg)](https://github.com/parththummar/FocusLens/releases)
[![Stars](https://img.shields.io/github/stars/parththummar/FocusLens?style=social)](https://github.com/parththummar/FocusLens/stargazers)

[Download](#installation) · [Features](#features) · [Usage](#usage) · [Build from source](#build-from-source) · [Contributing](#contributing)

</div>

---

## Why

You have ten apps open. You only need one. FocusLens covers everything else with a soft frosted-glass dim — the active window stays crisp, the rest fades into background noise. Click through to the next window and the dim moves with you, smooth and animated. Shake your cursor to toggle. No new keybinding to learn, no app switcher to fight.

Inspired by [Monocle](https://iamdk.gumroad.com/l/monocle-elegant-macos-window-blur-focus). Rebuilt from scratch, **free and open source under MIT**.

## Features

### Two focus modes
- **Deep** — full-screen frosted-glass dim, heavy tint everywhere except your active window
- **Ambient** — subtle vertical-fade gradient, cinematic backdrop instead of full coverage

### Real visual control
- Variable blur radius **0–50**
- Opacity **10–100%**
- 9 system colors + rainbow color picker + **As System** (matches your macOS accent color)
- Optional gradient tint with custom second color + angle
- High-frequency film grain with soft-light blend (subtle to heavy)
- Grayscale background filter
- Animated shader modes: **Static / Breathing / Drift / Pulse**

### Smart window tracking
- Per-screen active window detection — focus Xcode on monitor 1 + Slack on monitor 2, both stay clear
- Optional **highlight all windows of same app** for multi-window workflows (Xcode editors, Figma boards)
- Smooth animated cutout transitions when you switch windows
- AX-based focus tracking + CGWindowList fallback

### Gestures & shortcuts
- **Shake to toggle** — wiggle the cursor in any direction (2D detection, configurable sensitivity)
- **Shake-to-peek** — hold ⇧ + shake to temporarily reveal everything
- Three global hotkeys: toggle overlay, open settings, exclude current app

### Rules
- Exclude any app from the overlay (via picker or running-app list)
- Auto-hide Dock when active
- Auto-hide Menu Bar when active
- Drag-and-drop awareness — overlay fades out while you drag a file, fades back when you drop

### Native macOS feel
- Menu bar agent (no Dock icon)
- Control Center–style settings UI built in SwiftUI
- URL scheme automation: `focuslens://toggle | enable | disable | settings`
- Multi-display aware, hot-swappable monitors
- Onboarding for Accessibility permission

## Installation

> **Note:** FocusLens is not yet code-signed with an Apple Developer ID. macOS Gatekeeper will warn on first launch. The steps below work around it. A signed/notarized build is on the roadmap.

### Homebrew (recommended)

```bash
brew tap parththummar/focuslens
brew install --cask focuslens
```

The cask strips the macOS quarantine attribute on install so Gatekeeper does not block launch (the build is currently unsigned). The tap is community-maintained at [parththummar/homebrew-focuslens](https://github.com/parththummar/homebrew-focuslens).

### Direct download

1. Grab `FocusLens.zip` from the [latest release](https://github.com/parththummar/FocusLens/releases/latest)
2. Unzip → drag `FocusLens.app` into `/Applications`
3. Strip the quarantine attribute (or `Right-click → Open` once):

```bash
xattr -dr com.apple.quarantine /Applications/FocusLens.app
```

4. Launch FocusLens
5. Grant **Accessibility** access when prompted (System Settings → Privacy & Security → Accessibility)

### Heads-up about unsigned builds

- After every new release, you may need to **remove + re-add FocusLens** in System Settings → Privacy & Security → Accessibility. macOS ties the permission to the app's code-signature hash, and unsigned builds change hash each time.
- Right-click → Open works as a one-time bypass if `xattr` feels intimidating.
- If Gatekeeper still blocks the app, open **System Settings → Privacy & Security**, scroll to the message about FocusLens, click **Open Anyway**.

## Usage

| Action | How |
|---|---|
| Toggle overlay | Click menu bar icon, or shake cursor, or your global hotkey |
| Peek through | Hold ⇧ + shake to reveal everything temporarily |
| Switch focus | Just click another window — the dim follows your focus |
| Exclude current app | Right-click menu bar icon → **Exclude Current App** |
| Open settings | Right-click menu bar icon → **Settings…** |
| Quit | Right-click menu bar icon → **Quit** |

### Menu bar icon states

| Icon | Meaning |
|------|---------|
| `circle` | Overlay off |
| `circle.lefthalf.filled` | Deep mode active |
| `circle.righthalf.filled` | Ambient mode active |
| `circle.dashed` | Current app excluded — overlay paused |

### URL scheme

Drive FocusLens from Shortcuts, AppleScript, or a Terminal:

```bash
open "focuslens://toggle"
open "focuslens://enable"
open "focuslens://disable"
open "focuslens://settings"
```

## Permissions

FocusLens needs **Accessibility** access to detect which window you're focused on.

On first launch you'll see an onboarding window with a one-click button to **System Settings → Privacy & Security → Accessibility**. Flip the FocusLens switch on. The app polls every 1.5s and starts the moment you grant access — no restart needed.

> **Heads up:** macOS ties Accessibility permission to the app's **code signature**. If you rebuild FocusLens from source the signature changes and the old permission entry no longer matches. Fix: remove FocusLens from the Accessibility list and add it again. Signed release builds don't have this problem.

## Build from source

### Requirements
- macOS 14.0+
- Xcode 15.0+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (project file is generated, not committed)

### Steps

```bash
git clone https://github.com/parththummar/FocusLens.git
cd FocusLens
brew install xcodegen
xcodegen generate
open FocusLens.xcodeproj
```

Hit ⌘R in Xcode. Or from the command line:

```bash
xcodebuild -project FocusLens.xcodeproj -scheme FocusLens -configuration Release build
```

The built `.app` lands in `~/Library/Developer/Xcode/DerivedData/FocusLens-*/Build/Products/Release/`.

### Project layout

```
FocusLens/
├── App/             # App entry point, AppDelegate, status item
├── Core/            # WindowTracker, OverlayManager, ShakeDetector, HotkeyManager, AutomationHandler
├── Overlay/         # OverlayWindow, BlurOverlayView, CutoutView
├── Views/           # SettingsView, AppearanceSettings, GestureSettings, RulesSettings, OnboardingView
├── Models/          # Settings, ExcludedApp, TintPreset, OverlayMode, ShaderMode
└── Resources/       # Info.plist, entitlements, Assets.xcassets
```

No external dependencies — Apple frameworks only (AppKit, SwiftUI, CoreImage, Accessibility, Carbon hotkeys, ServiceManagement).

## Configuration

Settings live in `UserDefaults` under your standard suite. Reset everything with:

```bash
defaults delete com.parththummar.FocusLens
```

## Contributing

PRs welcome. Before opening one:

1. Open an issue describing the change
2. Keep changes focused — one feature or fix per PR
3. Match the existing code style (Swift API design guidelines, no force-unwraps in new code)
4. Verify the project builds with `xcodebuild` before pushing

## Roadmap

- [ ] Sparkle auto-updater
- [ ] Per-app overlay profiles (different blur for different excluded apps)
- [ ] Sensitivity tick slider keyboard navigation
- [ ] Custom Metal shader for true variable blur
- [ ] Localization (PRs welcome)

## FAQ

**Does this slow my Mac down?**
No. The overlay only redraws when the focused window changes. CPU stays under ~1% idle.

**Why is the menu bar dimmed?**
Toggle **Rules → Hide Menu Bar** off — the overlay will stop covering the menu bar strip.

**My cursor shake doesn't trigger the toggle.**
Drop **Sensitivity** in Settings → Gestures toward **Very High**, then try a brisk zigzag. Detection is 2D — any direction works.

**Can I use the system accent color as the tint?**
Yes — Settings → Appearance → Tint → tap **As System**.

**Does it work with multiple displays?**
Yes. Each display gets its own overlay and its own active-window cutout independently.

## License

[MIT](LICENSE) © Parth Thummar

Inspired by [Monocle](https://iamdk.gumroad.com/l/monocle-elegant-macos-window-blur-focus). Independent implementation. No code shared.

---

<div align="center">
If FocusLens helps you focus, drop a ⭐ on the repo.
</div>
