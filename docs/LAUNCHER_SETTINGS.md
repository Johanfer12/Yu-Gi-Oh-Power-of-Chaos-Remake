# Ajustes del launcher

El engranaje ofrece volumen y cinco selectores. El silencio se controla con el botón
de sonido exterior, sin una casilla duplicada en ajustes. Se conserva el idioma de la
esquina superior; el selector redundante del panel se ha retirado.

- **Aspecto:** Estirado ocupa la ventana completa; Original sin fondo conserva 4:3
  con bandas negras; Overlay conserva 4:3 y las ilustraciones exteriores actuales
  de cada duelo. Los menús conservan su composición original en el modo Overlay.
- **Fondo personalizado:** en **Importar más recursos**, elige **Importar fondo de
  duelo** y selecciona un PNG, JPEG o WebP. Se activa Overlay y se usa la misma
  imagen alrededor del tablero en los tres juegos. La imagen se escala con recorte
  centrado y conserva sus proporciones. La copia queda en el dispositivo. Usa
  **Restaurar fondo original** para recuperar las ilustraciones de cada juego.
- **FPS:** 30, 60 o Display. Display consulta el monitor actual, usa sincronización
  vertical y actualiza el límite al cambiar de monitor; si no informa frecuencia,
  utiliza 60. Los límites 30/60 desactivan VSync para respetar la selección.
- **Simulación:** Normal o 2×. Se aplica al entrar al juego y escala el tiempo de
  escenas, animaciones y lógica. No cambia los 30 ticks por segundo simulado del
  motor nativo. El launcher permanece a velocidad normal.

- **Juego rápido:** opcional y desactivado por defecto. En los tres juegos omite
  introducción, salida, barridos entre escenas, reacciones de personajes y voces.
  Conserva música, efectos, janken, reglas y resultados. La presentación original
  se recupera al desactivarlo.

- **Traducciones:** Originales o Mejoradas (ES), sólo para nombres y descripciones
  de las 771 cartas de los tres juegos. Parte de fuentes comunitarias públicas
  (YAML Yugi y CDBEsp) y adaptaciones revisadas para conservar los efectos del
  inglés histórico; no se presenta como traducción oficial. La primera activación
  prepara el paquete con una descarga aproximada de 110 MB. Los textos guardados
  funcionan sin conexión y el arranque no inicia descargas. Si la preparación
  falla, se usan los textos importados. Desactivarlo restaura esos textos.
  Ver [fuentes y cobertura](CARD_TRANSLATIONS.md).

Las preferencias se guardan en la sección `launcher` de `PoC Data/content.cfg`,
conservando los otros ajustes, incluso antes de importar recursos. Valores iniciales:
Overlay, Display, velocidad Normal, Juego rápido desactivado y traducciones Originales.
Volumen y silencio mantienen su guardado existente.

Clic sobre un selector avanza su valor. Arriba/abajo eligen fila, izquierda/derecha
cambian el valor, Enter activa la fila y Escape cierra el panel.

La ventana PC se crea maximizada desde `project.godot`, antes del arranque de
escenas. Ya no aparece primero a 1200×900 para maximizarse después. El aspecto
guardado se aplica a las escenas; `--window=ANCHOxALTO` sigue permitiendo forzar
un tamaño para las herramientas.

La navegación aplica el aspecto de destino de forma centralizada; retirar la escena
anterior no puede restaurar otro aspecto después de crear la nueva. La biblioteca
se reconoce como launcher al salir bajo negro, evitando capturar su formato expandido
como si fuera una pantalla original.

## Validación

23 de octubre de 2026, Godot 4.7.2, Windows, ANGLE/D3D11 (RTX 4060):

- `launcher_settings_test.gd`: headless y renderizado; ciclos de selectores, ratón,
  teclado, persistencia, conservación de otras secciones, los tres juegos en cada
  aspecto, coordenadas nativas del puntero, regreso al launcher, FPS/VSync y reloj
  nativo a 30/60 FPS con velocidades 1×/2×.
- `duel_margins_test.gd`: headless y renderizado; fondos, sombreado, entrada,
  redimensionado 4:3/16:9/21:9 y regreso al menú en los tres juegos.
- `startup_window_test.gd`: renderizado en los tres aspectos guardados; modo
  maximizado antes de boot, tamaño estable después y override explícito 1280×720.
  Evidencia en `artifacts/startup-window/`.
- `launcher_exit_test.gd`: renderizado; fundido negro antes del cambio de aspecto
  al abrir los tres juegos.

Las ejecuciones finales terminan con código 0. Evidencia local en
`artifacts/launcher-settings/`: registros y capturas `settings*.png`.

Ejemplo desde PowerShell en la raíz PC (usar siempre almacenamiento de prueba):

```powershell
. '..\ENTORNO.ps1'
& $env:POC_GODOT_EXE --headless --path game --script res://tests/launcher_settings_test.gd -- '--storage=E:/PoW Remake/PortTesting/artifacts/launcher-settings/runtime'
```

Para sondas con ventanas de tamaño fijo, añadir `--windowed` antes de `--script`.

Los FPS son el límite solicitado; no implican una medición de rendimiento garantizado.

## Publicación de shaders y juego rápido

La exportación pública incluye `.gdshaderinc`: el shader del janken y el de la onda
del cursor dependen de `native_scale.gdshaderinc`. Omitirlo deja sin renderizar las
manos giradas pese a que los PNG y la mano del jugador estén presentes. La prueba
`test_public_shaders_include_their_dependencies` revisa los includes de todos los
shaders publicables y exige que sus fuentes existan y estén permitidas.

`janken_hand_visibility_test.gd` compara capturas con y sin la mano del rival,
con renderizado real y recursos del usuario. `quick_play_test.gd` comprueba en
Yugi/Kaiba/Joey la entrada directa al janken, salida al menú, ausencia de barridos,
retratos y esperas de voces, conservación de efectos y persistencia. El modo normal
sigue usando las escenas originales.
