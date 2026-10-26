# Normal Mac installation and launch

## For users

1. Open the disk image and drag **USBAnywhere** onto **Applications**.
2. Open USBAnywhere from Applications. Its main window opens immediately.
3. On first setup, choose your Windows PC and optionally select **Open USBAnywhere
   when I log in**. Approve **Set Up Sharing** once.
4. Share each USB device you want to forward. Remembered devices reconnect
   automatically through the configured Windows automatic-reconnect client.

No Terminal, scripts, compiler or separate Mac-server download is needed. Opening
an already-running app from Finder or the Dock brings back its main window, even
if the window was closed. Closing the window keeps the app/service running; Quit
App closes the GUI but leaves the installed sharing service running. New installs
show the app in the Dock; existing saved Dock preferences are preserved.

Open at login is optional, defaults off, and remains available in the main window.
It starts the GUI in the user's session; the installed USB sharing service starts
with the Mac independently. macOS may require Login Items approval when enabling
GUI login startup. Setup opened outside Applications explains where to move the
app before enabling installation/startup.

The optional shared `usbanywhere-ctl` command is installed with the helper and
requires Python 3. The GUI and USB service remain native Swift and do not require
a Python installation.

A fresh Windows PC still requires its USB/IP driver/client installation once.
Mac setup can discover Windows peers through an existing Tailscale installation;
local-network addresses can also be entered directly.

## Build a local package

```sh
./package.sh
```

Produces architecture-labeled DMG and ZIP files plus SHA-256 checksums under
`build/`. The disk image includes the app, Applications shortcut, short installation
guide, GPL license and corresponding source archive. No build tools are needed by
someone installing the packaged app.

Without signing credentials the filename includes `-dev`: it is ad-hoc signed for
local development and **not notarized**. Do not label it Gatekeeper-approved or a
finished public release. Do not disable Gatekeeper or remove quarantine to pretend
that a development build is a notarized distribution.

## Developer ID signing and notarization

Requires a valid **Developer ID Application** certificate/private key in the
keychain, and a previously configured `notarytool` keychain profile. Apple
Development certificates are not a substitute. No passwords are stored by these
scripts.

```sh
SIGN_IDENTITY='Developer ID Application: Your Name (TEAMID)' \
NOTARY_PROFILE='your-existing-profile' ./package.sh
```

The build signs the daemon and app with hardened runtime and timestamps. Packaging
checks the signing authority, submits the app for notarization, requires an
Accepted result, staples its ticket, creates/signs the DMG, notarizes/staples that
image, and exports a ZIP of the stapled app. Submission/stapling failures stop the
release. `SKIP_BUILD=1` may reuse an existing matching signed build.

This development Mac currently has Apple Development identities only; no
Developer ID public distribution or notarization success is claimed. The signing
workflow is provided for use once the required credentials are available.
