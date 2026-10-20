#!/bin/sh
# macOS refuses RFCOMM channels to a bare binary launched from a terminal, but allows them to an
# app bundle launched by LaunchServices. Wrap budsprobe in a minimal ad-hoc-signed .app and run it.
set -e
cd "$(dirname "$0")/.."
swift build
APP=.build/BudsProbe.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp .build/debug/budsprobe "$APP/Contents/MacOS/budsprobe"
cat > "$APP/Contents/Info.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleIdentifier</key><string>local.yash.budsprobe</string>
  <key>CFBundleName</key><string>BudsProbe</string>
  <key>CFBundleExecutable</key><string>budsprobe</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>LSUIElement</key><true/>
  <key>NSBluetoothAlwaysUsageDescription</key><string>BudsProbe talks to your OnePlus Buds 4 to read battery and settings.</string>
</dict>
</plist>
EOF
codesign --force --sign - "$APP"
OUT=$(mktemp)
open -W -n --stdout "$OUT" --stderr "$OUT" "$APP" --args "$@" &
tail -f "$OUT" &
TAIL=$!
wait %1 2>/dev/null || true
sleep 0.2
kill $TAIL 2>/dev/null || true
