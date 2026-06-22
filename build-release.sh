#!/bin/bash
set -e

# Use the Xcode.app developer path to ensure we have the necessary macOS SDKs
export DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"

# Validate version argument
if [ -z "$1" ]; then
  echo "❌ Error: Please specify a version (e.g., ./build-release.sh 1.0.19)"
  exit 1
fi

# Load environment variables from .env file if present in the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/.env" ]; then
  echo "🔌 Loading environment variables from .env..."
  while IFS= read -r line || [ -n "$line" ]; do
    # Strip leading/trailing whitespaces, skip comments and empty lines
    line=$(echo "$line" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
    [[ "$line" =~ ^# ]] && continue
    [[ -z "$line" ]] && continue
    # Strip optional "export " prefix
    line=${line#export }
    
    # Split the line into key and value at the first '='
    if [[ "$line" =~ ^([^=]+)=(.*)$ ]]; then
      key="${BASH_REMATCH[1]}"
      val="${BASH_REMATCH[2]}"
      
      # Strip leading/trailing whitespaces from key and val
      key=$(echo "$key" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
      val=$(echo "$val" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
      
      # Strip leading and trailing double/single quotes from val
      val="${val#\"}"
      val="${val%\"}"
      val="${val#\'}"
      val="${val%\'}"
      
      export "$key=$val"
    fi
  done < "$SCRIPT_DIR/.env"
fi

# Validate code signing / notarization environment variables
if [ -z "$APPLE_ID" ] || [ -z "$APPLE_PASSWORD" ] || [ -z "$DEVELOPMENT_TEAM" ]; then
  echo "❌ Error: Please set the following environment variables for code signing and notarization:"
  echo "   export APPLE_ID=\"your-apple-id@email.com\""
  echo "   export APPLE_PASSWORD=\"your-app-specific-password\""
  echo "   export DEVELOPMENT_TEAM=\"YOUR_TEAM_ID\""
  echo "   (Alternatively, create a .env file in the same directory as this script)"
  exit 1
fi

VERSION="$1"
echo "🔖 Setting version to $VERSION in Hangar.xcodeproj..."

# Extract build number (last component of the version, e.g., 19 from 1.0.19)
BUILD_NUMBER=$(echo "$VERSION" | awk -F. '{print $3}')
if [ -z "$BUILD_NUMBER" ]; then
  BUILD_NUMBER="1"
fi

# Update MARKETING_VERSION and CURRENT_PROJECT_VERSION in project.pbxproj
sed -i '' "s/MARKETING_VERSION = [0-9.]*;/MARKETING_VERSION = $VERSION;/g" Hangar.xcodeproj/project.pbxproj
sed -i '' "s/CURRENT_PROJECT_VERSION = [0-9]*;/CURRENT_PROJECT_VERSION = $BUILD_NUMBER;/g" Hangar.xcodeproj/project.pbxproj

echo "🔨 Building Hangar locally in Release configuration..."
# Clean build directory if it exists
rm -rf build Hangar.zip

# Run xcodebuild using local developer tools (signing with Developer ID Application)
xcodebuild -project Hangar.xcodeproj \
           -scheme Hangar \
           -configuration Release \
           -derivedDataPath build \
           CODE_SIGN_IDENTITY="Developer ID Application" \
           DEVELOPMENT_TEAM="$DEVELOPMENT_TEAM" > xcodebuild.log 2>&1 || {
             echo "❌ xcodebuild failed. Compilation log:"
             cat xcodebuild.log
             rm -f xcodebuild.log
             exit 1
           }
rm -f xcodebuild.log

APP_PATH="build/Build/Products/Release/Hangar.app"

# Create a temporary entitlements file to ensure get-task-allow is absent (which would fail notarization)
# and Hardened Runtime exceptions (library validation & unsigned executable memory) are enabled.
cat << 'EOF' > temp.entitlements
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>com.apple.security.cs.allow-unsigned-executable-memory</key>
	<true/>
	<key>com.apple.security.cs.disable-library-validation</key>
	<true/>
</dict>
</plist>
EOF

echo "✍️ Signing Hangar.app with secure timestamp..."
codesign --force --options runtime --timestamp --entitlements temp.entitlements --sign "Developer ID Application" "$APP_PATH"
rm -f temp.entitlements

echo "📸 Capturing screenshot..."

# Allow unsigned build to launch
xattr -cr "$APP_PATH" 2>/dev/null || true
pkill -x Hangar 2>/dev/null || true
sleep 0.5

open "$APP_PATH"

# Poll until the window is ready (up to 10s)
# Uses System Events process targeting — more reliable than app-name scripting
# when the app is launched from a non-standard build path.
BOUNDS=""
for i in $(seq 1 20); do
  BOUNDS=$(osascript -e 'tell application "System Events" to tell process "Hangar" to get position of window 1' 2>/dev/null) && break
  sleep 0.5
done

if [ -z "$BOUNDS" ]; then
  echo "⚠️  Skipping screenshot — app window didn't appear"
else
  # Resize to fixed 1100×700 for a consistent screenshot
  osascript <<'OSASCRIPT'
tell application "System Events"
  tell process "Hangar"
    set position of window 1 to {100, 100}
    set size of window 1 to {1100, 700}
  end tell
end tell
OSASCRIPT
  sleep 1  # let content render at new size
  # Get the CGWindowID so screencapture -l captures just the window with its
  # shadow and rounded corners, matching cmd+shift+4+spacebar behaviour.
  WINDOW_ID=$(swift - <<'SWIFT'
import CoreGraphics
let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as! [[String: Any]]
for window in windows {
    if window["kCGWindowOwnerName"] as? String == "Hangar",
       window["kCGWindowLayer"] as? Int == 0,
       let id = window["kCGWindowNumber"] as? Int {
        print(id)
        break
    }
}
SWIFT
)
  if [ -n "$WINDOW_ID" ]; then
    if screencapture -x -l "$WINDOW_ID" screenshot.png 2>/dev/null; then
      echo "✅ screenshot.png updated"
    else
      echo "⚠️  screencapture failed (possibly due to Screen Recording permissions)"
    fi
  else
    echo "⚠️  Could not find Hangar window ID"
  fi
fi

osascript -e 'tell application "Hangar" to quit' 2>/dev/null || true
sleep 0.5

# 1. Package the signed .app into a temporary zip for notarization
echo "📦 Creating temporary zip for Notarization..."
APP_PATH="build/Build/Products/Release/Hangar.app"
ZIP_PATH_TEMP="$(pwd)/Hangar_Notary.zip"

cd build/Build/Products/Release
zip -r "$ZIP_PATH_TEMP" Hangar.app > /dev/null
cd - > /dev/null

# 2. Submit to Apple Notary Service
echo "🚀 Submitting Hangar to Apple Notary Service..."
xcrun notarytool submit "$ZIP_PATH_TEMP" \
      --apple-id "$APPLE_ID" \
      --password "$APPLE_PASSWORD" \
      --team-id "$DEVELOPMENT_TEAM" \
      --wait

# Clean up temporary zip
rm -f "$ZIP_PATH_TEMP"

# 3. Staple the Notary ticket back to the app bundle
echo "🎫 Stapling Notarization ticket..."
xcrun stapler staple "$APP_PATH"

# 4. Package the final notarized app for distribution
echo "📦 Packaging final Hangar.zip..."
ZIP_PATH="$(pwd)/Hangar.zip"
cd build/Build/Products/Release
zip -r "$ZIP_PATH" Hangar.app > /dev/null
cd - > /dev/null

echo "🧹 Cleaning up intermediate build files..."
rm -rf build

echo "✅ Hangar.zip successfully built and packaged!"
echo "👉 Remember to commit and push the updated Hangar.zip and Hangar.xcodeproj/project.pbxproj to trigger the release on GitHub!"
