# 🌐 USBAnywhere Server — Windows USB/IP Server

🌐 **Language / Idioma:** **English** | [Español](README_ES.md)

**v3.0.0** | [🌍 Official Website](https://oscarlosu-lab.github.io/USBAnywhere/) | [Download Latest](https://github.com/oscarlosu-lab/USBAnywhere-Server/releases/latest) | [🔗 USBAnywhere Client](https://github.com/oscarlosu-lab/USBAnywhere) | [📱 USBAnywhere Android](https://github.com/oscarlosu-lab/USBAnywhere-Android) | [💬 Reddit Community](https://www.reddit.com/r/UsbAnywhere/) | [📖 User Manual](docs/USAGE_EN.md)

**Share USB devices from any Windows PC over your network — Zero command line required.**

A clean, modern .NET 9.0 GUI server for [usbipd-win](https://github.com/dorssel/usbipd-win), natively integrated into the **[USBAnywhere v3.0 Ecosystem](https://github.com/oscarlosu-lab/USBAnywhere)**.

[![GitHub Downloads](https://img.shields.io/github/downloads/oscarlosu-lab/USBAnywhere-Server/total?style=flat-square&logo=github&color=blue)](https://github.com/oscarlosu-lab/USBAnywhere-Server/releases)
[![GitHub Stars](https://img.shields.io/github/stars/oscarlosu-lab/USBAnywhere-Server?style=flat-square&logo=github&color=yellow)](https://github.com/oscarlosu-lab/USBAnywhere-Server/stargazers)
[![License](https://img.shields.io/badge/License-GPLv3-blue.svg?style=flat-square)](https://www.gnu.org/licenses/gpl-3.0)
[![Platform](https://img.shields.io/badge/platform-Windows%2010%2F11%20(x64)-lightgrey?style=flat-square&logo=windows)](https://github.com/oscarlosu-lab/USBAnywhere-Server)
[![Website](https://img.shields.io/badge/Website-USBAnywhere-06B6D4?style=flat-square&logo=googlechrome&logoColor=white)](https://oscarlosu-lab.github.io/USBAnywhere/)
[![Reddit Community](https://img.shields.io/badge/Reddit-r%2FUsbAnywhere-FF4500?style=flat-square&logo=reddit&logoColor=white)](https://www.reddit.com/r/UsbAnywhere/)
[![Ko-fi](https://img.shields.io/badge/Ko--fi-Support%20Project-FF5E5B?style=flat-square&logo=ko-fi&logoColor=white)](https://ko-fi.com/oscarlosu)

## ✨ Features

- 🔧 **Zero Configuration** — Auto-installs official `usbipd-win` drivers on first run
- 📤 **One-Click & Share All** — Instant Share/Stop toggles or **⚡ Share All** for all local USB peripherals
- 🔗 **USBAnywhere Ecosystem Link** — Clickable Server IP badge (`IP: x.x.x.x:3240`) and **🔗 USBAnywhere Client** launcher button
- 🔄 **Persistent Auto-Bind** — Automatically re-shares remembered `VID:PID` devices when reconnected
- ⚡ **Flicker-Free UI** — Reactive in-place device updates and System Tray background mode
- 📛 **Smart Device Names** — Real product descriptions via WMI and `VID:PID` matching (including CH340/Serial, Webcams, Storage, Dongles)
- 🛡️ **Firewall & Elevated Startup** — Built-in Windows Firewall helper (TCP 3240) and Task Scheduler logon integration
- 🎨 **Dynamic Dark & Light Themes** — Instant runtime theme and ES/EN language switching
- 📦 **Hybrid Mode** — Self-contained portable ZIP or standard Inno Setup installer with fail-closed SHA-256 auto-updater

## 📦 Installation

1. Download `USBAnywhere-Server-v3.0.0-x64-Portable.zip` or `USBAnywhere-Server_Setup_v3.0.0.exe` from [Releases](https://github.com/oscarlosu-lab/USBAnywhere-Server/releases/latest)
2. Run `USBAnywhere-Server.exe` as Administrator
3. Done! The driver will be installed automatically if needed.

## 🚀 Quick Start

### 1. Share USB Devices on the Server PC
1. Launch **USBAnywhere Server**
2. Click **📤 Share** on any USB device (or **⚡ Share All** to export all eligible USB devices)
3. Click the green **IP badge** in the top bar (or **🔗 USBAnywhere Client**) to copy your server's IP address

### 2. Connect from USBAnywhere Client
Use **[USBAnywhere Client](https://github.com/oscarlosu-lab/USBAnywhere)** on another Windows PC:
1. Open **USBAnywhere Client**
2. Paste your server's IP address
3. Click **Scan** → **Connect** to attach remote USB devices locally!

## 🔗 USBAnywhere Ecosystem

| Component | Platform / Role | Description |
|---|---|---|
| **[USBAnywhere Client](https://github.com/oscarlosu-lab/USBAnywhere)** | 🖥️ Windows 10/11 (x64 / ARM64) | Connect to remote USB devices with WHQL drivers & WSK engine |
| **[USBAnywhere Server](https://github.com/oscarlosu-lab/USBAnywhere-Server)** | 🌐 Windows 10/11 (.NET 9.0) | Share local USB peripherals over network with GUI & Auto-Bind |
| **[USBAnywhere Android](https://github.com/oscarlosu-lab/USBAnywhere-Android)** | 📱 Android & Android TV | Rootless USB/IP server, Sunshine handoff & DualSense haptics |
| **[Official Website](https://oscarlosu-lab.github.io/USBAnywhere/)** | 🌍 Web Portal | Interactive guides, documentation & download hub |
| **[Reddit Community](https://www.reddit.com/r/UsbAnywhere/)** | 💬 r/UsbAnywhere | Support, discussions, community setups & announcements |
| **[Support on Ko-fi](https://ko-fi.com/oscarlosu)** | ☕ Community | Support hosting, driver testing & open-source engineering |
| [usbipd-win](https://github.com/dorssel/usbipd-win) | ⚙️ Core Driver | Underlying Windows USB/IP kernel driver by Frans van Dorsselaer |

## ⚙️ Requirements

- Windows 10/11 (x64)
- Administrator privileges
- Network connection (LAN/WiFi, TCP port 3240)

## 📄 License

This project is licensed under the **GNU General Public License v3.0 (GPLv3)**.

> **USBAnywhere Server is 100% Free and Open Source.** You are free to run, study, share, and modify the software under the terms of the GNU General Public License as published by the Free Software Foundation.

See [LICENSE](LICENSE) for full legal terms and conditions.

---

Developed by [oscarlosu-lab](https://github.com/oscarlosu-lab)
