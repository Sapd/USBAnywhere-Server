# CHANGELOG - USBAnywhere Server

## [3.0.0] - 2026-10-24

### Added
- **Rebrand & Migration to USBAnywhere Server v3.0.0 (.NET 9.0)** 🌐
  - Migrated entire project from `SnakeUSBIP-Server` (.NET 8.0) to `USBAnywhere-Server` (.NET 9.0) and linked directly with the **[USBAnywhere Client](https://github.com/oscarlosu-lab/USBAnywhere)** ecosystem.
- **One-Click "Share All" (`⚡ Share All`)** ⚡
  - Added a dedicated toolbar button to share all eligible local USB devices in a single click.
- **Interactive Server IP Badge & Client Launcher (`🔗 USBAnywhere Client`)** 🔗
  - Displays the active LAN IPv4 address and TCP port (`3240`) in the header (click to copy to clipboard) and launches `USBAnywhere.exe` locally or opens the client release page.
- **Persistent Auto-Bind Device Memory** 🔄
  - Sharing a device automatically registers its `VID:PID` in `AutoBindDevices`, and stopping it removes it, with concurrency protection against overlapping bind calls.

### Fixed
- **Fixed `Attached` and `Shared (forced)` Status Parsing** 🛠️
  - Updated `UsbipdService` regex to capture multi-word states (`Shared (forced)`, `Attached`) and stop before the `Persisted:` section, ensuring the **🚫 Stop** button remains visible for attached and force-shared devices.
- **Fixed Dynamic Theme Switching (`DynamicResource`)** 🎨
  - Removed shadowed `StaticResource` brushes in `MainWindow.xaml` and `SettingsWindow.xaml` so Dark/Light theme switching updates all UI elements immediately.
- **Fixed False Portable Detection in `C:\Program Files`** 📁
  - Updated `PathService` so running as Administrator inside `Program Files` correctly uses `%AppData%\USBAnywhere-Server` unless an explicit `.portable` / `portable.flag` file is present.
- **Fixed CLI Flags (`--minimized`, `--install-driver`) & Startup Preferences** 🚀
  - `MainWindow` now honors `--minimized`, `--install-driver`, `StartMinimized`, `CheckForUpdates`, and persists language selection in `SettingsService`.
- **Fail-Closed SHA-256 Auto-Updater (Setup & Portable)** 🔒
  - `UpdateService` now enforces `SHA256SUMS.txt` verification fail-closed and supports both `.exe` installer and `.zip` portable self-updates.

---
## [2.0.1] - 2026-10-19

### Fixed
- **Atomic Settings Persistence & Path Fix** 💾
- **Flicker-Free UI DataGrid** ⚡
- **Installer Drivers Missing** 📦
- **Safe MSI Uninstaller** 🧹
- **Elevated Windows Startup via Task Scheduler** 🚀
- **Fail-Closed SHA-256 Update Verification** 🛡️
- **Single-Instance Mutex Protection** 🔒
