# Yu-Gi-Oh! Power of Chaos Remake · Android

[English](README.md) | **Español** | [Launcher Windows](https://github.com/Johanfer12/Yu-Gi-Oh-Power-of-Chaos-Remake/tree/main)

## Contenido

- [Ventajas](#ventajas)
- [Opciones de juego](#opciones-de-juego)
- [Primera instalación](#primera-instalación)
- [Actualizaciones e instalaciones anteriores](#actualizaciones-e-instalaciones-anteriores)
- [Compilar desde el código](#compilar-desde-el-código)
- [Validación y avisos](#validación-y-avisos)

## Ventajas

- **Los tres juegos en una aplicación Android.** Usa tus recursos compatibles de Yugi, Kaiba y Joey, empezando por los juegos que tengas.
- **Importa una vez y sigue jugando al actualizar.** Tu paquete privado y tus partidas permanecen en la aplicación mientras los APK públicos compatibles actualizan el motor.
- **Prepara todo desde Windows.** **Crear APK** entrega el APK público y tu PCK privado juntos, sin cuentas, instalar SDK/JDK ni configurar una firma personal.
- **Las opciones actuales de PC también en Android.** Aspecto, FPS, simulación, juego rápido y traducciones de cartas acompañan los controles táctiles existentes.
- **Controles táctiles para los duelos.** Se conservan el scroll, el arrastre y la selección nativa de uno o dos sacrificios, con los modos de menú y mantener oprimido.
- **Joey por red local.** La conexión se probó anteriormente entre PC↔PC y PC↔Android; las pruebas actuales en dispositivos siguen siendo una tarea aparte.

El APK público contiene el motor, sin recursos originales. Tu PCK privado se prepara en tu equipo y no se sube a ningún servicio. Esta rama publica fuentes sin recursos originales ni claves privadas.

## Opciones de juego

Abre el engranaje del launcher para elegir:

| Ajuste | Opciones |
|---|---|
| Aspecto | Estirado, 4:3 original sin fondo o el fondo decorativo de cada juego. |
| FPS | 30, 60 o la frecuencia del display. |
| Simulación | Velocidad normal o 2×. |
| Juego rápido | Omite opcionalmente escenas de personajes, voces y barridos en los tres juegos; conserva música y efectos de sonido. |
| Traducciones mejoradas | Nombres y descripciones revisados en español para las 771 cartas, conservando los efectos originales. La primera preparación descarga aproximadamente 110 MB; después funciona sin conexión. |
| Controles táctiles | Con menú o mantener oprimido, con scroll, arrastre y selección de sacrificios. |

Las preferencias se guardan. Juego rápido y traducciones mejoradas vienen desactivados; las traducciones afectan las cartas, no los menús ni las reglas.

## Primera instalación

1. Descarga el EXE Windows de [Releases](https://github.com/Johanfer12/Yu-Gi-Oh-Power-of-Chaos-Remake/releases). Selecciona tus ISO o carpetas instaladas, o reutiliza la biblioteca preparada para PC.
2. Pulsa **Crear APK**. El launcher verifica el APK público y prepara un paquete privado de recursos. El flujo normal no necesita SDK, JDK ni configurar una firma.
3. Copia a tu Android los dos archivos de **PoC Data/android/apks/**: el **.apk** y su **-resources.pck**.
4. Instala y abre el APK. En **Añade tus juegos**, pulsa **Seleccionar paquete .pck**, abre **Descargas** en el selector de Android y elige tu PCK. La aplicación lo comprueba y copia a su almacenamiento. Dejar el archivo en Descargas no lo importa automáticamente.

Basta con importar ese paquete una vez. No necesitas volver a seleccionarlo al abrir la aplicación o instalar actualizaciones compatibles. El launcher PC conserva herramientas, informes y registros dentro de **PoC Data/android/**. Respalda esa carpeta junto con el EXE.

## Actualizaciones e instalaciones anteriores

El botón de actualizar de Android consulta las versiones de GitHub y abre la descarga del APK público cuando hay una actualización compatible. Descarga el APK y confirma la actualización en el instalador de Android. El sistema puede pedir permiso para instalar desde el navegador o gestor de archivos. **No desinstales primero:** actualizar la aplicación instalada conserva recursos, ajustes y partidas.

El APK público mantiene un certificado de firma estable. Antes de ofrecerlo, el actualizador comprueba los metadatos y la compatibilidad del certificado.

**Para pasar desde una instalación antigua:** prepara primero tu PCK desde PC. Si la aplicación anterior tiene otra firma, Android no puede sustituirla por el APK público como actualización. Si aceptas perder los datos de la aplicación antigua, desinstálala, instala el APK público e importa tu PCK una vez. Las actualizaciones públicas compatibles posteriores conservan ese paquete y tus partidas.

Los usuarios avanzados que necesiten conservar una instalación con otra firma pueden mantener su clave original y la configuración opcional **android-builder.json** para generar actualizaciones compatibles. El actualizador público informa de la diferencia; no elimina la aplicación, sus claves personales ni las compilaciones anteriores.

## Compilar desde el código

No hace falta clonar esta rama para usar **Crear APK** normalmente. Los desarrolladores pueden generar un APK sin recursos con sus propias herramientas y firma:

    python tools/android/build_apk.py --engine-only --godot <godot_console.exe> --sdk <Android-SDK> --debug-keystore <tu-debug.keystore> --first-build --work <carpeta-nueva> --output <nuevo.apk>

Para actualizar una instalación personalizada, cambia `--first-build` por `--previous-apk <tu-anterior.apk>` y usa su clave original. El flujo normal de **Crear APK** entrega el APK público oficial.

Para preparar sólo el paquete privado de recursos basta con Godot:

    python tools/android/build_apk.py --content-only --godot <godot_console.exe> --data <tus-datos-compactos> --work <carpeta-nueva> --content-output <recursos-privados.pck>

**game/** contiene el código editable; los proyectos exportables generados no son la fuente principal. No publiques tu paquete de recursos ni tu clave privada.

## Validación y avisos

La compilación comprueba certificado, integridad del APK, alineación de 16 KB y el arranque correspondiente: primera importación o recursos integrados. La importación, persistencia, metadatos de actualización y regresiones táctiles se comprobaron en el equipo de compilación. **El nuevo flujo de importación y actualización todavía no se verificó en un Android físico.**

Estas fuentes incluyen trabajo experimental no oficial derivado en parte mediante ingeniería inversa. La fidelidad, el soporte de hardware y la licencia de la implementación del juego siguen en revisión. La [licencia Apache 2.0](LICENSES/Apache-2.0.txt) cubre las herramientas propias que figuran en [NOTICE](NOTICE) y están presentes en esta copia. Consulta los [avisos de terceros](THIRD_PARTY_NOTICES.md).
