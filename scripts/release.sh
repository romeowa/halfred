#!/bin/bash
set -euo pipefail

# ─── Config ───
APP_NAME="Halfred"
BUNDLE_ID="com.howard.halfred"
TEAM_ID="76222M8V56"
SIGN_IDENTITY="Developer ID Application: yunjin han (${TEAM_ID})"
VERSION=$(grep 'MARKETING_VERSION' project.yml | head -1 | sed 's/.*"\(.*\)"/\1/')

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="${PROJECT_DIR}/build"
ARCHIVE_PATH="${BUILD_DIR}/${APP_NAME}.xcarchive"
APP_PATH="${BUILD_DIR}/${APP_NAME}.app"
DMG_PATH="${BUILD_DIR}/${APP_NAME}-${VERSION}.dmg"
DMG_TEMP="${BUILD_DIR}/dmg-staging"

cd "$PROJECT_DIR"

echo "═══════════════════════════════════════"
echo "  ${APP_NAME} Release Build v${VERSION}"
echo "═══════════════════════════════════════"

# ─── Clean ───
echo ""
echo "▸ Cleaning build directory..."
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# ─── Generate Xcode project ───
echo "▸ Generating Xcode project..."
xcodegen generate

# ─── Archive ───
echo "▸ Archiving..."
xcodebuild archive \
    -project "${APP_NAME}.xcodeproj" \
    -scheme "${APP_NAME}" \
    -configuration Release \
    -archivePath "$ARCHIVE_PATH" \
    CODE_SIGN_IDENTITY="$SIGN_IDENTITY" \
    DEVELOPMENT_TEAM="$TEAM_ID" \
    ENABLE_HARDENED_RUNTIME=YES \
    OTHER_CODE_SIGN_FLAGS="--options=runtime" \
    -quiet

# ─── Export app from archive ───
echo "▸ Exporting app..."
cp -R "${ARCHIVE_PATH}/Products/Applications/${APP_NAME}.app" "$APP_PATH"

# ─── Verify signing ───
echo "▸ Verifying code signature..."
codesign --verify --deep --strict "$APP_PATH"
echo "  ✓ Code signature valid"

# ─── Notarize ───
echo "▸ Submitting for notarization..."
ZIP_PATH="${BUILD_DIR}/${APP_NAME}.zip"
ditto -c -k --keepParent "$APP_PATH" "$ZIP_PATH"

xcrun notarytool submit "$ZIP_PATH" \
    --keychain-profile "notarytool" \
    --wait

echo "▸ Stapling notarization ticket..."
xcrun stapler staple "$APP_PATH"
echo "  ✓ Notarization complete"

rm -f "$ZIP_PATH"

# ─── Create DMG ───
echo "▸ Creating DMG..."
rm -rf "$DMG_TEMP"
mkdir -p "$DMG_TEMP"
cp -R "$APP_PATH" "$DMG_TEMP/"
ln -s /Applications "$DMG_TEMP/Applications"

hdiutil create -volname "$APP_NAME" \
    -srcfolder "$DMG_TEMP" \
    -ov -format UDZO \
    "$DMG_PATH" \
    -quiet

rm -rf "$DMG_TEMP"

# ─── Sign & notarize DMG ───
echo "▸ Signing DMG..."
codesign --sign "$SIGN_IDENTITY" "$DMG_PATH"

echo "▸ Notarizing DMG..."
xcrun notarytool submit "$DMG_PATH" \
    --keychain-profile "notarytool" \
    --wait

xcrun stapler staple "$DMG_PATH"
echo "  ✓ DMG ready"

# ─── GitHub Release ───
echo ""
echo "▸ Creating GitHub Release v${VERSION}..."
TAG="v${VERSION}"

if gh release view "$TAG" &>/dev/null; then
    echo "  Release ${TAG} already exists. Uploading asset..."
    gh release upload "$TAG" "$DMG_PATH" --clobber
else
    gh release create "$TAG" "$DMG_PATH" \
        --title "${APP_NAME} ${TAG}" \
        --notes "## ${APP_NAME} ${TAG}

### Install
1. Download **${APP_NAME}-${VERSION}.dmg**
2. Open the DMG and drag **${APP_NAME}** to **Applications**
3. Launch ${APP_NAME} from Applications
4. Grant Accessibility permission when prompted (first launch only)

### Shortcuts
- **⌥ Space** — Open command palette
- **⌥⌘←** — Snap window left (cycle: min → 1/2 → 2/3)
- **⌥⌘→** — Snap window right
- **⌥⌘↑** — Fullscreen"
fi

echo ""
echo "═══════════════════════════════════════"
echo "  ✓ Release complete!"
echo "  DMG: ${DMG_PATH}"
echo "  GitHub: $(gh release view "$TAG" --json url -q .url)"
echo "═══════════════════════════════════════"
