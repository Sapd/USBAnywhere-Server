# USBAnywhere Server for macOS

Native Swift USB/IP server with a SwiftUI menu-bar app. The daemon captures real
USB hardware through Apple's IOUSBHost API and forwards asynchronous control,
bulk and interrupt transfers. The app controls the daemon over a local Unix
socket; closing the app does not stop USB sharing.

USBAnywhere project: **oscarlosu-lab (SnakeFoxu)** — <https://github.com/oscarlosu-lab>.
Native macOS implementation and app: **Denis Arnst (Sapd)** — <https://github.com/Sapd>.
GPL-3.0; see the repository LICENSE.

## Download-style installation

See [DISTRIBUTION.md](DISTRIBUTION.md) for the drag-to-Applications DMG, normal
Finder/Dock launch and reopen behavior, optional login startup, and the distinction
between a local development build and a signed/notarized public release.

## Everyday setup

1. Open **USBAnywhere.app**. It includes the native server and installer.
2. Click **Set Up Sharing**, choose your Windows PC (automatically listed when
   reachable through an existing Tailscale installation), and approve the Mac
   administrator prompt. LAN addresses can also be entered directly.
3. Plug in a USB device and click **Share** beside it. Existing remembered devices
   reconnect automatically; new unapproved devices stay on the Mac.

No Terminal, USB identifiers or separate Mac helper download are needed once the
app has been built/distributed. The server starts at boot. Connection Setup is
available through the gear button and menu-bar menu. Copy Mac Address simplifies
connecting an ordinary USBAnywhere Windows client.

A fresh Windows PC still requires USBAnywhere's USB/IP driver/client installation.
For automatic attachment of newly approved Mac devices, install the included
`WindowsClient/install-reconnect-client.ps1` once alongside the native client
files, with `-Server YOUR_MAC_IPV4`. It now defaults to `-BusIDs auto`; it discovers
the approved export list every five seconds and retries disconnected devices.
Existing explicit bus-ID lists are still supported. The normal Windows GUI is
also usable, but its own connection behavior is separate from this helper.

Adding a device preserves existing target order and identities. Device choices
are stored in root-managed `targets.json` and sharing settings in `sharing.json`
under `/Library/Application Support/USBAnywhereMac`. App-based updates/network
setup migrate existing startup targets before replacing the service configuration.
Ambiguous identical models are refused rather than guessed. New devices still
need a supported USB transfer type; discovery is not a compatibility guarantee.

## Build and install (developers)


Requires macOS 13+, Xcode Command Line Tools and Swift 5.9+. No external package
dependencies. Only Apple Silicon/macOS 27 has been tested with physical hardware.

```sh
cd src/USBAnywhere.Server.Mac
./build.sh
swift test
./build/usbanywhere-server-mac list
```

`build.sh` builds the daemon and ad-hoc-signed `build/USBAnywhere.app`. It uses
`/Volumes/Builds/dd/usbanywhere-swift` when available, otherwise `.build`. Override
with `USBANYWHERE_BUILD_DIR`. Ad-hoc signing is for local development: distribution
requires your own Developer ID signing/notarization.

From the repository root, install with **your own** local and allowed-client IPv4
addresses and device IDs from `list`:

```sh
sudo sh scripts/install-server-mac.sh LOCAL_IPV4 CLIENT_IPV4 VID PID LOCATION LABEL
open /Applications/USBAnywhere.app
```

Append another `VID PID LOCATION LABEL` group for each device (maximum 16).
The device argument groups are optional for a fresh empty setup. VID/PID/location are hexadecimal; labels contain 1–32 ASCII letters/digits. The
listener refuses the unrestricted `0.0.0.0` address. Only the configured peer IPv4
is accepted. Use a trusted private network or VPN such as Tailscale: USB/IP itself
has no authentication or encryption. No firewall or system security settings are
changed by the installer.

Only explicitly approved devices are shared. Initial configuration group order fixes
USB/IP bus IDs `1-1`, `1-2`, etc.; preserve that order when adding devices. Named
targets follow their unique VID/PID across Mac USB ports. Ambiguous matches and
duplicate configured models are refused. Matching multiple identical units by
hardware serial is not implemented. Hardware serials are preserved; devices
without one receive the configured label as a stable USB serial.

The installer installs a root-owned daemon and app, updates launchd, and retires
the original scaffold's `com.usbanywhere.server` service if present. Initial
migration retains the previous server binary as `usbanywhere-mac.before-swift`.
It does not install or modify the Windows client. Windows requires a USB/IP client;
continuous automatic retry requires the separate Windows reconnect helper.

## App and operation

- Window and menu-bar device list with sharing switches and per-device reconnect.
- Identity, transferred bytes, completed/pending transfers, recent errors.
- Diagnostic export to a file you choose; no automatic upload or raw input capture.
- Optional app login startup. The background daemon already starts at boot.
- About window credits both the USBAnywhere project and macOS implementation.

Stopping sharing releases only that device back to macOS. Reconnect closes only
that device's USB/IP session, releases capture, and allows Windows to import it
again. It does **not** power-cycle hardware or guarantee recovery from firmware
lockups. Windows must retry attachment; a bare one-shot client will not do so.

```sh
/Library/PrivilegedHelperTools/USBAnywhereMac/usbanywhere-mac --control status
/Library/PrivilegedHelperTools/USBAnywhereMac/usbanywhere-mac --control reconnect 1-4
/Library/PrivilegedHelperTools/USBAnywhereMac/usbanywhere-mac --control unshare 1-1
/Library/PrivilegedHelperTools/USBAnywhereMac/usbanywhere-mac --control share 1-1
```

Local control accepts only fixed actions on configured targets; it never executes
shell commands. The socket and its parent are root-owned. Mutating requests are
accepted only from root or the current console user's UID, checked through kernel
peer credentials. Other local users may read status. Sharing preferences are
saved by the daemon in `/Library/Application Support/USBAnywhereMac/sharing.json`.

Service: `local.usbanywhere.macos`.
Executable: `/Library/PrivilegedHelperTools/USBAnywhereMac/usbanywhere-mac`.
Events: `/Library/Logs/USBAnywhereMac/swift-server.log`, rotated at 2 MiB plus one
archive. Launchd startup/fatal stderr: `server.log` in the same directory.

Uninstall: `sudo sh scripts/uninstall-server-mac.sh`. Logs, settings and rollback
backup are retained. Disable the app's login startup before uninstalling.

## Shared CLI and service control

Setup also installs the optional `usbanywhere-ctl` command. It requires Python 3
and no third-party Python packages; everyday app use does not require Python.
From a checkout you can run `python3 scripts/usbanywhere-ctl` at the server repo
root. The command reads the same native service and saved catalog as the app:

```sh
usbanywhere-ctl status --json
usbanywhere-ctl list
usbanywhere-ctl share 1-1
usbanywhere-ctl unshare 1-1
usbanywhere-ctl reconnect 1-1
usbanywhere-ctl test
sudo usbanywhere-ctl start
sudo usbanywhere-ctl stop
sudo usbanywhere-ctl restart
usbanywhere-ctl logs
```

Sharing/reconnect actions run as the signed-in Mac user and retain the daemon's
permission checks. Only service start/stop/restart require administrator access.
Share new devices in the app first; the CLI displays their unconfigured status
and manages remembered bus IDs. Replugging keeps those IDs stable.

Service commands target `system/local.usbanywhere.macos`; they never launch a
second daemon or kill unrelated processes. Failed native/launchd operations return
nonzero. The CLI is installed alongside the helper with a link under `/usr/local/bin`;
installer rollback restores both existing CLI files and links.

On this allowlisted server the Mac itself cannot act as a network USB/IP client.
`test` therefore checks the authenticated native control API and reports that
boundary explicitly. `test --host HOST --port 3240` performs a USB/IP network
handshake; use it from an allowed client. Neither test proves physical input or
long-duration tracking stability.

## Validation and limits

Forty-six native tests cover framing/write deadlines, idle/EOF, stable serials,
registry-entry identity refresh, legacy migration, failed persistence, real socket
credentials, per-endpoint cancellation and retained native buffers. Transfer tests
also cover short-read flags, terminating bulk packets and reset-generation ordering.
Installer failure tests and a bounded Windows worker integration test run in CI.
`ExceptionGuard` is a tiny Objective-C exception
boundary: Swift cannot catch Objective-C exceptions during USB service teardown.
All forwarding, protocol, lifecycle and UI logic is Swift. Modern and legacy
Apple endpoint-stall errors map to EPIPE; client clear-halt requests use
IOUSBHostPipe.clearStall to restore the endpoint. A real VKB endpoint halt/clear
test restored physical USB input within the same imported session.

Physical validation is recorded separately from automated tests. The development
machine forwards two VKB Gladiator EVO sticks, a Steam Controller Puck and Tobii
Eye Tracker 5 simultaneously. The user confirmed all four work after switching to
Swift. Existing VKB Windows USB instance IDs and DirectInput GUIDs were preserved.
This is not evidence of universal compatibility or long-duration reliability.

No isochronous support, nonzero alternate settings, device firmware updating,
physical USB power switching, or proven recovery from a frozen Tobii. Transfer
errors can be driver probes or cancellations as well as genuine faults; inspect
context and native status codes. An idle input stream alone is not a fault, and
no automatic reset is triggered just because a controller is stationary.

The low-latency/zero-copy modes belong to the Windows receiving driver; the Mac
uses the same USB/IP protocol for both and does not claim end-to-end zero-copy.
Multi-hour active tracking, real network outage, sleep/wake and boot tests remain
separate validation work.

## App artwork

The app includes a multi-resolution Finder/Dock icon and an adaptive monochrome
menu-bar template. **Show in Dock** enables Dock visibility; new installs show the Dock icon, while existing saved
Dock preferences are preserved. Closing the app still does not stop the USB service. See
`Artwork/AppIconMaster.png` for the source app image and `Artwork/MenuBarIcon.svg`
for the editable menu-bar mark. `Artwork/build-icons.sh` and `make-icons.swift`
produce the packaged icons from those assets.

Source attribution and contributor scope are recorded in [AUTHORS.md](AUTHORS.md)
and the implementation headers. Packaged downloads include Credits.txt.
