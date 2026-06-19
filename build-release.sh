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
BOUNDS=""
for i in $(seq 1 20); do
  BOUNDS=$(osascript -e 'tell application "Hangar" to get bounds of window 1' 2>/dev/null) && break
  sleep 0.5
done

if [ -z "$BOUNDS" ]; then
  echo "⚠️  Skipping screenshot — app window didn't appear"
else
  # Resize to fixed dimensions for a consistent screenshot
  osascript -e 'tell application "Hangar" to set bounds of window 1 to {100, 100, 1200, 800}'
  sleep 1  # let content render at new size
  RECT=$(osascript <<'OSASCRIPT'
tell application "Hangar"
  set {x1, y1, x2, y2} to bounds of window 1
  return (x1 as string) & "," & (y1 as string) & "," & ((x2 - x1) as string) & "," & ((y2 - y1) as string)
end tell
OSASCRIPT
)
  screencapture -x -R "$RECT" screenshot.png
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

echo "✅ Hangar.zip successfully built and packaged!"
