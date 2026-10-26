# Development validation — 2026-10-26

These results describe the tested build and devices, not universal USB support.

- Native Swift release build and SwiftUI app packaging/signature verification pass.
- Eight native tests pass normally and with AddressSanitizer, including 200
  cancellation/completion races, request bounds, stale callbacks, cross-device
  isolation, identity validation and local control authorization.
- Five tests against the actual loopback TCP listener pass. The test process
  exports zero devices, cannot capture hardware and does not touch the installed
  daemon's control socket or preferences.
- Two VKB Gladiator EVO sticks, a Steam Controller Puck and Tobii Eye Tracker 5
  work simultaneously. User confirmed live application input on all four after
  switching to Swift, including Tobii eye and head movement.
- VKB Windows USB instance IDs and DirectInput GUIDs match the pre-port baseline.
  Final ten-second concurrent sample: 619 reads per stick, zero read failures.
- Ten left-stick attach/read/detach cycles alternate Windows low-latency and
  zero-copy receive modes successfully. No comparative latency claim is made.
- Ten abrupt left connection reset/reimports succeed, followed by physical USB
  reads. Partial-header, missing-OUT-payload, oversized-buffer and wrong-device
  fault cases all release capture and permit a fresh physical read. Legitimate
  idle sessions are preserved.
- Regression test reproduced modern IOUSBHost endpoint stall mapped incorrectly
  to generic I/O error; corrected both modern and legacy codes to USB/IP EPIPE.
  Actual endpoint SET_FEATURE halt then CLEAR_FEATURE recovery restores physical
  VKB input within the same USB/IP session via IOUSBHostPipe.clearStall.
- GUI sharing switch and reconnect button affect only the selected left joystick;
  the other three sessions stay connected. Quitting the GUI leaves forwarding
  running. Actual About credits/title and diagnostic-file export verified.
- The installed binary was compared with its built artifact by SHA-256. The old
  Objective-C binary is preserved locally as an explicit rollback backup.

Remaining: multi-hour active gaming/tracking, frozen-Tobii reproduction and recovery,
Swift physical port-swap/replug coverage, true network outage, sleep/wake and reboot
validation. Original Objective-C lifecycle results do not count as rerun on Swift.
No guarantee of recovery from a device needing an electrical power cycle.

## Plug-and-play update

Fifteen native tests now pass normally and under AddressSanitizer, including
first-run catalog, discovery/ambiguity policy, saved catalog migration and stable
append-only identities. Five loopback tests and the Windows discovery parser test
pass. The app's bundled installer was exercised through its actual GUI and kept
all four device identities. Installed Windows helper uses automatic export discovery.

Actual left VKB replug automatically reattached. Post-replug 20-second sample:
1,240 reads per stick, zero failures; left 1,142 changing states, right X/Y unchanged;
original USB instance IDs and DirectInput GUIDs retained. This was a same-port
replug; new physical port-swap and first-32-button response were not measured here.

## Critical-path review fixes

BMad adversarial, edge-case and verification-gap reviews produced 21 initial
findings (overlaps retained) and one follow-up reset-ordering finding. The full
Markdown/JSON reports are REVIEW-2026-10-26.md and REVIEW-2026-10-26.json.

- 46 Swift tests pass normally and under AddressSanitizer. New coverage includes
  legacy saved-state migration, corrupt/unreadable sharing preferences, failed
  authorized add/unshare persistence, kernel credentials over framed local sockets,
  direct registry-entry replacement, capture identity races and slow-reader deadlines.
- The injectable native-transport tests verify endpoint/control serialization,
  native abort ordering, queued cancellation, cancelled-native count/byte budgets,
  sequence reuse, zero-completion-timeout bulk/interrupt I/O, SHORT_NOT_OK errors,
  aligned bulk OUT terminating packets, unsupported flags, configuration/interface
  reset and reset failures. Delayed successful callbacks after configuration,
  interface and clear-halt resets cannot send stale trailing packets; affected old
  queues are cancelled, while unrelated interface work survives.
- 17 Mac installer transaction tests pass on an isolated filesystem with mocked
  launchctl. One root-only sandbox rejection test is skipped under the normal user.
  ShellCheck and shell syntax checks pass. Production root checks remain enabled.
- Windows PowerShell 5.1 passed discovery/ID validation, the actual bounded reconnect
  worker with a compiled fake client, and five real-filesystem installer transactions
  using isolated paths and mocked task cmdlets. No live task operations occur in
  those transaction tests. CI now invokes these tests and Mac installer tests.
- The updated Windows helper was installed using the real staged installer. The
  SYSTEM reconnect task is Running with auto-discovery/low-latency; all four
  existing imported devices remained attached through the helper upgrade.

These tests establish the stated boundaries, not universal USB compatibility,
crash-consistent installation, measured latency, or multi-hour Tobii reliability.

Hardware checks on the reviewed release: all four devices automatically reattached,
with the original VKB USB instance IDs and healthy Windows PnP status. The real
left-VKB test completed 100 unlink pairs, all 100 acknowledged cancellation, with
every unrelated queued read and final physical read succeeding. Actual endpoint
halt recovered through clear-halt and repeated SET_CONFIGURATION in the same
session. VKB rejects optional SET_INTERFACE(0) with EPIPE; this is propagated,
the capture is released and a fresh import restores input. This does not claim
successful native alternate-setting reset on that VKB. The per-interface native
reset success/failure/order paths are covered by injected-transport tests.

Final ten-second simultaneous Windows joystick sample: 629 reads per stick, zero
failures. This stationary sample is not a movement/button test. The retry task was
restored after raw tests and all four targets were connected at completion. Final
installed daemon matches release SHA-256
`e1c98f7ae5f727b37f8d565d313782fe9cee243b71ecb374f6b5df49b5f752ca`.

## Shared control CLI integration

The optional Python CLI now calls the native Swift control client for status,
share/unshare and reconnect, preserving the same authorization and persistence.
Start/stop/restart targets only the native system service; logs use its actual
path. The Mac default self-test explicitly checks local control, with remote
USB/IP protocol checks available through --host.

Post-integration checks: 46 Swift tests, 17 adapter tests (including real isolated
helper subprocesses and failed mutation replies), 20 isolated installer transaction
tests (one additional root-only test skipped), four upstream CLI smoke tests, five
loopback protocol checks and three main-repository forwarding tests. Installer
regressions cover restoration of the CLI helper/public link and a prior link's
untouched target, plus missing/empty tool rejection before service stop.

Source CLI and main-repository forwarding CLI reach the installed service and
report all four devices connected. Service lifecycle and mutation failure tests
use isolated subprocesses/mocks; these tests do not stop the live service.
