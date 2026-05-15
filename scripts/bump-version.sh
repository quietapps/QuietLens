#!/usr/bin/env bash
# Bump app version in one place. Propagates to:
#   - project.yml  (MARKETING_VERSION + CURRENT_PROJECT_VERSION)
#   - Info.plist   (auto via $(MARKETING_VERSION) substitution at build time)
#   - About screen (auto via Bundle.main.infoDictionary)
#   - Casks/quietlens.rb (version line)
#
# Usage:
#   bash scripts/bump-version.sh 1.0.4         # bumps build by +1 automatically
#   bash scripts/bump-version.sh 1.0.4 7       # explicit build number
#
# After bumping, run `xcodegen generate` (this script does it for you).
set -euo pipefail

VERSION="${1:?usage: bump-version.sh VERSION [BUILD]}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
YML="$ROOT/project.yml"
CASK="$ROOT/Casks/quietlens.rb"

current_build=$(grep -E '^\s*CURRENT_PROJECT_VERSION:' "$YML" | sed -E 's/.*"([0-9]+)".*/\1/')
BUILD="${2:-$((current_build + 1))}"

# Update project.yml
/usr/bin/sed -i '' -E "s/(MARKETING_VERSION:[[:space:]]*\")[^\"]+\"/\1${VERSION}\"/" "$YML"
/usr/bin/sed -i '' -E "s/(CURRENT_PROJECT_VERSION:[[:space:]]*\")[^\"]+\"/\1${BUILD}\"/" "$YML"

# Update Cask (reset sha256 so release.sh can re-pin it)
/usr/bin/sed -i '' -E "s/^(  version )\".*\"/\1\"${VERSION}\"/" "$CASK"
/usr/bin/sed -i '' -E 's/^(  sha256 ).*/\1:no_check  # set by scripts\/release.sh output/' "$CASK"

# Regenerate Xcode project so the new version takes effect
(cd "$ROOT" && xcodegen generate >/dev/null)

echo "Bumped to ${VERSION} (build ${BUILD})."
echo "  project.yml:       MARKETING_VERSION=${VERSION}, CURRENT_PROJECT_VERSION=${BUILD}"
echo "  Casks/quietlens.rb: version=\"${VERSION}\" (sha256 reset)"
echo
echo "Next:"
echo "  bash scripts/release.sh ${VERSION}"
echo "  # then paste the new sha256 into Casks/quietlens.rb"
