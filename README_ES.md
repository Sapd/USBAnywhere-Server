# 🌐 USBAnywhere Server — Servidor USB/IP para Escritorio (Windows & macOS)

🌐 **Language / Idioma:** [English](README.md) | **Español**

**v3.0.1** | [🌍 Sitio Web Oficial](https://oscarlosu-lab.github.io/USBAnywhere/) | [Descargar Última Versión](https://github.com/oscarlosu-lab/USBAnywhere-Server/releases/latest) | [🔗 Cliente USBAnywhere](https://github.com/oscarlosu-lab/USBAnywhere) | [📱 USBAnywhere Android](https://github.com/oscarlosu-lab/USBAnywhere-Android) | [💬 Comunidad Reddit](https://www.reddit.com/r/UsbAnywhere/) | [📖 Manual Windows](docs/USAGE_ES.md) | [🍎 Manual macOS](docs/USAGE_MACOS_ES.md)

**Comparte periféricos USB locales desde PCs Windows y Apple Macs a través de tu red doméstica o VPN.**

Una suite de servidor de escritorio unificada que combina:
- **Windows**: Servidor gráfico moderno en .NET 9.0 (WPF) con wrapper sobre [usbipd-win](https://github.com/dorssel/usbipd-win).
- **macOS**: Servidor Swift con IOUSBHost, CLI y aplicación SwiftUI. Validación física actual en Apple Silicon.

Parte del **[Ecosistema de Código Abierto USBAnywhere v3.0+](https://github.com/oscarlosu-lab/USBAnywhere)**.

[![GitHub Downloads](https://img.shields.io/github/downloads/oscarlosu-lab/USBAnywhere-Server/total?style=flat-square&logo=github&color=blue)](https://github.com/oscarlosu-lab/USBAnywhere-Server/releases)
[![GitHub Stars](https://img.shields.io/github/stars/oscarlosu-lab/USBAnywhere-Server?style=flat-square&logo=github&color=yellow)](https://github.com/oscarlosu-lab/USBAnywhere-Server/stargazers)
[![License](https://img.shields.io/badge/License-GPLv3-blue.svg?style=flat-square)](https://www.gnu.org/licenses/gpl-3.0)
[![Platform Windows](https://img.shields.io/badge/platform-Windows%2010%2F11%20(x64)-lightgrey?style=flat-square&logo=windows)](https://github.com/oscarlosu-lab/USBAnywhere-Server)
[![Platform macOS](https://img.shields.io/badge/platform-macOS%20(Apple%20Silicon%20%2F%20Intel)-lightgrey?style=flat-square&logo=apple)](docs/USAGE_MACOS_ES.md)
[![Website](https://img.shields.io/badge/Website-USBAnywhere-06B6D4?style=flat-square&logo=googlechrome&logoColor=white)](https://oscarlosu-lab.github.io/USBAnywhere/)
[![Reddit Community](https://img.shields.io/badge/Reddit-r%2FUsbAnywhere-FF4500?style=flat-square&logo=reddit&logoColor=white)](https://www.reddit.com/r/UsbAnywhere/)
[![Ko-fi](https://img.shields.io/badge/Ko--fi-Support%20Project-FF5E5B?style=flat-square&logo=ko-fi&logoColor=white)](https://ko-fi.com/oscarlosu)

---

## ✨ Características Principales

- 🖥️ **Soporte de Servidor Windows y 🍎 macOS** — Comparte periféricos desde tu PC Windows o tu Mac hacia cualquier cliente de red local, Wi-Fi o VPN.
- 🎮 **Ideal para Joysticks, SimRacing y Gaming** — Reenvía palancas de vuelo, volantes, mandos, tarjetas de sonido/DAC y adaptadores serie con mínima latencia.
- 🔧 **Cero Configuración en Windows** — Instalación automatizada de drivers oficiales `usbipd-win` en el primer arranque.
- 🍎 **Aplicación nativa para Mac** — Compartir, reconectar y consultar diagnósticos por dispositivo.
- 📤 **Compartir en 1 Clic & Compartir Todo** — Conmutadores individuales o botón **⚡ Compartir Todo**.
- 🔄 **Auto-Bind Persistente** — Vuelve a compartir automáticamente periféricos memorizados por `VID:PID` al reconectarse.
- 🛡️ **Seguridad y Firewall Reforzado** — Reglas de Windows Firewall acotadas a la subred local; demonio macOS seguro.
- 🎨 **Temas Dinámicos Claro y Oscuro (Windows)** — Cambio de tema e idioma (ES/EN) en tiempo de ejecución.

---

## 🚀 Inicio Rápido — Servidor Windows

1. Descarga `USBAnywhere-Server_Setup_v3.0.1.exe` o el archivo ZIP portable desde [Releases](https://github.com/oscarlosu-lab/USBAnywhere-Server/releases/latest).
2. Ejecuta `USBAnywhere-Server.exe` como Administrador.
3. Haz clic en **📤 Compartir** en cualquier periférico (o en **⚡ Compartir Todo**).
4. Haz clic en la **etiqueta verde con la IP** en la barra superior para copiar la dirección de tu servidor.
5. Abre **[USBAnywhere Client](https://github.com/oscarlosu-lab/USBAnywhere)** en tu PC cliente, escribe la IP y ¡conéctate!

---

## 🍎 Inicio Rápido — Servidor macOS

Servidor nativo en Swift y aplicación SwiftUI en la barra de menús. Compila desde
este repositorio y configura explícitamente los dispositivos que deseas compartir.
Consulta [README de macOS](src/USBAnywhere.Server.Mac/README.md) para las instrucciones
actualizadas y limitaciones. No se instala un binario universal desde una URL.


---

## 🐧 Inicio Rápido — Servidor Linux (Debian/Ubuntu/Raspberry Pi)

En tu equipo Linux o Raspberry Pi, abre la **Terminal** y ejecuta:

```bash
curl -fsSL https://raw.githubusercontent.com/oscarlosu-lab/USBAnywhere-Server/main/scripts/install-server-linux.sh | sudo bash
```

---

## 🎛️ Suite de Control USBAnywhere (`usbanywhere-ctl`)

La aplicación nativa de Mac instala la CLI opcional en `/usr/local/bin/usbanywhere-ctl`.
Usa el mismo servicio y autorización que la interfaz gráfica. La CLI requiere
Python 3 y su biblioteca estándar; la aplicación Swift no necesita Python.
Linux conserva su backend systemd/usbip. Desde el repositorio puedes ejecutar
`python3 scripts/usbanywhere-ctl` antes de instalar.

En macOS, `test` verifica el control local autenticado. La prueba de red USB/IP
debe ejecutarse desde el cliente Windows autorizado, o con `--host` para otro
servidor accesible. El control local no demuestra entrada física del dispositivo.

```bash
# Abrir el panel de control interactivo (Dashboard TUI):
usbanywhere-ctl

# Diagnóstico de salud del sistema (módulos, puertos, permisos):
usbanywhere-ctl doctor

# Autoverificación del protocolo binario USB/IP en bucle local:
usbanywhere-ctl test

# Gestión del servicio en segundo plano (launchd / systemd):
usbanywhere-ctl status
sudo usbanywhere-ctl start
sudo usbanywhere-ctl stop
sudo usbanywhere-ctl restart

# Inventario y exportación de dispositivos:
usbanywhere-ctl list
sudo usbanywhere-ctl share 1-1
sudo usbanywhere-ctl unshare 1-1

# Monitorización de logs en tiempo real:
usbanywhere-ctl logs
```

---

## 🔗 Ecosistema USBAnywhere

| Componente | Plataforma / Rol | Descripción |
|---|---|---|
| **[USBAnywhere Client](https://github.com/oscarlosu-lab/USBAnywhere)** | 🖥️ Windows 10/11 (x64 / ARM64) | Conexión a periféricos remotos con drivers certificados WHQL y motor WSK |
| **[USBAnywhere Server](https://github.com/oscarlosu-lab/USBAnywhere-Server)** | 🌐 Windows & 🍎 macOS | Servidor USB/IP de escritorio con interfaz gráfica (Windows) y demonio Swift (macOS) |
| **[USBAnywhere Android](https://github.com/oscarlosu-lab/USBAnywhere-Android)** | 📱 Android & Android TV | Servidor USB/IP sin root, automatización Sunshine y háptica DualSense |
| **[Script Servidor Linux](https://github.com/oscarlosu-lab/USBAnywhere/blob/main/scripts/install-server.sh)** | 🐧 Linux & Raspberry Pi | Script en 1 clic para auto-exportar dispositivos por udev/kernel |
| **[Sitio Web Oficial](https://oscarlosu-lab.github.io/USBAnywhere/)** | 🌍 Portal Web | Guías interactivas, documentación y descargas |
| **[Comunidad Reddit](https://www.reddit.com/r/UsbAnywhere/)** | 💬 r/UsbAnywhere | Soporte, debates, configuraciones de la comunidad y avisos |
| **[Apoyo en Ko-fi](https://ko-fi.com/oscarlosu)** | ☕ Comunidad | Apoya el hosting, pruebas de drivers e ingeniería de código abierto |

## ⚙️ Requisitos

- **Windows**: Windows 10/11 (x64), permisos de Administrador, puerto TCP 3240.
- **macOS**: macOS 13 Ventura o superior (Apple Silicon M1/M2/M3/M4 o Intel x86_64), puerto TCP 3240.

## 📄 Licencia

Este proyecto está bajo licencia **GNU General Public License v3.0 (GPLv3)**.

Consulta el archivo [LICENSE](LICENSE) para conocer los términos completos.

---

Desarrollado por [oscarlosu-lab](https://github.com/oscarlosu-lab)

Servidor nativo para macOS y aplicación por [Denis Arnst (Sapd)](https://github.com/Sapd).
