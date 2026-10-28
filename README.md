# AsistePY — Control de asistencia

Aplicación web académica de control de asistencia, hecha únicamente con **HTML, CSS y JavaScript**. No necesita instalación, librerías externas ni base de datos.

## Funciones

- Inicio de sesión de demostración.
- Tres roles: **cajero**, **asistente** y **gerente**.
- Registro de entrada y salida del día.
- Cálculo de tardanzas a partir del horario asignado.
- Informes por fechas y filtro por empleado.
- Exportación de informes a CSV e impresión.
- Logo y fondo de pantalla en archivos SVG.
- El gerente consulta todos los empleados; los demás solo sus propios registros.
- Botón para cargar datos de ejemplo (solo gerente).

## Usuarios de prueba

| Usuario | Contraseña | Horario |
|---|---|---|
| cajero | 1234 | 08:00 |
| asistente | 1234 | 08:30 |
| gerente | 1234 | 09:00 |

## Cómo usar

1. Abrí `index.html` en un navegador.
2. Iniciá sesión con alguno de los usuarios de prueba.
3. Usá **Registrar entrada** y **Registrar salida**.
4. Elegí fechas para generar un informe, exportalo a CSV o imprimilo.
5. Para probar los informes sin tener que esperar varios días, entrá como gerente y pulsá **Cargar datos de ejemplo**.

## Cómo publicar con GitHub Pages

1. El repositorio debe ser público para usar GitHub Pages gratis con una cuenta personal.
2. Subí **index.html**, **logo.svg**, **fondo.svg** y **README.md** a la raíz de la rama `main`.
3. Abrí el repositorio → **Settings → Pages**.
4. En **Build and deployment**, elegí **Deploy from a branch** y seleccioná **main / (root)**; después **Save**.
5. La dirección del sitio será `https://TU-USUARIO.github.io/segundo-parcial/`.

## Limitaciones de esta demostración

Este proyecto es un **prototipo académico**, no un sistema seguro de RR. HH. Las credenciales están incluidas en JavaScript y el control de roles solo funciona en el navegador. La información se guarda con `localStorage`: no se comparte entre navegadores, dispositivos o usuarios, y puede perderse si se borran los datos del sitio. No usar con datos personales reales ni para liquidar salarios.