#!/bin/bash

# Exit on error
set -e

PROJECT_DIR="/Users/kaerith/workspace/Photos"
APP_NAME="Photo Sorter"
APP_DIR="${PROJECT_DIR}/${APP_NAME}.app"
MACOS_DIR="${APP_DIR}/Contents/MacOS"
RESOURCES_DIR="${APP_DIR}/Contents/Resources"

echo "=== Building Swift executable in Release mode ==="
cd "${PROJECT_DIR}"
swift build -c release

echo "=== Creating App Bundle hierarchy ==="
# Remove existing app bundle if it exists
if [ -d "${APP_DIR}" ]; then
    rm -rf "${APP_DIR}"
fi

mkdir -p "${MACOS_DIR}"
mkdir -p "${RESOURCES_DIR}"

echo "=== Copying executable ==="
cp "${PROJECT_DIR}/.build/release/PhotosApp" "${MACOS_DIR}/PhotosApp"
chmod +x "${MACOS_DIR}/PhotosApp"

if [ -f "${PROJECT_DIR}/Resources/AppIcon.icns" ]; then
    echo "=== Copying app icon ==="
    cp "${PROJECT_DIR}/Resources/AppIcon.icns" "${RESOURCES_DIR}/AppIcon.icns"
fi

echo "=== Creating Info.plist ==="
cat > "${APP_DIR}/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>PhotosApp</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon.icns</string>
    <key>CFBundleIdentifier</key>
    <string>com.photosorter.app</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>Photo Sorter</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleSignature</key>
    <string>????</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
</dict>
</plist>
EOF

# Create PkgInfo file
echo "APPL????" > "${APP_DIR}/Contents/PkgInfo"

echo "=== App Bundle created successfully! ==="
echo "You can find it at: ${APP_DIR}"
echo "To run the app, double-click on '${APP_NAME}.app' in Finder or execute:"
echo "open \"${APP_DIR}\""
