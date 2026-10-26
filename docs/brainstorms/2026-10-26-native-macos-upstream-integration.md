---
date: 2026-10-26
topic: native-macos-upstream-integration
---

# Native macOS integration with current upstream

## Decision

Use `USBAnywhere-Server/src/USBAnywhere.Server.Mac` as the single Mac package,
replacing the previous scaffold in place. In the main USBAnywhere checkout this
is `server-windows/src/USBAnywhere.Server.Mac`; `server-windows` is a historical
submodule name whose repository now contains both desktop servers.

Keep `USBAnywhereCore`, `USBAnywhereDaemon`, `USBAnywhereApp`, tests, artwork,
Windows support helpers and packaging together. Preserve Denis Arnst (Sapd)
implementation credits and oscarlosu-lab (SnakeFoxu) project credits.

## Alternatives considered

| Approach | Assessment |
| --- | --- |
| Replace the existing Mac package | Recommended: follows upstream's chosen location, keeps one implementation and minimizes CI/install/docs changes. |
| Add another native Mac folder beside it | Leaves competing servers, commands, service paths and instructions. No technical benefit. |
| Move the Mac implementation into a new top-level repository/submodule | Adds repository and release coordination; contradicts upstream's recent consolidation. |

The main checkout's local `server-macos/` already labels itself historical and
forwards build/test to the canonical package. Retain it as local history, not a
second implementation to publish. Renaming the desktop-server submodule is a
separate ecosystem change and is unnecessary for this contribution.

## Integration boundaries

- Retain upstream Windows/Linux additions and their CI jobs. Replace only the Mac
  scaffold and Mac-specific installation/docs; keep our safety and regression work.
- Keep the shared `usbanywhere-ctl` interface, adapting its Mac branch to our native
  CLI/local-control socket. Do not copy USB transport, persistence or authorization
  into Python. Linux behavior should stay independent.
- Adapter work must cover actual service label `local.usbanywhere.macos`, the helper
  in `/Library/PrivilegedHelperTools/USBAnywhereMac`, JSON `list` output, `--control`
  actions, configured listen address and actual log paths. Remove old Mac `bind`,
  `unbind`, `serve --auto-bind` and broad process-kill assumptions from this path.
- Main-repository Mac installers/control entry points should delegate to canonical
  server implementations. Avoid maintaining two forked copies of installation logic.
- Keep the app as the primary plug-and-play flow. CLI/control tools are optional
  automation entry points over the same service and permissions.
- Add adapter integration tests; upstream's four generic output tests do not verify
  compatibility with the native Mac service. Preserve all three platform CI jobs.

## Pull completed

Main repository: `b1fbcca7555e46f684f272371091f88142bb92e6`.
Server repository: `d3455ca1f20c0545a2837e66f82d8d79dc49c7cd`.
Both were fast-forwarded. Overlapping changes were reconciled; the old modified
`Sources/main.swift` remains removed because the new daemon/app entry points replace
it. Our full native package was compared byte-for-byte with the pre-pull snapshot.
CI combines our Mac/Windows checks and packaging with upstream's new Linux/control
jobs. All local source credits remain intact.

Validation after merge: 46 Swift tests, five real loopback tests and four upstream
Control Suite output tests pass. These do not establish a completed Mac adapter.
The installed service was not reinstalled or restarted by this repository update.

## Implemented integration

The shared Mac CLI now delegates sharing/status/reconnect to the existing Swift
control client, with native service paths, catalog formatting and accurate test
boundaries. Service lifecycle targets only the registered system service. The
optional Python tool is bundled and installed transactionally with rollback of
its helper file and public link. Main-repository entry points delegate to this
canonical implementation. The old parallel Mac scaffold remains removed.

Added native-adapter, real-helper-subprocess, installer rollback and forwarding
regressions. Both platform documentation sets describe the app-first flow and
optional Python CLI. Local engineering notes and historical prototypes remain
outside the published implementation.
