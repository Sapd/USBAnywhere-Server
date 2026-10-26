# USBAnywhere Server para macOS

Esta implementación nativa reemplaza el servidor anterior en esta misma carpeta.
Incluye el servidor Swift con IOUSBHost, una aplicación SwiftUI, controles por
dispositivo y reconexión automática de dispositivos memorizados.

Consulta el [README completo](README.md) para compilar, instalar la aplicación,
configurar el servicio y usar los controles CLI actuales. El flujo principal es
arrastrar USBAnywhere a Aplicaciones, abrirla y completar la configuración inicial.

Los antiguos comandos `serve --auto-bind`, `bind` y `unbind` no corresponden a
esta implementación. La adaptación de la herramienta compartida `usbanywhere-ctl`
está descrita en el [plan de integración](../../docs/brainstorms/2026-10-26-native-macos-upstream-integration.md).

Implementación nativa para macOS: **Denis Arnst (Sapd)** — https://github.com/Sapd.
Proyecto USBAnywhere: **oscarlosu-lab (SnakeFoxu)** — https://github.com/oscarlosu-lab.
Licencia GPL-3.0. Véanse [AUTHORS.md](AUTHORS.md) y LICENSE del repositorio.
