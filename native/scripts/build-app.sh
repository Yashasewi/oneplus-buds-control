#!/bin/sh
# Build OpenBuds.app (menu-bar app) with SwiftPM and wrap it in an ad-hoc-signed bundle.
# macOS only opens Bluetooth RFCOMM channels for app bundles, so the bare binary cannot be run directly.
#   scripts/build-app.sh            build and launch
#   scripts/build-app.sh --install  also copy to /Applications and launch from there
set -e
cd "$(dirname "$0")/.."
# SwiftUI's macros (@State, #Preview) need full Xcode, not just the Command Line Tools.
if [ -z "$DEVELOPER_DIR" ] && [ -d /Applications/Xcode.app ]; then
  export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
fi
swift build -c release --product OpenBuds
APP=.build/OpenBuds.app
pkill -x OpenBuds 2>/dev/null || true
pkill -x BudsBar 2>/dev/null || true
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/OpenBuds "$APP/Contents/MacOS/OpenBuds"
cp Support/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
cat > "$APP/Contents/Info.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleIdentifier</key><string>local.yash.openbuds</string>
  <key>CFBundleName</key><string>OpenBuds</string>
  <key>CFBundleDisplayName</key><string>OpenBuds</string>
  <key>CFBundleExecutable</key><string>OpenBuds</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>0.2</string>
  <key>CFBundleVersion</key><string>2</string>
  <key>LSMinimumSystemVersion</key><string>26.0</string>
  <key>LSUIElement</key><true/>
  <key>NSBluetoothAlwaysUsageDescription</key><string>OpenBuds talks to your OnePlus Buds 4 to show battery and change settings.</string>
</dict>
</plist>
EOF
codesign --force --sign - "$APP"
if [ "$1" = "--install" ]; then
  rm -rf /Applications/OpenBuds.app /Applications/BudsBar.app "$HOME/Applications/BudsBar.app"
  cp -R "$APP" /Applications/OpenBuds.app
  APP=/Applications/OpenBuds.app
fi
open "$APP"
echo "Launched $APP"
