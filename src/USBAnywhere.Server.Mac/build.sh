#!/bin/sh
# Native macOS implementation and support: Denis Arnst (Sapd) — https://github.com/Sapd
# USBAnywhere project: oscarlosu-lab (SnakeFoxu) — https://github.com/oscarlosu-lab
# Licensed under GPL-3.0; see the repository LICENSE.
set -eu
cd "$(dirname "$0")"
configuration=${CONFIGURATION:-release}
if [ -n "${SIGN_IDENTITY:-}" ]; then
    case "$SIGN_IDENTITY" in 'Developer ID Application:'*) ;; *) echo 'Distribution signing requires a Developer ID Application identity.' >&2; exit 2;; esac
fi
if [ -n "${USBANYWHERE_BUILD_DIR:-}" ]; then
    scratch=$USBANYWHERE_BUILD_DIR
elif [ -d /Volumes/Builds/dd ]; then
    scratch=/Volumes/Builds/dd/usbanywhere-swift
else
    scratch="$PWD/.build"
fi
swift build --scratch-path "$scratch" -c "$configuration"
bin=$(swift build --scratch-path "$scratch" -c "$configuration" --show-bin-path)
./Artwork/build-icons.sh
mkdir -p build
cp "$bin/usbanywhere-server-mac" build/
if [ -n "${SIGN_IDENTITY:-}" ]; then
    codesign --force --options runtime --timestamp --sign "$SIGN_IDENTITY" build/usbanywhere-server-mac
fi
app=build/USBAnywhere.app
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp "$bin/USBAnywhereApp" "$app/Contents/MacOS/USBAnywhere"
cp build/Artwork/AppIcon.icns build/Artwork/MenuBarIconTemplate.pdf "$app/Contents/Resources/"
cat > "$app/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>org.usbanywhere.mac</string>
<key>CFBundleName</key><string>USBAnywhere Server</string>
<key>CFBundleDisplayName</key><string>USBAnywhere Server</string>
<key>CFBundleExecutable</key><string>USBAnywhere</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>0.1.0</string>
<key>CFBundleVersion</key><string>4</string>
<key>CFBundleIconFile</key><string>AppIcon</string>
<key>LSMinimumSystemVersion</key><string>13.0</string>
<key>LSUIElement</key><true/>
<key>NSHumanReadableCopyright</key><string>Copyright 2026 Denis Arnst (Sapd) — github.com/Sapd. GPL-3.0.</string>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
mkdir -p "$app/Contents/Resources/Server"
cp build/usbanywhere-server-mac "$app/Contents/Resources/Server/"
cp ../../scripts/install-server-mac.sh "$app/Contents/Resources/Server/"
if [ -n "${SIGN_IDENTITY:-}" ]; then
    codesign --force --options runtime --timestamp --sign "$SIGN_IDENTITY" "$app"
else
    codesign --force --sign - "$app"
fi
codesign --verify --strict "$app"
printf 'Built %s and %s\n' "$PWD/build/usbanywhere-server-mac" "$PWD/$app"
