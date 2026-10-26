#!/bin/sh
# Native macOS implementation and support: Denis Arnst (Sapd) — https://github.com/Sapd
# USBAnywhere project: oscarlosu-lab (SnakeFoxu) — https://github.com/oscarlosu-lab
# Licensed under GPL-3.0; see the repository LICENSE.
# Install a locally built, reviewed Swift server and companion menu-bar app.
set -eu
PATH=/usr/bin:/bin:/usr/sbin:/sbin
export PATH
root=
sandbox=0
if [ "${USBANYWHERE_INSTALL_SANDBOX+x}" = x ]; then
    # Test command overrides must never be reachable from an administrator run.
    if [ "$(/usr/bin/id -u)" -eq 0 ]; then
        echo 'Installer sandbox is forbidden when running as root.' >&2; exit 2
    fi
    root=${USBANYWHERE_INSTALL_SANDBOX}
    case "$root" in /*) ;; *) echo 'Sandbox must be an absolute directory.' >&2; exit 2;; esac
    test -f "$root/.usbanywhere-installer-test"
    root=$(CDPATH='' cd -- "$root" && pwd -P)
    test "$root" != /
    sandbox=1
    PATH="$root/bin:$PATH"
    export PATH
elif [ "$(/usr/bin/id -u)" -ne 0 ]; then
    echo 'Run this installer with sudo.' >&2; exit 2
fi
if [ "$#" -lt 2 ]; then
    echo 'Usage: sudo sh scripts/install-server-mac.sh LISTEN_IPV4 PEER_IPV4 [VID PID LOCATION LABEL ...]' >&2
    exit 2
fi
script_dir=$(CDPATH='' cd -- "$(dirname "$0")" && pwd)
package=${USBANYWHERE_PACKAGE_DIR:-"$script_dir/../src/USBAnywhere.Server.Mac"}
binary="$package/build/usbanywhere-server-mac"
test -x "$binary"
control_source="$package/build/usbanywhere-ctl"
test -f "$control_source"
test -s "$control_source"
# Values are embedded in XML below; permit only the validated identifier alphabet.
for arg in "$@"; do case "$arg" in ''|*[!0-9a-zA-Z.]*) echo 'Invalid argument' >&2; exit 2;; esac; done
label=local.usbanywhere.macos
helper_dir="$root/Library/PrivilegedHelperTools/USBAnywhereMac"
installed="$helper_dir/usbanywhere-mac"
control_installed="$helper_dir/usbanywhere-ctl"
control_bin="$root/usr/local/bin"
control_link="$control_bin/usbanywhere-ctl"
plist_dir="$root/Library/LaunchDaemons"
plist="$plist_dir/$label.plist"
upstream_plist="$plist_dir/com.usbanywhere.server.plist"
state_dir="$root/Library/Application Support/USBAnywhereMac"
targets="$state_dir/targets.json"
previous_upstream="$state_dir/previous-upstream.plist"
log_dir="$root/Library/Logs/USBAnywhereMac"
apps_dir="$root/Applications"
app="$apps_dir/USBAnywhere.app"
lock_dir="$root/var/run/usbanywhere-mac-install.lock"
work_parent=/private/tmp
if [ "$sandbox" -eq 1 ]; then work_parent=${TMPDIR:-/tmp}; fi
work=$(mktemp -d "$work_parent/usbanywhere-install.XXXXXX")
helper_stage='' plist_stage='' app_stage='' control_stage=''
locked=0 transaction=0 catalog_changed=0 app_changed=0 upstream_changed=0 backup_created=0
main_loaded=0 upstream_loaded=0 had_binary=0 had_plist=0 had_targets=0 had_app=0 had_previous=0
rollback_failed=0
control_changed=0 had_control=0 had_control_link=0

restore_file() {
    cp -pP "$1" "$2.rollback" && mv -f "$2.rollback" "$2"
}
verify_restored_service() {
    restore_label=$1
    before=$2
    restore_attempt=0
    while [ "$restore_attempt" -lt 5 ]; do
        restore_attempt=$((restore_attempt+1))
        if launchctl print "system/$restore_label" >"$work/restored" 2>/dev/null; then
            # A previously loaded but stopped service must remain registered;
            # one that was running must actually resume running after rollback.
            if ! grep -Eq 'state = running' "$before" \
                || { grep -Eq 'state = running' "$work/restored" \
                    && grep -Eq 'pid = [1-9][0-9]*' "$work/restored"; }; then return 0; fi
        fi
        sleep 1
    done
    return 1
}
rollback() {
    echo 'Installation failed; restoring the previous installation.' >&2
    launchctl bootout "system/$label" >/dev/null 2>&1 || true
    if [ "$had_binary" -eq 1 ]; then
        restore_file "$helper_stage/old" "$installed" || rollback_failed=1
    else
        rm -f "$installed" || rollback_failed=1
    fi
    if [ "$had_plist" -eq 1 ]; then
        restore_file "$plist_stage/old" "$plist" || rollback_failed=1
    else
        rm -f "$plist" || rollback_failed=1
    fi
    if [ "$control_changed" -eq 1 ]; then
        if [ "$had_control" -eq 1 ]; then
            restore_file "$helper_stage/control-old" "$control_installed" || rollback_failed=1
        else
            rm -f "$control_installed" || rollback_failed=1
        fi
        if [ "$had_control_link" -eq 1 ]; then
            restore_file "$control_stage/old" "$control_link" || rollback_failed=1
        else
            rm -f "$control_link" || rollback_failed=1
        fi
    fi
    if [ "$app_changed" -eq 1 ]; then
        if [ -e "$app_stage/old" ] || [ -L "$app_stage/old" ]; then
            rm -rf "$app" && mv "$app_stage/old" "$app" || rollback_failed=1
        elif [ "$had_app" -eq 0 ]; then
            rm -rf "$app" || rollback_failed=1
        fi
    fi
    if [ "$upstream_changed" -eq 1 ]; then
        restore_file "$work/upstream.plist" "$upstream_plist" || rollback_failed=1
        if [ "$had_previous" -eq 1 ]; then
            restore_file "$work/previous-upstream.plist" "$previous_upstream" || rollback_failed=1
        else
            rm -f "$previous_upstream" || rollback_failed=1
        fi
    fi
    if [ "$backup_created" -eq 1 ]; then rm -f "$installed.before-swift" || rollback_failed=1; fi
}
finish() {
    result=$1
    trap - EXIT HUP INT TERM
    set +e
    if [ "$result" -ne 0 ]; then
        if [ "$transaction" -eq 1 ]; then rollback; fi
        if [ "$catalog_changed" -eq 1 ]; then
            if [ "$had_targets" -eq 1 ]; then
                restore_file "$work/targets.json" "$targets" || rollback_failed=1
            else
                rm -f "$targets" || rollback_failed=1
            fi
        fi
        # Restore registration only after files and the catalog have been restored.
        if [ "$transaction" -eq 1 ]; then
            if [ "$main_loaded" -eq 1 ]; then
                launchctl bootstrap system "$plist" || rollback_failed=1
                verify_restored_service "$label" "$work/main.before" || rollback_failed=1
            fi
            if [ "$upstream_loaded" -eq 1 ]; then
                if ! launchctl print system/com.usbanywhere.server >/dev/null 2>&1; then
                    launchctl bootstrap system "$upstream_plist" || rollback_failed=1
                fi
                verify_restored_service com.usbanywhere.server "$work/upstream.before" || rollback_failed=1
            fi
        fi
    fi
    if [ "$locked" -eq 1 ]; then rmdir "$lock_dir"; fi
    if [ "$rollback_failed" -eq 0 ]; then
        for directory in "$helper_stage" "$plist_stage" "$app_stage" "$control_stage" "$work"; do
            if [ -n "$directory" ]; then rm -rf "$directory"; fi
        done
    else
        echo "Rollback needs attention. Recovery files: $work $helper_stage $plist_stage $app_stage" >&2
    fi
    exit "$result"
}
trap 'finish $?' EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM

# Execute a private staged copy, never the mutable package path, during validation.
cp "$binary" "$work/server"
cp "$control_source" "$work/control"
chmod 755 "$work/server"
"$work/server" --validate "$@"
"$work/server" --preflight-install "$@"
if [ "$sandbox" -eq 1 ]; then mkdir -p "$root/var/run"; fi
if ! mkdir "$lock_dir"; then echo 'Another installation is in progress.' >&2; exit 1; fi
locked=1
# Recheck under the installer lock in case another installation just completed.
"$work/server" --preflight-install "$@"

if [ "$sandbox" -eq 0 ]; then
    install -d -o root -g wheel -m 755 "$helper_dir" "$log_dir" "$state_dir"
    mkdir -p "$plist_dir" "$apps_dir" "$control_bin"
else
    mkdir -p "$helper_dir" "$plist_dir" "$log_dir" "$state_dir" "$apps_dir" "$control_bin"
fi
# Do not treat an existing directory as a file destination during replacement.
test ! -d "$control_link"
test ! -d "$control_installed"
control_stage=$(mktemp -d "$control_bin/.usbanywhere.XXXXXX")
helper_stage=$(mktemp -d "$helper_dir/.install.XXXXXX")
plist_stage=$(mktemp -d "$plist_dir/.usbanywhere.XXXXXX")
cp "$work/server" "$helper_stage/new"
chmod 755 "$helper_stage/new"
cp "$work/control" "$helper_stage/control-new"
chmod 755 "$helper_stage/control-new"
ln -s "$control_installed" "$control_stage/new"
if [ -e "$control_installed" ] || [ -L "$control_installed" ]; then
    cp -pP "$control_installed" "$helper_stage/control-old"; had_control=1
fi
if [ -e "$control_link" ] || [ -L "$control_link" ]; then
    cp -pP "$control_link" "$control_stage/old"; had_control_link=1
fi
if [ -e "$installed" ]; then cp -p "$installed" "$helper_stage/old"; had_binary=1; fi
if [ -e "$plist" ]; then cp -p "$plist" "$plist_stage/old"; had_plist=1; fi
if [ -e "$targets" ]; then cp -p "$targets" "$work/targets.json"; had_targets=1; fi
if [ -e "$previous_upstream" ]; then cp -p "$previous_upstream" "$work/previous-upstream.plist"; had_previous=1; fi
if [ -e "$upstream_plist" ]; then cp -p "$upstream_plist" "$work/upstream.plist"; fi
if launchctl print "system/$label" >"$work/main.before" 2>/dev/null; then
    main_loaded=1
    test "$had_plist" -eq 1 || { echo 'Cannot back up the registered service configuration.' >&2; exit 1; }
fi
if launchctl print system/com.usbanywhere.server >"$work/upstream.before" 2>/dev/null; then
    upstream_loaded=1
    test -f "$work/upstream.plist" || { echo 'Cannot back up the registered upstream service.' >&2; exit 1; }
fi

cat > "$plist_stage/new" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>Label</key><string>$label</string>
<key>ProgramArguments</key><array><string>$installed</string>
PLIST
for argument in "$@"; do printf '<string>%s</string>\n' "$argument" >> "$plist_stage/new"; done
cat >> "$plist_stage/new" <<PLIST
</array><key>RunAtLoad</key><true/><key>KeepAlive</key><true/>
<key>ThrottleInterval</key><integer>5</integer><key>ExitTimeOut</key><integer>10</integer>
<key>StandardOutPath</key><string>$log_dir/server.log</string>
<key>StandardErrorPath</key><string>$log_dir/server.log</string>
</dict></plist>
PLIST
chmod 644 "$plist_stage/new"
plutil -lint "$plist_stage/new"
if [ -d "$package/build/USBAnywhere.app" ]; then
    app_stage=$(mktemp -d "$apps_dir/.usbanywhere.XXXXXX")
    ditto "$package/build/USBAnywhere.app" "$app_stage/new"
    codesign --verify --deep --strict "$app_stage/new"
    if [ "$sandbox" -eq 0 ]; then chown -R root:wheel "$app_stage/new"; fi
    if [ -e "$app" ] || [ -L "$app" ]; then had_app=1; fi
fi

# Migration can write targets.json. Snapshot first, and undo it on every failure,
# including failures before the running service has been stopped.
# Preserve the old startup suffix even when the proposed explicit configuration
# contains fewer targets. Preflight has already checked both sources agree.
catalog_changed=1
"$work/server" --preserve-startup-devices
transaction=1
if [ "$main_loaded" -eq 1 ]; then launchctl bootout "system/$label"; fi
if [ "$upstream_loaded" -eq 1 ]; then launchctl bootout system/com.usbanywhere.server; fi
mv -f "$helper_stage/new" "$installed"
mv -f "$plist_stage/new" "$plist"
control_changed=1
mv -f "$helper_stage/control-new" "$control_installed"
mv -f "$control_stage/new" "$control_link"
if [ -n "$app_stage" ]; then
    app_changed=1
    if [ "$had_app" -eq 1 ]; then mv "$app" "$app_stage/old"; fi
    mv "$app_stage/new" "$app"
fi
if [ -f "$work/upstream.plist" ]; then
    upstream_changed=1
    restore_file "$work/upstream.plist" "$previous_upstream"
    rm "$upstream_plist"
fi
attempt=0
until launchctl bootstrap system "$plist"; do
    attempt=$((attempt+1)); if [ "$attempt" -ge 5 ]; then echo 'Service registration failed.' >&2; exit 1; fi
    sleep 1
done
# Registration alone does not establish that the daemon stayed alive or opened
# its control socket. Require two healthy observations before discarding backups.
attempt=0 healthy=0
while [ "$attempt" -lt 10 ]; do
    attempt=$((attempt+1))
    if launchctl print "system/$label" >"$work/running" 2>/dev/null \
        && grep -Eq 'state = running' "$work/running" \
        && grep -Eq 'pid = [1-9][0-9]*' "$work/running" \
        && "$installed" --control status >/dev/null 2>&1; then
        healthy=$((healthy+1))
        if [ "$healthy" -ge 2 ]; then break; fi
    else
        healthy=0
    fi
    sleep 1
done
if [ "$healthy" -lt 2 ]; then echo 'The installed service did not become healthy.' >&2; exit 1; fi
# Retain the original binary for an explicit first-migration rollback.
if [ "$had_binary" -eq 1 ] && [ ! -e "$installed.before-swift" ]; then
    backup_created=1
    restore_file "$helper_stage/old" "$installed.before-swift"
fi
transaction=0 catalog_changed=0
echo 'Swift USB sharing installed and running. Open /Applications/USBAnywhere.app.'
