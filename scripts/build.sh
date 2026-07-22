#!/bin/bash
# Build Tomochi.app from the SwiftPM executable and assemble a macOS app bundle.
# UNIVERSAL=1 (used by release.sh/CI) builds arm64 + x86_64 separately and merges
# with lipo — a single multi-arch `swift build` silently fails on CI runners.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG="${1:-release}"
APP="$ROOT/Tomochi.app"
cd "$ROOT"

if [ "${UNIVERSAL:-0}" = "1" ]; then
    echo "▸ Building ($CONFIG, arm64)…"
    swift build -c "$CONFIG" --arch arm64
    echo "▸ Building ($CONFIG, x86_64)…"
    swift build -c "$CONFIG" --arch x86_64
    BIN_ARM="$(swift build -c "$CONFIG" --arch arm64 --show-bin-path)/Tomochi"
    BIN_X86="$(swift build -c "$CONFIG" --arch x86_64 --show-bin-path)/Tomochi"
    mkdir -p "$ROOT/.build/universal"
    BIN="$ROOT/.build/universal/Tomochi"
    lipo -create "$BIN_ARM" "$BIN_X86" -o "$BIN"
    echo "▸ Universal binary: $(lipo -archs "$BIN")"
else
    echo "▸ Building ($CONFIG, native arch)…"
    swift build -c "$CONFIG"
    BIN="$(swift build -c "$CONFIG" --show-bin-path)/Tomochi"
fi

echo "▸ Assembling Tomochi.app…"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/Tomochi"
cp "$ROOT/Info.plist" "$APP/Contents/Info.plist"
[ -f "$ROOT/Resources/AppIcon.icns" ] && cp "$ROOT/Resources/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"

# Embed Sparkle.framework so the bundle is self-contained outside the build dir.
SPARKLE="$ROOT/.build/artifacts/sparkle/Sparkle/Sparkle.xcframework/macos-arm64_x86_64/Sparkle.framework"
if [ -d "$SPARKLE" ]; then
    mkdir -p "$APP/Contents/Frameworks"
    cp -R "$SPARKLE" "$APP/Contents/Frameworks/"
    install_name_tool -add_rpath "@executable_path/../Frameworks" "$APP/Contents/MacOS/Tomochi" 2>/dev/null || true
else
    echo "⚠️  Sparkle.framework not found at $SPARKLE — updates won't work in this build." >&2
fi

# Sign the embedded framework first (covers its nested XPC services), then the app.
if [ -d "$APP/Contents/Frameworks/Sparkle.framework" ]; then
    codesign --force --deep --sign - "$APP/Contents/Frameworks/Sparkle.framework"
fi
codesign --force --sign - "$APP"

echo "✓ Built $APP"
