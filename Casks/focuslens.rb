cask "focuslens" do
  version "1.0.0"
  sha256 "a95e70037b9dfeaa2c7b903e94e941abb08dd6b20f1ca0823169fc9704b0d3d8"

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

  # Build is not signed with an Apple Developer ID. Install with:
  #   brew install --cask --no-quarantine focuslens
  # The --no-quarantine flag is required so Gatekeeper does not block launch.

  zap trash: [
    "~/Library/Preferences/com.parththummar.FocusLens.plist",
    "~/Library/Application Support/FocusLens",
    "~/Library/Caches/com.parththummar.FocusLens",
    "~/Library/HTTPStorages/com.parththummar.FocusLens",
    "~/Library/Saved Application State/com.parththummar.FocusLens.savedState",
  ]

  caveats <<~EOS
    FocusLens is currently distributed unsigned. Install with:
      brew install --cask --no-quarantine focuslens

    FocusLens needs Accessibility access to detect which window is focused.
    On first launch, grant access in System Settings → Privacy & Security → Accessibility.

    Heads-up: after upgrading, you may need to remove + re-add FocusLens
    in the Accessibility list because macOS binds permissions to the app's
    code signature, which changes between unsigned builds.
  EOS
end
