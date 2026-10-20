#!/bin/sh
# Build BudsBar.app (menu-bar app) with SwiftPM and wrap it in an ad-hoc-signed bundle.
# macOS only opens Bluetooth RFCOMM channels for app bundles, so the bare binary cannot be run directly.
#   scripts/build-app.sh            build and launch
#   scripts/build-app.sh --install  also copy to ~/Applications
set -e
cd "$(dirname "$0")/.."
swift build -c release --product BudsBar
APP=.build/BudsBar.app
pkill -x BudsBar 2>/dev/null || true
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp .build/release/BudsBar "$APP/Contents/MacOS/BudsBar"
cat > "$APP/Contents/Info.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleIdentifier</key><string>local.yash.budsbar</string>
  <key>CFBundleName</key><string>BudsBar</string>
  <key>CFBundleDisplayName</key><string>Buds</string>
  <key>CFBundleExecutable</key><string>BudsBar</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>0.1</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSUIElement</key><true/>
  <key>NSBluetoothAlwaysUsageDescription</key><string>Buds talks to your OnePlus Buds 4 to show battery and change settings.</string>
</dict>
</plist>
EOF
codesign --force --sign - "$APP"
if [ "$1" = "--install" ]; then
  mkdir -p "$HOME/Applications"
  rm -rf "$HOME/Applications/BudsBar.app"
  cp -R "$APP" "$HOME/Applications/BudsBar.app"
  APP="$HOME/Applications/BudsBar.app"
fi
open "$APP"
echo "Launched $APP"
