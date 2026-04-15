#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="Recorder"
BUNDLE_ID="com.zhangzhongjun.recorder"
BUILD_DIR="$SCRIPT_DIR/.build/release"
APP_BUNDLE="$SCRIPT_DIR/$APP_NAME.app"

echo "==> Building $APP_NAME..."
cd "$SCRIPT_DIR"
swift build -c release 2>&1

echo "==> Creating app bundle..."
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# Copy binary
cp "$BUILD_DIR/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"

# Copy Info.plist
cp "$SCRIPT_DIR/Info.plist" "$APP_BUNDLE/Contents/Info.plist"

# Generate icon using make_icon.py
echo "==> Generating icon..."
ICONSET_DIR="$APP_BUNDLE/Contents/Resources/AppIcon.iconset"
python3 "$SCRIPT_DIR/make_icon.py" "$ICONSET_DIR"

# Convert iconset → .icns, then remove the iconset directory
if command -v iconutil &> /dev/null; then
    iconutil -c icns "$ICONSET_DIR" -o "$APP_BUNDLE/Contents/Resources/AppIcon.icns"
    rm -rf "$ICONSET_DIR"
    echo "  AppIcon.icns created"
fi

echo "==> Signing app bundle (ad-hoc)..."
codesign --deep --force --sign - \
    --entitlements "$SCRIPT_DIR/Recorder.entitlements" \
    "$APP_BUNDLE" 2>&1

echo "==> Done!"
echo ""
echo "App bundle: $APP_BUNDLE"
echo ""
echo "要运行应用，请执行："
echo "  open '$APP_BUNDLE'"
echo ""
echo "首次运行需要授予以下权限（系统会自动提示）："
echo "  1. 屏幕录制 - 用于捕获系统音频"
echo "  2. 语音识别 - 用于转写文字"
echo ""
echo "如果权限被拒绝，前往：系统偏好设置 > 隐私与安全性"
