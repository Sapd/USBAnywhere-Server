# 🍎 Servidor USBAnywhere para macOS (Swift)

🌐 **Idioma / Language:** [English](README.md) | **Español**

Implementación nativa del servidor USB/IP para macOS desarrollada en Swift 5.9+, utilizando el framework IOKit en espacio de usuario (`IOKit.framework`) y `IOUSBHostInterface`.

[![Licencia](https://img.shields.io/badge/Licencia-GPLv3-blue.svg?style=flat-square)](https://www.gnu.org/licenses/gpl-3.0)
[![Plataforma](https://img.shields.io/badge/plataforma-macOS%20(Apple%20Silicon%20%7C%20Intel)-lightgrey?style=flat-square&logo=apple)](https://github.com/oscarlosu-lab/USBAnywhere-Server)
[![Swift](https://img.shields.io/badge/Swift-5.9%2B-orange?style=flat-square&logo=swift)](https://swift.org/)
[![Ko-fi](https://img.shields.io/badge/Ko--fi-Apoyar%20Proyecto-FF5E5B?style=flat-square&logo=ko-fi&logoColor=white)](https://ko-fi.com/oscarlosu)

---

## 🏗️ Arquitectura del Módulo

```text
Sources/
├── IOKit/
│   └── IOKitDeviceManager.swift   # Enumeración y captura exclusiva (seize) vía IOKit
├── Models/
│   └── USBDevice.swift            # Descriptores de periféricos e interfaces USB
├── Protocol/
│   ├── USBIPConstants.swift       # Opcodes y constantes estándar del protocolo USB/IP
│   └── USBIPPackets.swift         # Serializador de paquetes de red en formato Big-Endian
├── Server/
│   ├── URBHandler.swift           # Despacho y enrutamiento de URBs de entrada y salida
│   └── USBIPServer.swift          # Servidor TCP sobre sockets BSD y bucle de eventos
├── Service/
│   └── LaunchdService.swift       # Administrador del servicio LaunchDaemon del sistema
└── main.swift                     # Punto de entrada CLI (list, bind, unbind, serve)
```

---

## 🛠️ Compilación y Ejecución

```bash
# Compilar binario universal en Release
swift build -c release

# Ejecutar suite de pruebas
swift test

# Listar dispositivos conectados
swift run usbanywhere-server-mac list

# Iniciar servidor en puerto 3240
swift run usbanywhere-server-mac serve --port 3240 --auto-bind
```

---

## 📄 Licencia

Licencia GPL-3.0. Desarrollado por [oscarlosu-lab](https://github.com/oscarlosu-lab).
