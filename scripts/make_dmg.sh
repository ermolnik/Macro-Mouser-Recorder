#!/usr/bin/env bash
#
# Build Release Clicker.app and package it into a distributable .dmg.
#
# Usage:
#   ./scripts/make_dmg.sh              # builds dist/Clicker-<version>.dmg
#   ./scripts/make_dmg.sh 1.2.3        # overrides version in filename
#
# Output: dist/Clicker-<version>.dmg
#
# NOTE: the app is ad-hoc signed (CODE_SIGN_IDENTITY="-"), so on the target
# Mac Gatekeeper will block first launch. Tell the recipient to either:
#   1. Right-click Clicker.app → Open → Open, OR
#   2. Run:  xattr -dr com.apple.quarantine /Applications/Clicker.app

set -euo pipefail

# --- paths --------------------------------------------------------------------
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

SCHEME="Clicker"
PROJECT="Clicker.xcodeproj"
CONFIG="Release"
DERIVED="$ROOT/build/dmg"
STAGING="$ROOT/build/dmg-staging"
DIST="$ROOT/dist"

# --- read version from Info.plist --------------------------------------------
INFO_PLIST="$ROOT/Clicker/Resources/Info.plist"
VERSION="${1:-$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$INFO_PLIST")}"
DMG_NAME="Clicker-${VERSION}.dmg"
VOL_NAME="Clicker ${VERSION}"

echo "==> Building ${SCHEME} ${CONFIG} (v${VERSION})"
rm -rf "$DERIVED" "$STAGING"
mkdir -p "$DERIVED" "$STAGING" "$DIST"

xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration "$CONFIG" \
  -destination 'platform=macOS' \
  -derivedDataPath "$DERIVED" \
  clean build \
  | xcbeautify 2>/dev/null || true

APP_SRC="$DERIVED/Build/Products/${CONFIG}/Clicker.app"
if [[ ! -d "$APP_SRC" ]]; then
  echo "ERROR: build did not produce $APP_SRC" >&2
  exit 1
fi

# --- stage the .dmg layout ----------------------------------------------------
echo "==> Staging DMG contents"
cp -R "$APP_SRC" "$STAGING/Clicker.app"
ln -s /Applications "$STAGING/Applications"

# strip xattrs that confuse Gatekeeper / make the dmg dirty
xattr -cr "$STAGING/Clicker.app"

# re-sign ad-hoc so the cdhash matches the post-xattr-strip contents
codesign --force --deep --sign - "$STAGING/Clicker.app"

# --- build the dmg ------------------------------------------------------------
DMG_OUT="$DIST/$DMG_NAME"
rm -f "$DMG_OUT"

echo "==> Creating $DMG_OUT"
hdiutil create \
  -volname "$VOL_NAME" \
  -srcfolder "$STAGING" \
  -ov \
  -format UDZO \
  -fs HFS+ \
  "$DMG_OUT" >/dev/null

# strip Finder-added xattrs (e.g. com.apple.FinderInfo "deviddsk") so receivers
# see a clean file and don't confuse Finder/Gatekeeper
xattr -c "$DMG_OUT" || true

# --- summary ------------------------------------------------------------------
SIZE=$(du -h "$DMG_OUT" | awk '{print $1}')
echo ""
echo "Done."
echo "  File: $DMG_OUT"
echo "  Size: $SIZE"
echo ""
echo "On the target Mac, after copying Clicker.app to /Applications:"
echo "  xattr -dr com.apple.quarantine /Applications/Clicker.app"
echo "Then grant Accessibility in System Settings → Privacy & Security."
