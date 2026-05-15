#!/usr/bin/env bash
# Release helper (unsigned / free-tier build).
#
# Usage:
#   bash scripts/release.sh 1.0.3
#
# Produces build/QuietLens-VERSION.zip ready for GitHub Release upload.
# The app is ad-hoc signed — users must install via Homebrew which strips
# the quarantine xattr automatically.
set -euo pipefail

VERSION="${1:?usage: release.sh VERSION (e.g. 1.0.3)}"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD="$ROOT/build"
ARCHIVE="$BUILD/QuietLens.xcarchive"
APP="$ARCHIVE/Products/Applications/Quiet Lens.app"
ZIP="$BUILD/QuietLens-${VERSION}.zip"

rm -rf "$BUILD"
mkdir -p "$BUILD"

echo "==> Regenerate Xcode project"
(cd "$ROOT" && xcodegen generate)

echo "==> Archive (ad-hoc signed)"
xcodebuild -project "$ROOT/QuietLens.xcodeproj" -scheme QuietLens \
  -configuration Release \
  -archivePath "$ARCHIVE" \
  -destination 'generic/platform=macOS' \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=YES \
  archive

echo "==> Zip"
ditto -c -k --keepParent "$APP" "$ZIP"

SHA=$(shasum -a 256 "$ZIP" | awk '{print $1}')
SIZE=$(du -h "$ZIP" | awk '{print $1}')

echo
echo "Artifact: $ZIP ($SIZE)"
echo "sha256:   $SHA"
echo
echo "Next:"
echo "  gh release create $VERSION '$ZIP' -R quietapps/QuietLens \\"
echo "    --title 'Quiet Lens $VERSION' \\"
echo "    --notes-file CHANGELOG.md"
echo
echo "Then update quietapps/homebrew-quietlens Casks/quietlens.rb:"
echo "  version \"$VERSION\""
echo "  sha256 \"$SHA\""
