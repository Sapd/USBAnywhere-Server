# USBAnywhere Server para macOS

Esta implementación nativa reemplaza el servidor anterior en esta misma carpeta.
Incluye el servidor Swift con IOUSBHost, una aplicación SwiftUI, controles por
dispositivo y reconexión automática de dispositivos memorizados.

Consulta el [README completo](README.md) para compilar, instalar la aplicación,
configurar el servicio y usar los controles CLI actuales. El flujo principal es
arrastrar USBAnywhere a Aplicaciones, abrirla y completar la configuración inicial.

Los antiguos comandos `serve --auto-bind`, `bind` y `unbind` no corresponden a
esta implementación. La herramienta compartida `usbanywhere-ctl` ya utiliza el
servicio nativo: `status --json`, `list`, `share 1-1`, `unshare 1-1` y
`reconnect 1-1`. La CLI opcional requiere Python 3; la aplicación no lo requiere.
Solo `start`, `stop` y `restart` necesitan permisos de administrador. Añade nuevos
dispositivos desde la aplicación primero. `test` verifica el control local; una
prueba USB/IP de red debe ejecutarse desde el cliente autorizado.

Implementación nativa para macOS: **Denis Arnst (Sapd)** — https://github.com/Sapd.
Proyecto USBAnywhere: **oscarlosu-lab (SnakeFoxu)** — https://github.com/oscarlosu-lab.
Licencia GPL-3.0. Véanse [AUTHORS.md](AUTHORS.md) y LICENSE del repositorio.
