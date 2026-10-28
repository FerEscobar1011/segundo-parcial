# AsistePY — Control de asistencia

Aplicación web académica hecha con **HTML, CSS y JavaScript**, publicada en GitHub Pages.

## Pantalla inicial

Tiene dos opciones:
1. **Marcar asistencia**: un empleado inicia sesión y registra su entrada o salida.
2. **Panel de administrador**: el gerente consulta reportes por fecha, descarga CSV, imprime informes y carga fotos a los perfiles.

## Usuarios de demostración

| Usuario | Rol | Contraseña | Horario de entrada |
| --- | --- | --- | --- |
| cajero | Cajero | 1234 | 08:00 |
| asistente | Asistente | 1234 | 08:30 |
| gerente | Gerente | 1234 | 09:00 |

El panel de administrador acepta únicamente el usuario `gerente`.

## Funciones
- Inicio con dos botones.
- Login de demostración para empleados y gerente.
- Registro de entrada y salida del día.
- Cálculo de tardanzas comparando la hora registrada con el horario.
- Informes filtrados por fecha y empleado.
- Exportación CSV e impresión de reportes.
- Fotos de perfil cargadas por el gerente.
- Fondo e imagen de logo en SVG.
- Botón para cargar asistencias de ejemplo.

## Sitio

https://ferescobar1011.github.io/segundo-parcial/

## Importante

Este proyecto es una **demostración académica**, no un sistema real de control de asistencia.

Los datos y las fotos se guardan en el `localStorage` del navegador: no se sincronizan entre computadoras, usuarios ni dispositivos. Las credenciales están en el código y no ofrecen autenticación segura, y los roles se aplican solo en el navegador. No subir fotos ni datos personales reales. Para una empresa se necesitarían un servidor, base de datos y autenticación segura.
