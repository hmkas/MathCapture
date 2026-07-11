#!/bin/bash
set -euo pipefail

ICON_DIR="$(dirname "$0")/../Resources/AppIcon.iconset"
SCRIPT_DIR="$(dirname "$0")"
mkdir -p "$ICON_DIR"

echo "==> Generating 1024x1024 base icon..."
swift "$SCRIPT_DIR/generate_icon.swift" "/tmp/mathcapture_icon_1024.png"

echo "==> Resizing to all required sizes..."
sips -z 16 16   "/tmp/mathcapture_icon_1024.png" --out "$ICON_DIR/icon_16x16.png" &>/dev/null
sips -z 32 32   "/tmp/mathcapture_icon_1024.png" --out "$ICON_DIR/icon_16x16@2x.png" &>/dev/null
sips -z 32 32   "/tmp/mathcapture_icon_1024.png" --out "$ICON_DIR/icon_32x32.png" &>/dev/null
sips -z 64 64   "/tmp/mathcapture_icon_1024.png" --out "$ICON_DIR/icon_32x32@2x.png" &>/dev/null
sips -z 128 128 "/tmp/mathcapture_icon_1024.png" --out "$ICON_DIR/icon_128x128.png" &>/dev/null
sips -z 256 256 "/tmp/mathcapture_icon_1024.png" --out "$ICON_DIR/icon_128x128@2x.png" &>/dev/null
sips -z 256 256 "/tmp/mathcapture_icon_1024.png" --out "$ICON_DIR/icon_256x256.png" &>/dev/null
sips -z 512 512 "/tmp/mathcapture_icon_1024.png" --out "$ICON_DIR/icon_256x256@2x.png" &>/dev/null
sips -z 512 512 "/tmp/mathcapture_icon_1024.png" --out "$ICON_DIR/icon_512x512.png" &>/dev/null
cp "/tmp/mathcapture_icon_1024.png" "$ICON_DIR/icon_512x512@2x.png"

echo "==> Creating .icns..."
iconutil -c icns "$ICON_DIR" -o "$(dirname "$0")/../Resources/AppIcon.icns"

# Clean up
rm -rf "$ICON_DIR" "/tmp/mathcapture_icon_1024.png"

echo "✅ App icon created: Resources/AppIcon.icns"
