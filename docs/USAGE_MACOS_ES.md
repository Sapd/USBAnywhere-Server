# USBAnywhere Server para macOS

Servidor USB/IP nativo en Swift con acceso USB real mediante IOUSBHost y una
aplicación SwiftUI en la barra de menús. Sustituye la implementación inicial con
respuestas USB simuladas.

La documentación técnica actualizada está en inglés en
[README de macOS](../src/USBAnywhere.Server.Mac/README.md): compilación,
instalación, configuración explícita de dispositivos, controles y limitaciones.
No se exportan todos los dispositivos automáticamente. La aplicación puede
cerrarse sin detener el servidor en segundo plano.

**Créditos:** USBAnywhere por [oscarlosu-lab (SnakeFoxu)](https://github.com/oscarlosu-lab).
Servidor nativo para macOS y aplicación por [Denis Arnst (Sapd)](https://github.com/Sapd).

La CLI opcional `usbanywhere-ctl` se instala durante la configuración y requiere
Python 3. Usa el mismo servicio: `status --json`, `list`, `share 1-1`,
`unshare 1-1` y `reconnect 1-1`. Solo iniciar/detener/reiniciar el servicio requiere
sudo. `test` verifica el control local; la prueba USB/IP de red debe ejecutarse
desde el cliente autorizado. Consulta el README para los detalles.
