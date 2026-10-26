#!/bin/sh
# Native macOS implementation and support: Denis Arnst (Sapd) — https://github.com/Sapd
# USBAnywhere project: oscarlosu-lab (SnakeFoxu) — https://github.com/oscarlosu-lab
# Licensed under GPL-3.0; see the repository LICENSE.
set -eu
if [ "$(id -u)" -ne 0 ]; then echo 'Run this script with sudo.' >&2; exit 2; fi
launchctl bootout system/local.usbanywhere.macos 2>/dev/null || true
launchctl bootout system/com.usbanywhere.server 2>/dev/null || true
rm -f /Library/LaunchDaemons/local.usbanywhere.macos.plist /Library/LaunchDaemons/com.usbanywhere.server.plist
rm -f /Library/PrivilegedHelperTools/USBAnywhereMac/usbanywhere-mac
rm -f /var/run/usbanywhere-mac/control.sock
rm -rf /Applications/USBAnywhere.app
# Retain logs, sharing preferences and the pre-Swift backup for diagnosis/recovery.
echo 'Service and app removed; diagnostic logs, preferences and rollback backup retained.'
