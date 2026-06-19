#!/bin/bash
set -e

# Use the Xcode.app developer path to ensure we have the necessary macOS SDKs
export DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"

echo "🔨 Building Hangar locally..."
rm -rf build

xcodebuild -project Hangar.xcodeproj \
           -scheme Hangar \
           -configuration Release \
           -derivedDataPath build \
           CODE_SIGNING_ALLOWED=NO \
           CODE_SIGNING_REQUIRED=NO \
           CODE_SIGN_IDENTITY="" \
           CODE_SIGN_ENTITLEMENTS="" > /dev/null

APP_PATH="build/Build/Products/Release/Hangar.app"
DEST_PATH="/Applications/Hangar.app"

echo "🚚 Installing Hangar to $DEST_PATH..."

# Kill any currently running instances of Hangar
pkill -x Hangar 2>/dev/null || true
sleep 0.5

# Replace the application bundle in /Applications
rm -rf "$DEST_PATH"
cp -R "$APP_PATH" "$DEST_PATH"

# Strip quarantine attributes to allow the unsigned app to run
xattr -cr "$DEST_PATH" 2>/dev/null || true

# Clean up build artifacts
rm -rf build

echo "🚀 Launching Hangar..."
open "$DEST_PATH"

echo "✅ Hangar successfully built, installed, and launched!"
