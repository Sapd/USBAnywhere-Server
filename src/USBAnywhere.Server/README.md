# 🖥️ USBAnywhere Server for Windows (.NET 9)

🌐 **Language / Idioma:** **English** | [Español](README_ES.md)

Modern Windows desktop USB/IP server GUI built in C# (.NET 9.0 WPF) that wraps and enhances `usbipd-win` with persistent auto-binding, system tray minimization, and scoped firewall protection.

[![License](https://img.shields.io/badge/License-GPLv3-blue.svg?style=flat-square)](https://www.gnu.org/licenses/gpl-3.0)
[![Platform](https://img.shields.io/badge/platform-Windows%2010%2F11%20(x64)-lightgrey?style=flat-square&logo=windows)](https://github.com/oscarlosu-lab/USBAnywhere-Server)
[![.NET](https://img.shields.io/badge/.NET-9.0-purple?style=flat-square&logo=dotnet)](https://dotnet.microsoft.com/)
[![Ko-fi](https://img.shields.io/badge/Ko--fi-Support%20Project-FF5E5B?style=flat-square&logo=ko-fi&logoColor=white)](https://ko-fi.com/oscarlosu)

---

## 🏗️ Architecture

```text
USBAnywhere.Server/
├── Views/              # WPF Modern UI (Dark / Light Theme, Device List, IP badge)
├── ViewModels/         # MVVM Presentation Logic & Commands
├── Models/             # Device, Interface, and Network Data Models
├── Services/           # PnP Orchestrator, Firewall Manager, and Configuration
│   ├── UsbipdService.cs        # usbipd CLI wrapper & process manager
│   ├── FirewallService.cs      # Scoped Windows Firewall rule configuration
│   ├── ConfigService.cs        # JSON settings persistence
│   └── TrayIconService.cs      # System tray minimization & notifications
└── App.xaml.cs         # Application entry point & single-instance mutex
```

---

## 🛠️ Building & Testing

```powershell
# Restore & Build Release
dotnet build USBAnywhere.Server.csproj -c Release

# Run tests
dotnet test ..\..\tests\USBAnywhere.Server.Tests -c Release
```

---

## 📄 License

GPL-3.0 License. Developed by [oscarlosu-lab](https://github.com/oscarlosu-lab).
