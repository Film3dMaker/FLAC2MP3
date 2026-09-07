#!/bin/bash
set -e

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="FLAC2MP3"
BUILD_DIR="$PROJECT_DIR/build"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
CONTENTS_DIR="$APP_BUNDLE/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
DMG_PATH="$BUILD_DIR/$APP_NAME.dmg"

echo "=== FLAC2MP3 Universal Build & Package Script ==="
echo ""

# Check for ffmpeg
if ! command -v ffmpeg &> /dev/null; then
    echo "⚠️  ffmpeg no encontrado en PATH. Instálalo con: brew install ffmpeg"
else
    echo "✅ ffmpeg encontrado: $(which ffmpeg)"
fi

# Check for fpcalc
if ! command -v fpcalc &> /dev/null; then
    echo "⚠️  fpcalc no encontrado. Instálalo con: brew install chromaprint"
else
    echo "✅ fpcalc encontrado: $(which fpcalc)"
fi

echo ""
echo "Limpiando directorio de compilación..."
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

SOURCES=($(find Sources/FLAC2MP3 -name "*.swift"))


SDK_PATH=$(xcrun --show-sdk-path --sdk macosx)

echo "Compilando para Apple Silicon (arm64)..."
swiftc \
    -O \
    -o "$BUILD_DIR/${APP_NAME}_arm64" \
    -module-name "$APP_NAME" \
    -emit-executable \
    -target arm64-apple-macos13.0 \
    -sdk "$SDK_PATH" \
    -framework SwiftUI \
    -framework AppKit \
    -framework UserNotifications \
    -framework UniformTypeIdentifiers \
    "${SOURCES[@]}"

echo "Compilando para Intel (x86_64)..."
swiftc \
    -O \
    -o "$BUILD_DIR/${APP_NAME}_x86_64" \
    -module-name "$APP_NAME" \
    -emit-executable \
    -target x86_64-apple-macos13.0 \
    -sdk "$SDK_PATH" \
    -framework SwiftUI \
    -framework AppKit \
    -framework UserNotifications \
    -framework UniformTypeIdentifiers \
    "${SOURCES[@]}"

echo "Creando binario Universal 2 con lipo..."
lipo -create \
    -output "$BUILD_DIR/$APP_NAME" \
    "$BUILD_DIR/${APP_NAME}_arm64" \
    "$BUILD_DIR/${APP_NAME}_x86_64"

rm -f "$BUILD_DIR/${APP_NAME}_arm64" "$BUILD_DIR/${APP_NAME}_x86_64"

echo "✅ Binario Universal creado:"
file "$BUILD_DIR/$APP_NAME"

echo ""
echo "Creando bundle de aplicación..."
rm -rf "$APP_BUNDLE"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

# Copy binary
cp "$BUILD_DIR/$APP_NAME" "$MACOS_DIR/"
chmod +x "$MACOS_DIR/$APP_NAME"

# Copy Info.plist
cp "$PROJECT_DIR/Info.plist" "$CONTENTS_DIR/"

# Copy PkgInfo
echo "APPL????" > "$CONTENTS_DIR/PkgInfo"

# Copy icon
if [ -f "$PROJECT_DIR/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.icns" ]; then
    cp "$PROJECT_DIR/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.icns" "$RESOURCES_DIR/"
fi

# Copy resources
cp -r "$PROJECT_DIR/Resources/Assets.xcassets" "$RESOURCES_DIR/"

# Copy Automator workflow
mkdir -p "$RESOURCES_DIR/Automator"
if [ -d "$PROJECT_DIR/Automator/Send to FLAC2MP3.workflow" ]; then
    cp -r "$PROJECT_DIR/Automator/Send to FLAC2MP3.workflow" "$RESOURCES_DIR/Automator/"
fi

# Sign the app (ad-hoc)
codesign --force --deep --sign - "$APP_BUNDLE" 2>/dev/null || true

echo "✅ App creada: $APP_BUNDLE ($(du -sh "$APP_BUNDLE" | cut -f1))"

echo ""
echo "Empaquetando instalador DMG..."
DMG_STAGING="$BUILD_DIR/dmg_staging"
rm -rf "$DMG_STAGING" "$DMG_PATH"
mkdir -p "$DMG_STAGING"

cp -r "$APP_BUNDLE" "$DMG_STAGING/"
ln -s /Applications "$DMG_STAGING/Applications"

hdiutil create \
    -volname "FLAC2MP3" \
    -srcfolder "$DMG_STAGING" \
    -ov \
    -format UDZO \
    "$DMG_PATH"

rm -rf "$DMG_STAGING"

echo ""
echo "=============================================="
echo "🎉 DEPLOY LISTO:"
echo "  • App Bundle: $APP_BUNDLE"
echo "  • Instalador DMG: $DMG_PATH ($(du -sh "$DMG_PATH" | cut -f1))"
echo "  • Arquitectura: Universal 2 (arm64 + x86_64)"
echo "=============================================="