# USBAnywhere Server for macOS

The Mac implementation is a real Swift IOUSBHost USB/IP server and a SwiftUI
menu-bar app named **USBAnywhere Server**. It replaces the earlier protocol
scaffold, including its simulated transfer replies.

See [the Mac README](../src/USBAnywhere.Server.Mac/README.md) for build, installation,
sharing controls, identity behavior, security, validation and current limitations.

Open the bundled app, select the Windows PC and approve setup once. Detected USB
devices can then be approved with Share; those choices persist across reconnects
and restarts. Developer builds and manual configuration remain available. The old
unrestricted auto-export installer and process-local `bind`/`unbind` commands are
replaced by explicit configuration and daemon-backed sharing controls. There is
no unverified prebuilt download in this source installation flow.

**Credits:** USBAnywhere by [oscarlosu-lab (SnakeFoxu)](https://github.com/oscarlosu-lab).
Native macOS server and app by [Denis Arnst (Sapd)](https://github.com/Sapd).

The optional `usbanywhere-ctl` CLI is installed during setup and requires Python 3.
It uses the same service as the app: `status --json`, `list`, `share 1-1`,
`unshare 1-1` and `reconnect 1-1`. Only service start/stop/restart require sudo.
`test` checks authenticated local control; a network USB/IP probe must originate
from the allowed client. See the Mac README for exact commands and boundaries.
