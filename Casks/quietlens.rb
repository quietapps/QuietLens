cask "quietlens" do
  version "1.0.3"
  sha256 :no_check  # set by scripts/release.sh output

  url "https://github.com/quietapps/QuietLens/releases/download/#{version}/QuietLens-#{version}.zip",
      verified: "github.com/quietapps/QuietLens/"
  name "Quiet Lens"
  desc "Dim every window except the focused one"
  homepage "https://github.com/quietapps/QuietLens"

  livecheck do
    url :url
    strategy :github_latest
  end

  auto_updates false
  depends_on macos: ">= :sonoma"

  app "Quiet Lens.app"

  # Build is not signed with an Apple Developer ID. Make the app launchable on
  # any Mac out of the box:
  #   1. Strip ALL extended attributes (com.apple.quarantine, com.apple.macl,
  #      com.apple.provenance) so Gatekeeper does not block launch.
  #   2. Force-register the bundle with Launch Services so double-clicking from
  #      Finder / Dock launches the real binary.
  postflight do
    system_command "/usr/bin/xattr",
                   args: ["-cr", "#{appdir}/Quiet Lens.app"],
                   sudo: false
    system_command "/System/Library/Frameworks/CoreServices.framework/" \
                   "Versions/A/Frameworks/LaunchServices.framework/" \
                   "Versions/A/Support/lsregister",
                   args: ["-f", "#{appdir}/Quiet Lens.app"],
                   sudo: false,
                   must_succeed: false
  end

  zap trash: [
    "~/Library/Preferences/app.quiet.QuietLens.plist",
    "~/Library/Application Support/Quiet Lens",
    "~/Library/Caches/app.quiet.QuietLens",
    "~/Library/HTTPStorages/app.quiet.QuietLens",
    "~/Library/Saved Application State/app.quiet.QuietLens.savedState",
  ]

  caveats <<~EOS
    Quiet Lens is currently distributed unsigned. The post-install hook
    strips Gatekeeper attributes automatically, but if the app refuses to
    launch on a fresh Mac, do this once:

      1. Open Finder → /Applications
      2. Right-click Quiet Lens.app → Open
      3. Click "Open" in the dialog
      4. macOS remembers your choice for every future launch

    Or run this in Terminal once after install:
      xattr -cr "/Applications/Quiet Lens.app"

    Quiet Lens needs Accessibility access to detect which window is focused.
    On first launch, grant access in:
      System Settings → Privacy & Security → Accessibility

    After upgrading, you may need to remove + re-add Quiet Lens in the
    Accessibility list because macOS binds permissions to the app's code
    signature, which changes between unsigned builds.
  EOS
end
