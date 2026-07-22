#!/bin/bash
# Build distributable Tomochi.zip + Tomochi.dmg for a GitHub Release.
# Requires a universal (arm64 + x86_64) binary; set UNIVERSAL=0 to override for
# local experiments (never for a real release).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

UNIVERSAL="${UNIVERSAL:-1}" bash scripts/build.sh release

if [ "${UNIVERSAL:-1}" = "1" ]; then
    ARCHS="$(lipo -archs Tomochi.app/Contents/MacOS/Tomochi)"
    case "$ARCHS" in
        *arm64*x86_64*|*x86_64*arm64*) echo "▸ Verified universal binary ($ARCHS)";;
        *) echo "❌ Release build must be universal, got: $ARCHS" >&2; exit 1;;
    esac
fi

mkdir -p dist
rm -f dist/Tomochi.zip dist/Tomochi.dmg
# ditto preserves the .app bundle correctly for macOS.
ditto -c -k --keepParent Tomochi.app dist/Tomochi.zip
# DMG with a drag-to-Applications layout for GUI-only installs.
STAGE="$(mktemp -d)"
cp -R Tomochi.app "$STAGE/"
ln -s /Applications "$STAGE/Applications"
hdiutil create -volname "Tomochi" -srcfolder "$STAGE" -ov -format UDZO dist/Tomochi.dmg >/dev/null
rm -rf "$STAGE" Tomochi.app
echo "✓ dist/Tomochi.zip + dist/Tomochi.dmg ready — attach them to a GitHub Release."
echo "  Note: the app is ad-hoc signed (not notarized). First launch needs"
echo "  System Settings → Privacy & Security → Open Anyway (the installer script avoids this)."
