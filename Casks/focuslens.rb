cask "focuslens" do
  version "1.0.2"
  sha256 "e333c08f3f97440f0391b85596d43aa99e0d2afce3df9dfe2e9ee59bf894ea9b"

  url "https://github.com/parththummar/FocusLens/releases/download/#{version}/FocusLens-#{version}.zip",
      verified: "github.com/parththummar/FocusLens/"
  name "FocusLens"
  desc "Dim every window except the focused one"
  homepage "https://github.com/parththummar/FocusLens"

  livecheck do
    url :url
    strategy :github_latest
  end

  auto_updates false
  depends_on macos: ">= :sonoma"

  app "FocusLens.app"

  # Build is not signed with an Apple Developer ID. Make the app launchable on
  # any Mac out of the box:
  #   1. Strip ALL extended attributes (not just com.apple.quarantine — newer
  #      macOS versions also set com.apple.macl and com.apple.provenance that
  #      can block launch).
  #   2. Force-register the bundle with Launch Services so double-clicking from
  #      Finder / Dock launches the real binary instead of silently failing.
  postflight do
    system_command "/usr/bin/xattr",
                   args: ["-cr", "#{appdir}/FocusLens.app"],
                   sudo: false
    system_command "/System/Library/Frameworks/CoreServices.framework/" \
                   "Versions/A/Frameworks/LaunchServices.framework/" \
                   "Versions/A/Support/lsregister",
                   args: ["-f", "#{appdir}/FocusLens.app"],
                   sudo: false,
                   must_succeed: false
  end

  zap trash: [
    "~/Library/Preferences/com.parththummar.FocusLens.plist",
    "~/Library/Application Support/FocusLens",
    "~/Library/Caches/com.parththummar.FocusLens",
    "~/Library/HTTPStorages/com.parththummar.FocusLens",
    "~/Library/Saved Application State/com.parththummar.FocusLens.savedState",
  ]

  caveats <<~EOS
    FocusLens is currently distributed unsigned. The post-install hook
    strips Gatekeeper attributes automatically, but if the app refuses to
    launch on a fresh Mac, do this once:

      1. Open Finder → /Applications
      2. Right-click FocusLens.app → Open
      3. Click "Open" in the dialog
      4. macOS remembers your choice for every future launch

    Or run this in Terminal once after install:
      xattr -cr /Applications/FocusLens.app

    FocusLens needs Accessibility access to detect which window is focused.
    On first launch, grant access in:
      System Settings → Privacy & Security → Accessibility

    After upgrading, you may need to remove + re-add FocusLens in the
    Accessibility list because macOS binds permissions to the app's code
    signature, which changes between unsigned builds.
  EOS
end
