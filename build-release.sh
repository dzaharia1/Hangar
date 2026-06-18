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

echo "📦 Packaging Hangar.app..."
zip -r Hangar.zip build/Build/Products/Release/Hangar.app > /dev/null

echo "🧹 Cleaning up intermediate build files..."
rm -rf build

echo "✅ Hangar.zip successfully built and packaged!"
