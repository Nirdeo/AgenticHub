#!/bin/bash

# Build script for AgenticHub

APP_NAME="AgenticHub"
BUILD_DIR=".build/release"
APP_BUNDLE="$APP_NAME.app"

echo "🔨 Compiling AgenticHub in release mode..."
swift build -c release

if [ $? -ne 0 ]; then
    echo "❌ Build failed"
    exit 1
fi

echo "📦 Creating $APP_BUNDLE..."

# Create bundle structure
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# Copy executable
cp "$BUILD_DIR/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/"

# Copy Info.plist
cp Info.plist "$APP_BUNDLE/Contents/"

# Copy icons
if [ -f "Sources/Resources/AppIcon.icns" ]; then
    cp "Sources/Resources/AppIcon.icns" "$APP_BUNDLE/Contents/Resources/"
fi

# Create PkgInfo
echo -n "APPL????" > "$APP_BUNDLE/Contents/PkgInfo"

echo "✅ Build complete: $APP_BUNDLE"
echo ""
echo "📍 To install:"
echo "   cp -r \"$APP_BUNDLE\" /Applications/"
echo ""
echo "🚀 To run:"
echo "   open \"$APP_BUNDLE\""
