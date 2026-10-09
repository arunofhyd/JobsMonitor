#!/usr/bin/env bash
# =============================================================================
#  build_app.sh — Fast Local Development & Bundle Builder for JobsMonitor
# =============================================================================
set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
APP_NAME="JobsMonitor"
APP_DIR="$DIR/$APP_NAME.app"
DEST_APP="/Applications/$APP_NAME.app"
BUNDLE_ID="com.apple.aoh.jobsmonitor"

# 1. Single Source of Truth: Read version from version.json or main.swift
VERSION=$(python3 -c "import json; print(json.load(open('$DIR/version.json'))['version'])" 2>/dev/null || grep -m1 'let appVersion =' "$DIR/main.swift" | cut -d'"' -f2 || echo "2.3.7")
echo "🔖 Building $APP_NAME v$VERSION ($BUNDLE_ID)..."

# 2. Assemble .app bundle structure
echo "📦 Assembling .app bundle..."
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"

# 3. Copy Icon & Brand Assets
[ -f "$DIR/AppIcon.icns" ] && cp "$DIR/AppIcon.icns" "$APP_DIR/Contents/Resources/"
[ -f "$DIR/logo-jobsmonitor.png" ] && cp "$DIR/logo-jobsmonitor.png" "$APP_DIR/Contents/Resources/"
[ -f "$DIR/AppIcon.png" ] && cp "$DIR/AppIcon.png" "$APP_DIR/Contents/Resources/"

# 4. Write Info.plist
cat > "$APP_DIR/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>$APP_NAME</string>
  <key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
  <key>CFBundleVersion</key><string>$VERSION</string>
  <key>CFBundleShortVersionString</key><string>$VERSION</string>
  <key>CFBundleExecutable</key><string>$APP_NAME</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>LSUIElement</key><true/>
</dict>
</plist>
PLIST

# 5. Compile Swift Binary
echo "🔨 Compiling main.swift with swiftc..."
SWIFT_SDK=$(xcrun --show-sdk-path 2>/dev/null || true)
SWIFT_CACHE="/tmp/.swiftcache_jobsmonitor"
mkdir -p "$SWIFT_CACHE"
xcrun swiftc -O ${SWIFT_SDK:+-sdk "$SWIFT_SDK"} -module-cache-path "$SWIFT_CACHE" -o "$APP_DIR/Contents/MacOS/$APP_NAME" "$DIR/main.swift" -framework AppKit -framework ServiceManagement -framework UserNotifications -framework SwiftUI -framework Foundation -framework WebKit -framework AVFoundation

chmod +x "$APP_DIR/Contents/MacOS/$APP_NAME"

# 6. Codesign with Hardened Runtime and designated identifier for permission persistence
echo "🔏 Ad-hoc code signing with Hardened Runtime..."
ENTITLEMENTS_ARG=()
if [ -f "$DIR/Entitlements.plist" ]; then
    ENTITLEMENTS_ARG=(--entitlements "$DIR/Entitlements.plist")
fi

codesign --force --deep --options runtime "${ENTITLEMENTS_ARG[@]}" --sign - \
  --requirements "=designated => identifier \"$BUNDLE_ID\"" "$APP_DIR"
codesign --verify --deep --strict "$APP_DIR" && echo "✅ Signature verified"

# 7. Install to /Applications — force-kill any running instance first
echo "🚀 Installing to $DEST_APP..."
pkill -9 -x "$APP_NAME" 2>/dev/null || true
attempts=0
while [ "$attempts" -lt 10 ] && pgrep -x "$APP_NAME" >/dev/null 2>&1; do
    sleep 0.5
    attempts=$((attempts + 1))
done
rm -rf "$DEST_APP" 2>/dev/null || true
cp -R "$APP_DIR" "$DEST_APP"

INSTALLED_VER=$(defaults read "$DEST_APP/Contents/Info.plist" CFBundleShortVersionString 2>/dev/null || echo "unknown")
echo "✅ Verified installed version: $INSTALLED_VER"

# 8. Refresh LaunchServices icon cache
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$DEST_APP" 2>/dev/null || true
touch "$DEST_APP"

# 9. Relaunch
echo "✨ Launching $APP_NAME..."
open "$DEST_APP"

# 10. Create release package (JobsMonitor.zip) for Software Signing Portal upload
echo "📦 Creating production JobsMonitor.zip archive..."
rm -f "$DIR/JobsMonitor.zip"
export COPYFILE_DISABLE=1
xattr -cr "$APP_DIR"
find "$APP_DIR" -name "._*" -delete 2>/dev/null || true
find "$APP_DIR" -name ".DS_Store" -delete 2>/dev/null || true
(cd "$DIR" && zip -q -r -y "$DIR/JobsMonitor.zip" "$APP_NAME.app")
echo "🎁 Release package ready: $DIR/JobsMonitor.zip"

echo "✅ Build & Install Complete!"
