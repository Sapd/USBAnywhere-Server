# Windows client support and hardware validation

Uses USBAnywhere's native Windows USB/IP client/UDE driver; this folder contains
only support scripts, not a replacement Windows GUI or bundled driver binaries.
Place the scripts alongside the USBAnywhere client tools (`usbip.exe`, `usbipw.exe`,
`libusbip.dll`, `resources.dll`, `usb.ids`, and the portable driver package when
installing a driver). Driver installation requires Windows administrator access.

- `install-client.ps1`: idempotent driver/controller installation.
- `install-reconnect-client.ps1`: persistent SYSTEM startup task, configured Mac
  address, bus IDs and receiving mode. No stored user password. It copies the
  tools/helper to Program Files. The installer validates IDs, copies and checks
  the complete replacement before stopping the task, then swaps whole directories.
  A failed upgrade restores the previous files and task configuration/running state.
  A still-running native command can briefly delay a directory rename.
- `reconnect-client.ps1`: serialized bounded retries, a global mutex and rotated log.
  Default `-BusIDs auto` discovers approved exports every five seconds. Newly shared
  devices need no helper edits; explicit comma-separated lists remain supported.
- `client-discovery.ps1`, `test-discovery.ps1`: bounded export-list parser and tests.
  Discovery failure retains the last known set and retries; a valid empty export
  list is treated as empty, not as an error.
- `test-reconnect-worker.ps1`: safe integration test of the actual reconnect loop.
  Run using Windows PowerShell 5.1: `powershell.exe -NoProfile -ExecutionPolicy
  Bypass -File .\test-reconnect-worker.ps1`. It compiles a temporary fake client
  and checks empty discovery, new-device adoption, failed attach/retry, receive
  mode and existing-attachment detection. No administrator, driver, network or
  scheduled task changes are needed. A 25-second watchdog bounds the test.
  The worker's `-TestIterations` and `-TestClientPath` overrides are for isolated
  tests only; the installed task never passes them and retries indefinitely.
- `test-install-reconnect.ps1`: isolated real-filesystem installer transactions with
  mocked task operations. Requires an administrator token for the installer's
  unchanged privilege check, but does not change Program Files or real tasks.
- `uninstall-reconnect-client.ps1`: remove the helper task without deleting logs.
- `verify-dual-input.ps1`: concurrent VKB input/identity sampling; needs
  `controller-api.ps1` beside it. Samples WinMM axes and first 32 buttons.
- `test-protocol.ps1`: nondisruptive USB/IP list/framing checks.
- `test-reconnect.ps1`, `test-recovery.ps1`, `test-dual-order.ps1`: disruptive
  attachment/recovery tests. Stop the reconnect task first and restore it in a
  `finally` block. Never detach an unrelated USB device.
- `test-stall.ps1`: deliberately halt the left VKB interrupt endpoint, verify
  EPIPE and restore reads via clear-halt, then via repeated SET_CONFIGURATION,
  in the same session. It also checks SET_INTERFACE(0): devices may legally reject
  this optional default-only selection, in which case fresh-import recovery is
  required. Stop the retry task
  and detach only the left imported device first; restore retry in `finally`.
- `test-unlink.ps1`: 100 pairs of same-endpoint VKB reads, unlinking the first
  while requiring the second and a final physical read to succeed. Stop retry and
  detach only the left stick first, restoring retry in `finally`.
- `test-network.ps1`: experimental firewall-cut test. Requires proof the block is
  effective; it did not establish an actual outage on the development PC.
- `verify-xinput.ps1`: generic system XInput probe; Steam input can work without
  exposing a system-wide XInput slot to an SSH session.

A successful read of stationary/cached joystick state is not proof of movement,
network recovery or end-to-end latency. Tobii/Steam application input and long
active-session stability require separate validation.
