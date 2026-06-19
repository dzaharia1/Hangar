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

echo "🚚 Preparing Hangar for local run..."

# Kill any currently running instances of Hangar
pkill -x Hangar 2>/dev/null || true
sleep 0.5

# Strip quarantine attributes to allow the unsigned app to run
xattr -cr "$APP_PATH" 2>/dev/null || true

echo "🚀 Launching Hangar from build directory..."
open "$APP_PATH"

echo "✅ Hangar successfully built and launched!"
