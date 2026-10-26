#!/bin/sh
# USBAnywhere project: oscarlosu-lab (SnakeFoxu) — https://github.com/oscarlosu-lab
# Native macOS implementation and support: Denis Arnst (Sapd) — https://github.com/Sapd
# Licensed under GPL-3.0; see the repository LICENSE.
# Build a drag-to-Applications distribution. Public notarization is opt-in and
# requires a Developer ID identity and a preconfigured notarytool keychain profile.
set -eu
cd "$(dirname "$0")"
if [ -n "${NOTARY_PROFILE:-}" ] && [ -z "${SIGN_IDENTITY:-}" ]; then
    echo 'NOTARY_PROFILE requires SIGN_IDENTITY=Developer ID Application: ...' >&2; exit 2
fi
if [ "${SKIP_BUILD:-0}" != 1 ]; then ./build.sh; fi
app=build/USBAnywhere.app
codesign --verify --deep --strict "$app"
if [ -n "${SIGN_IDENTITY:-}" ]; then
    codesign -dv --verbose=4 "$app" 2>&1 | grep -Fqx "Authority=$SIGN_IDENTITY"
fi
if [ -n "${NOTARY_PROFILE:-}" ]; then
    case "$SIGN_IDENTITY" in 'Developer ID Application:'*) ;; *) echo 'A Developer ID Application identity is required for notarization.' >&2; exit 2;; esac
    ditto -c -k --keepParent "$app" build/USBAnywhere-notarization.zip
    xcrun notarytool submit build/USBAnywhere-notarization.zip --keychain-profile "$NOTARY_PROFILE" --wait --output-format json > build/notarization-app.json
    /usr/bin/plutil -extract status raw build/notarization-app.json | /usr/bin/grep -qx Accepted
    xcrun stapler staple "$app"
    xcrun stapler validate "$app"
fi
stage=build/Distribution
rm -rf "$stage"
mkdir -p "$stage"
ditto "$app" "$stage/USBAnywhere.app"
ln -s /Applications "$stage/Applications"
cp ../../LICENSE "$stage/License.txt"
cp AUTHORS.md "$stage/Credits.txt"
# Include corresponding source with the local binary package. Keep build output,
# machine-specific notes and Git metadata out of the source archive.
source_root=build/SourceDistribution/USBAnywhere-Server
rm -rf build/SourceDistribution
mkdir -p "$source_root/src/USBAnywhere.Server.Mac" "$source_root/scripts"
for item in Package.swift Sources Tests Artwork WindowsClient build.sh package.sh README.md AUTHORS.md DISTRIBUTION.md; do
    ditto "$item" "$source_root/src/USBAnywhere.Server.Mac/$item"
done
cp ../../scripts/install-server-mac.sh ../../scripts/uninstall-server-mac.sh ../../scripts/usbanywhere-ctl "$source_root/scripts/"
cp ../../LICENSE "$source_root/LICENSE"
ditto -c -k --keepParent "$source_root" "$stage/Source.zip"
cat > "$stage/Read Me.txt" <<'README'
USBAnywhere Server for macOS

1. Drag USBAnywhere to Applications.
2. Open USBAnywhere from Applications.
3. Choose your Windows PC and approve Set Up Sharing once.
4. Click Share beside each USB device you want to use on Windows.

Remembered devices reconnect automatically. Opening the app again brings back
its main window. Closing the window keeps sharing running in the background.
Open at login is optional and can be chosen during setup or changed later.
A fresh Windows PC requires USBAnywhere Client and its USB/IP driver once.

The server is bundled: no Terminal, source checkout, compiler or separate helper
download is required to use the packaged app. Use a trusted LAN or Tailscale.
Requires macOS 13 or later. This package is built for the architecture in its name.

USBAnywhere project: oscarlosu-lab (SnakeFoxu), github.com/oscarlosu-lab
Native Mac implementation: Denis Arnst (Sapd), github.com/Sapd
GPL-3.0. License.txt and corresponding Source.zip are included.
Experimental: see the project documentation for device-support limits.
README
version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app/Contents/Info.plist")
arch=$(/usr/bin/uname -m)
suffix='-dev'
if [ -n "${NOTARY_PROFILE:-}" ]; then suffix=''; fi
name="USBAnywhere-Server-$version-$arch$suffix"
dmg="build/$name.dmg"
hdiutil create -volname 'USBAnywhere Server' -srcfolder "$stage" -format UDZO -ov "$dmg"
if [ -n "${SIGN_IDENTITY:-}" ]; then
    codesign --force --timestamp --sign "$SIGN_IDENTITY" "$dmg"
fi
if [ -n "${NOTARY_PROFILE:-}" ]; then
    xcrun notarytool submit "$dmg" --keychain-profile "$NOTARY_PROFILE" --wait --output-format json > build/notarization-dmg.json
    /usr/bin/plutil -extract status raw build/notarization-dmg.json | /usr/bin/grep -qx Accepted
    xcrun stapler staple "$dmg"
    xcrun stapler validate "$dmg"
fi
ditto -c -k --keepParent "$app" "build/$name.zip"
shasum -a 256 "$dmg" "build/$name.zip" > "build/$name.sha256"
if [ -z "${SIGN_IDENTITY:-}" ]; then
    echo 'Development package only: ad-hoc signed, not notarized. Public distribution requires Developer ID signing/notarization.'
fi
printf 'Created %s and build/%s.zip\n' "$dmg" "$name"
