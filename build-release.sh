#!/bin/bash
set -e

echo "🔨 Building Hangar locally in Release configuration..."
# Clean build directory if it exists
rm -rf build Hangar.zip

# Run xcodebuild using local developer tools (ensuring Tahoe/macOS 26 capabilities are compiled in)
xcodebuild -project Hangar.xcodeproj \
           -scheme Hangar \
           -configuration Release \
           -derivedDataPath build \
           CODE_SIGNING_ALLOWED=NO \
           CODE_SIGNING_REQUIRED=NO \
           CODE_SIGN_IDENTITY="" \
           CODE_SIGN_ENTITLEMENTS="" > /dev/null

echo "📸 Capturing screenshot..."
APP_PATH="build/Build/Products/Release/Hangar.app"

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
  screencapture -x -l "$WINDOW_ID" screenshot.png
  echo "✅ screenshot.png updated"
fi

osascript -e 'tell application "Hangar" to quit' 2>/dev/null || true
sleep 0.5

echo "📦 Packaging Hangar.app..."
ZIP_PATH="$(pwd)/Hangar.zip"
cd build/Build/Products/Release
zip -r "$ZIP_PATH" Hangar.app > /dev/null
cd - > /dev/null

echo "🧹 Cleaning up intermediate build files..."
rm -rf build

echo "📎 Staging build artifacts and amending last commit..."
git add Hangar.zip screenshot.png
git commit --amend --no-edit --no-verify

echo "✅ Hangar.zip successfully built and packaged!"
