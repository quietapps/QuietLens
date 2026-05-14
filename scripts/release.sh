#!/usr/bin/env bash
# Release helper (unsigned / free-tier build).
#
# Usage:
#   bash scripts/release.sh 1.0.1
#
# Produces a build/FocusLens-VERSION.zip ready for GitHub Release upload.
# The app is ad-hoc signed — users must install via Homebrew with
# `--no-quarantine`, or strip the quarantine xattr manually.
#
# When you later get an Apple Developer ID, switch to scripts/release-signed.sh
# (write your own version with notarytool + stapler steps).
set -euo pipefail

VERSION="${1:?usage: release.sh VERSION (e.g. 1.0.1)}"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD="$ROOT/build"
ARCHIVE="$BUILD/FocusLens.xcarchive"
APP="$ARCHIVE/Products/Applications/FocusLens.app"
ZIP="$BUILD/FocusLens-${VERSION}.zip"

rm -rf "$BUILD"
mkdir -p "$BUILD"

echo "==> Regenerate Xcode project"
(cd "$ROOT" && xcodegen generate)

echo "==> Archive (ad-hoc signed)"
xcodebuild -project "$ROOT/FocusLens.xcodeproj" -scheme FocusLens \
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
echo "  gh release create v$VERSION '$ZIP' \\"
echo "    --title 'FocusLens $VERSION' \\"
echo "    --notes-file CHANGELOG.md"
echo
echo "Then update parththummar/homebrew-focuslens Casks/focuslens.rb:"
echo "  version \"$VERSION\""
echo "  sha256 \"$SHA\"  (or keep :no_check)"
