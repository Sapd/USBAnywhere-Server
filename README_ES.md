# 🌐 USBAnywhere Server — Servidor USB/IP para Windows

🌐 **Idioma / Language:** [English](README.md) | **Español**

**v3.0.0** | [Descargar Última Versión](https://github.com/oscarlosu-lab/USBAnywhere-Server/releases/latest) | [🔗 Cliente USBAnywhere](https://github.com/oscarlosu-lab/USBAnywhere) | [📱 USBAnywhere Android](https://github.com/oscarlosu-lab/USBAnywhere-Android) | [💬 Comunidad Reddit](https://www.reddit.com/r/UsbAnywhere/) | [📖 Manual de Usuario](docs/USAGE_ES.md)

**Comparte dispositivos USB desde cualquier PC Windows por red — Sin línea de comandos.**

Interfaz gráfica moderna en .NET 9.0 para [usbipd-win](https://github.com/dorssel/usbipd-win), vinculada nativamente con el ecosistema **[USBAnywhere v3.0](https://github.com/oscarlosu-lab/USBAnywhere)**.

[![GitHub Downloads](https://img.shields.io/github/downloads/oscarlosu-lab/USBAnywhere-Server/total?style=flat-square&logo=github&color=blue)](https://github.com/oscarlosu-lab/USBAnywhere-Server/releases)
[![GitHub Stars](https://img.shields.io/github/stars/oscarlosu-lab/USBAnywhere-Server?style=flat-square&logo=github&color=yellow)](https://github.com/oscarlosu-lab/USBAnywhere-Server/stargazers)
[![Licencia](https://img.shields.io/badge/licencia-Gratis%20Uso%20Personal%20y%20Gaming-blue?style=flat-square)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-Windows%2010%2F11%20(x64)-lightgrey?style=flat-square&logo=windows)](https://github.com/oscarlosu-lab/USBAnywhere-Server)
[![Comunidad Reddit](https://img.shields.io/badge/Reddit-r%2FUsbAnywhere-FF4500?style=flat-square&logo=reddit&logoColor=white)](https://www.reddit.com/r/UsbAnywhere/)

## ✨ Características

- 🔧 **Cero Configuración** — Instalación desatendida y automática de drivers `usbipd-win` certificados en el primer arranque.
- 📤 **Compartir con Un Clic y Compartir Todo** — Botón individual **📤 Compartir / 🚫 Detener** y botón **⚡ Compartir Todo**.
- 🔗 **Vinculación Directa con USBAnywhere Client** — Indicador interactivo con la IP local del servidor (`IP: x.x.x.x:3240`) y acceso directo a **🔗 Cliente USBAnywhere**.
- 🔄 **Auto-Bind Persistente** — Recuerda los dispositivos compartidos (`VID:PID`) y vuelve a compartirlos automáticamente al reconectarlos.
- ⚡ **Interfaz Reactiva Sin Parpadeo** — Actualización in-place y soporte completo de bandeja del sistema (`System Tray`).
- 📛 **Identificación Real** — Muestra nombres de hardware descriptivos mediante WMI y detección inteligente (CH340/Serial, Cámaras, Almacenamiento, Dongles).
- 🛡️ **Firewall y Arranque con Windows** — Configuración en 1 clic del puerto TCP 3240 en el Firewall de Windows y arranque elevado mediante Programador de Tareas.
- 🎨 **Temas Claro y Oscuro Dinámicos** — Cambio instantáneo de tema visual e idioma (Español / Inglés) persistente.
- 📦 **Modo Híbrido** — Disponible en paquete ZIP portable auto-contenido o instalador guiado Setup con auto-actualizador verificado por SHA-256.

## 📦 Instalación

1. Descarga `USBAnywhere-Server-v3.0.0-x64-Portable.zip` o el instalador `USBAnywhere-Server_Setup_v3.0.0.exe` desde [Releases](https://github.com/oscarlosu-lab/USBAnywhere-Server/releases/latest).
2. Ejecuta `USBAnywhere-Server.exe` como Administrador.
3. ¡Listo! El driver se configurará automáticamente si no está instalado.

## 🚀 Inicio Rápido

### 1. Compartir Dispositivos en el PC Servidor
1. Abre **USBAnywhere Server**.
2. Haz clic en **📤 Compartir** en el dispositivo deseado (o en **⚡ Compartir Todo**).
3. Haz clic en la insignia verde **IP** en la cabecera para copiar la IP de este servidor.

### 2. Conectar desde el Cliente USBAnywhere
Usa **[USBAnywhere Client](https://github.com/oscarlosu-lab/USBAnywhere)** en cualquier otro PC con Windows:
1. Abre **USBAnywhere Client**.
2. Pega la dirección IP del servidor.
3. Pulsa **Escanear** y conéctate a los dispositivos compartidos.

## 🔗 Ecosistema USBAnywhere

| Proyecto | Rol | Descripción |
|---|---|---|
| **[USBAnywhere (Client)](https://github.com/oscarlosu-lab/USBAnywhere)** | 🖥️ Cliente Windows + Auto-Deploy Linux/Armbian | Conecta dispositivos USB desde servidores Windows o Linux/Raspberry Pi/Orange Pi |
| **[USBAnywhere Server](https://github.com/oscarlosu-lab/USBAnywhere-Server)** | 🌐 Servidor Windows | Exporta periféricos USB conectados a un PC Windows por red (TCP 3240) |
| [usbipd-win](https://github.com/dorssel/usbipd-win) | ⚙️ Driver Base | Motor USB/IP para Windows de código abierto |

## 📄 Licencia

> **USBAnywhere es gratuito para uso personal, educativo y gaming. La redistribución comercial, cambio de marca (rebranding) o venta de este software o sus derivados está estrictamente prohibida sin el consentimiento explícito por escrito del autor.**

Consulta el archivo [LICENSE](LICENSE) para ver los términos y condiciones legales completos.

---

Desarrollado por [oscarlosu-lab](https://github.com/oscarlosu-lab)
