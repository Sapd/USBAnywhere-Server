# 🍎 USBAnywhere Server for macOS (Swift)

🌐 **Language / Idioma:** **English** | [Español](README_ES.md)

Native macOS USB/IP server implementation built in Swift 5.9+, utilizing Apple's Userspace IOKit framework (`IOKit.framework`) and `IOUSBHostInterface`.

[![License](https://img.shields.io/badge/License-GPLv3-blue.svg?style=flat-square)](https://www.gnu.org/licenses/gpl-3.0)
[![Platform](https://img.shields.io/badge/platform-macOS%20(Apple%20Silicon%20%7C%20Intel)-lightgrey?style=flat-square&logo=apple)](https://github.com/oscarlosu-lab/USBAnywhere-Server)
[![Swift](https://img.shields.io/badge/Swift-5.9%2B-orange?style=flat-square&logo=swift)](https://swift.org/)
[![Ko-fi](https://img.shields.io/badge/Ko--fi-Support%20Project-FF5E5B?style=flat-square&logo=ko-fi&logoColor=white)](https://ko-fi.com/oscarlosu)

---

## 🏗️ Architecture

```text
Sources/
├── IOKit/
│   └── IOKitDeviceManager.swift   # Enumeration and USBDeviceOpenSeize via IOKit
├── Models/
│   └── USBDevice.swift            # USB Device & Interface descriptors
├── Protocol/
│   ├── USBIPConstants.swift       # Standard USB/IP opcodes and constants
│   └── USBIPPackets.swift         # Big-endian network packet serializer
├── Server/
│   ├── URBHandler.swift           # USB Request Block transfer dispatch
│   └── USBIPServer.swift          # BSD Socket TCP server & client event loop
├── Service/
│   └── LaunchdService.swift       # System LaunchDaemon installer / uninstaller
└── main.swift                     # CLI entry point (list, bind, unbind, serve)
```

---

## 🛠️ Building & Running

```bash
# Build Universal Release binary
swift build -c release

# Run tests
swift test

# List connected devices
swift run usbanywhere-server-mac list

# Start server daemon on port 3240
swift run usbanywhere-server-mac serve --port 3240 --auto-bind
```

---

## 📄 License

GPL-3.0 License. Developed by [oscarlosu-lab](https://github.com/oscarlosu-lab).
