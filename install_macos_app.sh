#!/usr/bin/env bash
set -euo pipefail

# Navigate to the folder where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "1/4 Compiling HabitFlow (Release build)..."
swift build -c release

APP_NAME="HabitFlow.app"
DEST_DIR="/Applications/$APP_NAME"
CONTENTS_DIR="$DEST_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

echo "2/4 Creating macOS application bundle at $DEST_DIR..."
rm -rf "$DEST_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

cp ".build/release/HabitFlow" "$MACOS_DIR/HabitFlow"
chmod +x "$MACOS_DIR/HabitFlow"

echo "3/4 Writing Info.plist..."
cat << 'PLIST' > "$CONTENTS_DIR/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>HabitFlow</string>
    <key>CFBundleIdentifier</key>
    <string>com.habitflow.macos.app</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>HabitFlow</string>
    <key>CFBundleDisplayName</key>
    <string>HabitFlow</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
</dict>
</plist>
PLIST

echo "4/4 Signing HabitFlow.app for local macOS execution & notifications..."
codesign --force --deep --sign - "$DEST_DIR"

echo "Done! HabitFlow.app is now installed in /Applications."
echo "Opening HabitFlow..."
open "$DEST_DIR"
