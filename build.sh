#!/bin/bash
set -euo pipefail

APP_NAME="MathCapture"
CONFIG="${1:-debug}"

if [ "$CONFIG" = "release" ]; then
    BUILD_DIR=".build/release"
    SWIFT_FLAGS="-c release"
else
    BUILD_DIR=".build/debug"
    SWIFT_FLAGS=""
fi

echo "==> Building $APP_NAME ($CONFIG)..."

swift build $SWIFT_FLAGS

echo "==> Creating .app bundle..."

APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

cp "$BUILD_DIR/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"

# Generate icon if needed
ICON_SRC="Resources/AppIcon.icns"
if [ ! -f "$ICON_SRC" ]; then
    echo "==> Generating app icon..."
    bash Scripts/make_icon.sh
fi
cp "$ICON_SRC" "$APP_BUNDLE/Contents/Resources/AppIcon.icns"

cat > "$APP_BUNDLE/Contents/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleDevelopmentRegion</key>
	<string>nl</string>
	<key>CFBundleDisplayName</key>
	<string>MathCapture</string>
	<key>CFBundleExecutable</key>
	<string>$APP_NAME</string>
	<key>CFBundleIconFile</key>
	<string>AppIcon</string>
	<key>CFBundleIdentifier</key>
	<string>com.maarten.mathcapture</string>
	<key>CFBundleInfoDictionaryVersion</key>
	<string>6.0</string>
	<key>CFBundleName</key>
	<string>MathCapture</string>
	<key>CFBundlePackageType</key>
	<string>APPL</string>
	<key>CFBundleShortVersionString</key>
	<string>1.0</string>
	<key>CFBundleVersion</key>
	<string>1</string>
	<key>LSApplicationCategoryType</key>
	<string>public.app-category.productivity</string>
	<key>LSMinimumSystemVersion</key>
	<string>14.0</string>
	<key>LSUIElement</key>
	<true/>
	<key>NSHighResolutionCapable</key>
	<true/>
	<key>NSHumanReadableCopyright</key>
	<string>MIT License</string>
	<key>NSPrincipalClass</key>
	<string>NSApplication</string>
	<key>NSSupportsAutomaticTermination</key>
	<true/>
</dict>
</plist>
EOF

echo "==> Signing bundle (ad-hoc)..."
codesign --force --sign - "$APP_BUNDLE" --identifier "com.maarten.mathcapture" --options runtime

echo "==> Moving to project root..."
DEST="$PWD/$APP_NAME.app"
rm -rf "$DEST"
mv "$APP_BUNDLE" "$DEST"

echo ""
echo "✅ App bundle created: $DEST"
echo "   Run with: open \"$DEST\""
