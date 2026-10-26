#!/bin/sh
# Native macOS implementation and support: Denis Arnst (Sapd) — https://github.com/Sapd
# USBAnywhere project: oscarlosu-lab (SnakeFoxu) — https://github.com/oscarlosu-lab
# Licensed under GPL-3.0; see the repository LICENSE.
set -eu
cd "$(dirname "$0")/.."
mkdir -p build/Artwork/AppIcon.iconset
for points in 16 32 128 256 512; do
    sips -z "$points" "$points" Artwork/AppIconMaster.png --out "build/Artwork/AppIcon.iconset/icon_${points}x${points}.png" >/dev/null
    pixels=$((points*2))
    sips -z "$pixels" "$pixels" Artwork/AppIconMaster.png --out "build/Artwork/AppIcon.iconset/icon_${points}x${points}@2x.png" >/dev/null
done
iconutil -c icns build/Artwork/AppIcon.iconset -o build/Artwork/AppIcon.icns
xcrun swift Artwork/make-icons.swift build/Artwork
