# 🖥️ Servidor USBAnywhere para Windows (.NET 9)

🌐 **Idioma / Language:** [English](README.md) | **Español**

Servidor de escritorio USB/IP para Windows con interfaz gráfica moderna desarrollada en C# (.NET 9.0 WPF) que encapsula y potencia `usbipd-win` con auto-bind persistente, minimización en la bandeja del sistema y protección de Firewall acotada.

[![Licencia](https://img.shields.io/badge/Licencia-GPLv3-blue.svg?style=flat-square)](https://www.gnu.org/licenses/gpl-3.0)
[![Plataforma](https://img.shields.io/badge/plataforma-Windows%2010%2F11%20(x64)-lightgrey?style=flat-square&logo=windows)](https://github.com/oscarlosu-lab/USBAnywhere-Server)
[![.NET](https://img.shields.io/badge/.NET-9.0-purple?style=flat-square&logo=dotnet)](https://dotnet.microsoft.com/)
[![Ko-fi](https://img.shields.io/badge/Ko--fi-Apoyar%20Proyecto-FF5E5B?style=flat-square&logo=ko-fi&logoColor=white)](https://ko-fi.com/oscarlosu)

---

## 🏗️ Arquitectura

```text
USBAnywhere.Server/
├── Views/              # Interfaz moderna WPF (Temas Claro/Oscuro, Lista, Badge IP)
├── ViewModels/         # Lógica de presentación y comandos MVVM
├── Models/             # Modelos de datos para dispositivos, interfaces y red
├── Services/           # Orquestador PnP, Administrador de Firewall y Ajustes
│   ├── UsbipdService.cs        # Envoltorio y gestor del proceso usbipd
│   ├── FirewallService.cs      # Configuración de reglas seguras del Firewall
│   ├── ConfigService.cs        # Persistencia atómica de configuración JSON
│   └── TrayIconService.cs      # Notificaciones y minimización en la bandeja
└── App.xaml.cs         # Punto de entrada y mutex de instancia única
```

---

## 🛠️ Compilación y Pruebas

```powershell
# Restaurar y compilar en Release
dotnet build USBAnywhere.Server.csproj -c Release

# Ejecutar suite de pruebas
dotnet test ..\..\tests\USBAnywhere.Server.Tests -c Release
```

---

## 📄 Licencia

Licencia GPL-3.0. Desarrollado por [oscarlosu-lab](https://github.com/oscarlosu-lab).
