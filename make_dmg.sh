#!/bin/bash
# Build Recorder.dmg — a drag-to-install disk image.
# Requires: hdiutil, osascript (both ship with macOS)
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="Recorder"
APP_BUNDLE="$SCRIPT_DIR/$APP_NAME.app"
DMG_OUT="$SCRIPT_DIR/$APP_NAME.dmg"
TMP_DMG="$SCRIPT_DIR/.tmp_$APP_NAME.dmg"
VOLUME_NAME="$APP_NAME"
MOUNT_POINT="/Volumes/$VOLUME_NAME"

# ── 0. Ensure the app bundle exists ────────────────────────────────────────
if [ ! -d "$APP_BUNDLE" ]; then
    echo "==> App bundle not found, running build.sh first..."
    bash "$SCRIPT_DIR/build.sh"
fi

# ── 1. Generate background image ───────────────────────────────────────────
echo "==> Generating DMG background..."
BG_PNG="$SCRIPT_DIR/.dmg_background.png"
python3 "$SCRIPT_DIR/make_dmg_bg.py" "$BG_PNG"

# ── 2. Unmount any leftover volume from a previous failed run ───────────────
if [ -d "$MOUNT_POINT" ]; then
    echo "==> Unmounting leftover volume..."
    hdiutil detach "$MOUNT_POINT" -quiet -force 2>/dev/null || true
fi
rm -f "$TMP_DMG" "$DMG_OUT"

# ── 3. Create a writable temporary DMG (size: 120 MB) ──────────────────────
echo "==> Creating temporary DMG..."
hdiutil create \
    -size 120m \
    -fs HFS+ \
    -volname "$VOLUME_NAME" \
    -type UDIF \
    "$TMP_DMG" > /dev/null

# ── 4. Mount it ────────────────────────────────────────────────────────────
echo "==> Mounting DMG..."
hdiutil attach "$TMP_DMG" -mountpoint "$MOUNT_POINT" -noautoopen -quiet

# ── 5. Copy app + create Applications symlink ──────────────────────────────
echo "==> Copying files..."
cp -r "$APP_BUNDLE" "$MOUNT_POINT/"
ln -s /Applications "$MOUNT_POINT/Applications"

# ── 6. Copy background image (hidden folder) ───────────────────────────────
mkdir -p "$MOUNT_POINT/.background"
cp "$BG_PNG" "$MOUNT_POINT/.background/background.png"

# ── 7. Set window appearance via AppleScript ───────────────────────────────
echo "==> Styling DMG window..."
osascript <<APPLESCRIPT
tell application "Finder"
    tell disk "$VOLUME_NAME"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {200, 150, 860, 550}
        set viewOptions to the icon view options of container window
        set arrangement of viewOptions to not arranged
        set icon size of viewOptions to 100
        set background picture of viewOptions to file ".background:background.png"
        set position of item "$APP_NAME.app" of container window to {165, 185}
        set position of item "Applications" of container window to {495, 185}
        close
        open
        update without registering applications
        delay 2
        close
    end tell
end tell
APPLESCRIPT

# ── 8. Flush & unmount ─────────────────────────────────────────────────────
echo "==> Finalising..."
sync
hdiutil detach "$MOUNT_POINT" -quiet

# ── 9. Convert to compressed read-only DMG ─────────────────────────────────
echo "==> Compressing DMG..."
hdiutil convert "$TMP_DMG" \
    -format UDZO \
    -imagekey zlib-level=9 \
    -o "$DMG_OUT" > /dev/null

rm -f "$TMP_DMG" "$BG_PNG"

SIZE=$(du -sh "$DMG_OUT" | cut -f1)
echo ""
echo "==> Done!  ($SIZE)"
echo "    $DMG_OUT"
