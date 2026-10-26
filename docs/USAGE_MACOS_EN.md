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
