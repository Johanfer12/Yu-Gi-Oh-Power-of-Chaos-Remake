## v0.1.0-alpha.38

- Joey: with the FORBIDDEN/LIMITED option on, the duel now starts. The starter deck has two forbidden cards (Change of Heart and Harpie's Feather Duster); the first try removes them and shows the deck error as in the original, and the next try starts the duel with the remaining 40 cards. Before, the error came back on every try (issue #8).
- Importer: the original US edition of Yugi the Destiny (2003, 165 cards) is now recognized and reported as not supported yet, instead of suggesting the Data.dat was changed by a mod. Use the European edition (2004) of Yugi (issue #7).

Android: update from the launcher; the APK downloads inside the app and Android asks you to confirm the installation. Keep the app installed to retain your imported PCK and saves. Android42 uses the same package and signing certificate as Android41. No new physical-device validation is claimed.

Joey: con la opción FORBIDDEN/LIMITED activa, el duelo ya empieza. El mazo inicial trae dos cartas prohibidas (Cambio de idea y El Duster de pluma de Harpie); el primer intento las quita y muestra el aviso de mazo como el original, y el siguiente empieza el duelo con las 40 restantes. El importador reconoce además el Yugi estadounidense de 2003 y avisa de que aún no es compatible.

## v0.1.0-alpha.37

- Google Drive: **Connect** now opens Google's normal sign-in page in your browser. Choose your account, allow access and return to the game; no code to type and no YouTube channel selection. If Drive was already connected, nothing changes and you don't need to connect again.

Android: update from the launcher; the APK downloads inside the app and Android asks you to confirm the installation. Keep the app installed to retain your imported PCK and saves. Android41 uses the same package and signing certificate as Android40. On Android the browser sign-in has not been tried on a physical device yet.

Google Drive: **Conectar** abre ahora la página normal de inicio de sesión de Google en tu navegador; eliges cuenta, aceptas y vuelves al juego, sin escribir un código ni elegir canal de YouTube. Si ya tenías Drive conectado, no cambia nada.

## v0.1.0-alpha.36

- Android: new **Import .pck…** option in Settings → Save data. To add a game later (for example Kaiba after Yugi), create a new .pck with all your games in the PC launcher, select it there and reopen the app. Your saves and settings are kept (issue #6).
- Google Drive now has its own cloud button next to Exit, with a status dot, and opens its menu directly.
- At 2× simulation speed, Yugi's voice lines no longer overlap (for example when he activates Swords of Revealing Light) (issue #5).
- Exodia: the five pieces are now revealed by a top-to-bottom sweep as in the original, instead of flashing back to white; sparks, arm fade-in and the falling ball also follow the original (issue #5).
- Smoother card destruction: breaking a card and the character cut-in drops no longer create hundreds of objects per frame, which caused hiccups, especially on phones (issue #5).

Android: update from the launcher; the APK downloads inside the app and Android asks you to confirm the installation. Keep the app installed to retain your imported PCK and saves. Android40 uses the same package and signing certificate as Android39. No new physical-device validation is claimed.

Android: nueva opción **Importar .pck…** en Configuración → Partida para añadir juegos más tarde (por ejemplo Kaiba después de Yugi) sin perder partidas ni ajustes. Google Drive tiene su propio botón de nube junto a Salir. A velocidad x2 las frases de Yugi ya no se pisan; las piezas de Exodia se descubren con el barrido del original, y destruir una carta ya no da tirones.

## v0.1.0-alpha.35

- Android: choosing the target of a card with a tap works again. After activating an equip card such as Sword of Dark Destruction and pressing OK, tapping the monster kept bringing back "Designate the monster that you wish to equip" instead of equipping it. A single tap now selects the target in Yugi and Kaiba duels (issue #4).

Android: update from the launcher; the APK downloads inside the app and Android asks you to confirm the installation. Keep the app installed to retain your imported PCK and saves. Android39 uses the same package and signing certificate as Android38. No new physical-device validation is claimed.

Android: elegir el objetivo de una carta con un toque vuelve a funcionar. Tras activar una carta de equipo como Espada de la destrucción oscura y pulsar OK, tocar el monstruo volvía a mostrar "Designa al monstruo que deseas equipar" en lugar de equiparlo. Ahora un toque elige el objetivo en los duelos de Yugi y Kaiba (issue #4).

## v0.1.0-alpha.34

- Joey the Passion: the tournament (best of three) result board now shows the right banner and marks. Winning the match showed the small "DRAW" stamp instead of "YOU WIN", the rival's row used the player's blue "LOSE" mark, and a drawn duel would have shown "LOSE".

Android: update from the launcher; the APK downloads inside the app and Android asks you to confirm the installation. Keep the app installed to retain your imported PCK and saves. Android38 uses the same package and signing certificate as Android37. No new physical-device validation is claimed.

Joey: el tablero del torneo (al mejor de tres) muestra el rótulo y las marcas correctos. Al ganar el match salía el sello "EMPATE" en vez de "HAS GANADO", la fila del rival usaba el "PIERDES" azul del jugador y un duelo empatado habría mostrado "PIERDES".

## v0.1.0-alpha.33

- Fixed a freeze in Yugi and Kaiba duels: after the CPU used Thunder Dragon's effect from the hand (discard it to add two Thunder Dragons from the deck), the game kept showing "Shuffling Deck..." forever. The deck is now shuffled once and the duel continues.
- Joey the Passion: normal duels start with the original's native local player, so who goes first and the saved replays match the original game.
- Kaiba the Revenge: the title screen uses the original random number sequence.

Android: update from the launcher; the APK downloads inside the app and Android asks you to confirm the installation. Keep the app installed to retain your imported PCK and saves. Android37 uses the same package and signing certificate as Android36. No new physical-device validation is claimed.

Arreglado un bloqueo en los duelos de Yugi y Kaiba: tras el efecto de mano de Thunder Dragon de la CPU, la partida se quedaba en "Shuffling Deck..." para siempre; ahora baraja una vez y el duelo sigue. Joey arranca el duelo normal con el jugador local nativo del original, y la portada de Kaiba usa la secuencia aleatoria original.

## v0.1.0-alpha.32

- New **Voices +** button in the import screen: add another dub from a compatible copy of the same game (its `Voice.dat`), for example the English voices from a US disc on top of a European Yugi. Pick the game, select the `Voice.dat`, then click **Extract for PC**. Both dubs are kept; the launcher uses the one matching its language.
- The import actions are now four compact buttons: Extract for PC, Voices +, Create .pck and Download APK.

Android: update from the launcher; the APK downloads inside the app and Android asks you to confirm the installation. Keep the app installed to retain your imported PCK and saves. Android36 uses the same package and signing certificate as Android35. No new physical-device validation is claimed.

Nuevo botón **Voces +** en la pantalla de importación para añadir el doblaje de otra copia compatible del mismo juego (su `Voice.dat`), por ejemplo las voces inglesas sobre un Yugi europeo. Las acciones de importación pasan a ser cuatro botones compactos.

## v0.1.0-alpha.31

- Installations made by some third-party installers, which unpack `Data.dat` into a `data` folder of loose files, can now be imported: the launcher checks that the folder belongs to the selected game and packs it back automatically. Tested with an unpacked US Kaiba the Revenge: same engine data, and all 16 original Kaiba replays play back exactly.

Android: update from the launcher; the APK downloads inside the app and Android asks you to confirm the installation. Keep the app installed to retain your imported PCK and saves. Android35 uses the same package and signing certificate as Android34. No new physical-device validation is claimed.

Se pueden importar las instalaciones que algunos instaladores de terceros dejan con `Data.dat` desempaquetado en una carpeta `data`: el launcher comprueba que es del juego elegido y la vuelve a empaquetar automáticamente.

## v0.1.0-alpha.30

- Kaiba the Revenge: the US retail disc (Konami of America, 2004) is now accepted. Its executable only differs from the supported one in how DLL names are written, so the duel engine data is identical; all 16 original Kaiba replays play back exactly with it.
- Import errors no longer repeat the game name ("kaiba: kaiba: …").
- Known limitation: Yugi the Destiny from the US release (2003, and its December 2003 update) is a different build of the game and is not supported yet. Yugi currently works with the later European/Spanish edition.

Android: update from the launcher; the APK downloads inside the app and Android asks you to confirm the installation. Keep the app installed to retain your imported PCK and saves. Android34 uses the same package and signing certificate as Android33. No new physical-device validation is claimed.

Kaiba: se acepta el CD estadounidense; su ejecutable solo cambia la forma de escribir los nombres de DLL y las 16 repeticiones originales se reproducen igual. Los errores de importación ya no repiten el nombre del juego. Limitación conocida: el Yugi estadounidense (2003 y su actualización de diciembre de 2003) es otra compilación y aún no es compatible; Yugi funciona con la edición europea/española posterior.

## v0.1.0-alpha.29

- Clearer import errors. If a Data.dat belongs to another game (for example, several games installed in the same folder) the launcher names that game; if the Data.dat or the executable looks modified by a mod or card pack, it says so and asks for an original installation or ISO. When an ISO contains the installer, the real reason from inside it is shown instead of "found: 0".
- Import, Android pack and error messages now follow the launcher language (English, Spanish, German, French, Italian and Japanese). Technical details stay available under "Technical details" and in the log.
- Android: a .pck that lacks a game's duel engine data is rejected when you select it, with a message naming the game, instead of failing later with "Faltan los datos del motor de duelo".

Android: update from the launcher; the APK downloads inside the app and Android asks you to confirm the installation. Keep the app installed to retain your imported PCK and saves. Android33 uses the same package and signing certificate as Android32. No new physical-device validation is claimed.

Errores de importación más claros: si un Data.dat es de otro juego el launcher dice de cuál, y si el Data.dat o el ejecutable parecen modificados por un mod lo indica y pide una instalación o ISO original. Los mensajes de importación y de error salen en el idioma del launcher. En Android, un .pck sin los datos del motor de duelo de algún juego se rechaza al seleccionarlo, nombrando el juego.

## v0.1.0-alpha.28

- Launcher dialogs (reset, Google Drive, update, import errors) now match the gold style of the settings panel.
- Fixed animation glitches introduced in alpha.26:
  - Coins and dice no longer show flattened ghost copies beside them, and the coin shine is clean again.
  - Damage numbers no longer slide in from another digit (most visible when Joey takes damage).
  - Joey: "Draw Phase" no longer plays twice at the start of each turn.

Android: update from the launcher; the APK downloads inside the app and Android asks you to confirm the installation. Keep the app installed to retain your imported PCK and saves. Android32 uses the same package and signing certificate as Android31. No new physical-device validation is claimed.

Las ventanas del launcher (reiniciar, Google Drive, actualizar, errores de importación) usan el estilo dorado del panel de ajustes. Arreglados los fallos de animación de alpha.26: las monedas y los dados ya no muestran copias fantasma aplanadas, las cifras de daño ya no se deslizan desde otra cifra y en Joey "Draw Phase" ya no sale dos veces al empezar cada turno. En Android, actualiza desde el launcher; no desinstales la app ni borres sus datos.

## v0.1.0-alpha.27

- Optional Google Drive save sync between PC and Android: open the launcher settings, **Save data → Google Drive… → Connect**, enter the code shown at google.com/device and allow access. Cards, decks, results and progress sync when you return to the game selector and shortly after each save. If both devices changed, the launcher asks which save to keep; the other stays as a backup. Each player's save goes to their own Drive, and the game can only see the files it creates. Music volume, touch controls and display options stay per device. Privacy policy: docs/PRIVACY.md.
- Google may show "unverified app" when connecting; continue with **Advanced → Go to Power of Chaos Remake**.

Android: update from the launcher; the APK downloads inside the app and Android asks you to confirm the installation. Keep the app installed to retain your imported PCK and saves. Android31 uses the same package and signing certificate as Android30. No new physical-device validation is claimed.

Sincronización opcional de la partida con Google Drive entre PC y Android: en los ajustes del launcher, **Partida → Google Drive… → Conectar**, escribe el código en google.com/device y permite el acceso. Cartas, barajas, resultados y progreso se sincronizan al volver al selector y poco después de cada guardado; si cambiaron ambos dispositivos, el launcher pregunta cuál conservar. Cada jugador guarda en su propio Drive. Si Google avisa de «app no verificada», continúa con **Configuración avanzada → Ir a Power of Chaos Remake**. En Android, actualiza desde el launcher; no desinstales la app ni borres sus datos.

## v0.1.0-alpha.26

- Overlay mode is now as sharp as Stretch: the duel is drawn at your screen's resolution instead of being upscaled from 800×600.
- Smoother animations at your display's refresh rate:
  - Destruction smoke and other frame-by-frame effects blend between frames instead of jumping.
  - Phase names ("Main Phase"…) no longer flicker when their two copies join.
  - The darkening and sweeping band at the start of a duel, the Kaiba and Joey title intros and Joey's level-change stars move every frame.
  - Android: the Display option no longer caps the game at 60 FPS on 90/120 Hz screens.
- Card collection works like the original: a new game starts empty and each game gives its starter deck the first time you open it. Kaiba and Joey only treat you as a player with previous cards (stronger CPU decks, Joey's full card set) if you really played the earlier games. Existing saves keep their cards; reset from the launcher settings to start over.
- Yugi and Kaiba: surrendering no longer counts as a loss or breaks your winning streak, as in the original.

Android: update from the launcher; the APK downloads inside the app and Android asks you to confirm the installation. Keep the app installed to retain your imported PCK and saves. Android30 uses the same package and signing certificate as Android29. No new physical-device validation is claimed.

El modo overlay se ve tan nítido como el estirado. Las animaciones se mezclan entre fotogramas (humo al destruir, nombres de fase, sombra del inicio, títulos de Kaiba y Joey) y en Android el modo Display ya no limita a 60 FPS. Una partida nueva empieza sin cartas, como en el original: cada juego da su mazo inicial al abrirlo, y Kaiba y Joey solo endurecen la CPU si de verdad jugaste a los juegos anteriores. En Yugi y Kaiba rendirse ya no cuenta como derrota. En Android, actualiza desde el launcher; no desinstales la app ni borres sus datos.

## v0.1.0-alpha.25

- Demo mode: leaving the title menu idle starts the attract duel in Kaiba (recorded demos) and in Joey, where two CPU players duel live with the original decks, as in the original game. Any key or click returns to the title.
- Duels in all three games were checked against recordings of the original games, value by value (detail panel, dialogs, life points, music and every sound). Most differences found are fixed:
  - Yugi and Kaiba: CPU voices when it activates spells and traps (card-specific lines, Kaiba's reaction to damage), and portraits that no longer pause the duel.
  - Kaiba: phase, draw, attack and life-point timing now follow the original.
  - Sounds: summoning, equipping, changing position and direct attacks use the original sounds and timing; music returns after a summon portrait at the right moment.
  - Dialogs: a quick double click on OK no longer goes through to the field and selects a card by accident.
  - The detail panel keeps the card that asked for a target and no longer flips to a card back while choosing.

Android: update from the launcher; the APK downloads inside the app and Android asks you to confirm the installation. Keep the app installed to retain your imported PCK and saves. Android29 uses the same package and signing certificate as Android28. No new physical-device validation is claimed.

Modo demostración: con el menú del título inactivo, Kaiba reproduce sus demos y Joey juega en directo un duelo CPU contra CPU con los mazos originales; cualquier tecla o clic vuelve al título. Los duelos de los tres juegos se cotejaron valor por valor con grabaciones del original y se corrigieron voces de la CPU, ritmo de Kaiba, sonidos de invocar, equipar y atacar, la música tras los retratos y los dobles clics en los cuadros. En Android, actualiza desde el launcher; no desinstales la app ni borres sus datos.

## v0.1.0-alpha.24

- Joey: the duel now matches recordings of the original game much more closely. Three full recorded duels (normal, spells and traps) replay with every engine command identical to the original.
- Joey: the card-set effect (frame, light and falling sparkles) is now ported method by method from the original.
- Joey: the card detail panel follows played and activated cards, including your own spells; a card shown by the duel wins over the pointer on the same frame.
- Joey: the phase banner no longer delays summons, the end-of-duel banner waits for the shade opening from the centre, and the first portrait reactions use the original turn counter.
- Joey: the hand keeps cards sharp at 800x600 and hover works under a still pointer.

Android: update from the launcher; the APK downloads inside the app and Android asks you to confirm the installation. Keep the app installed to retain your imported PCK and saves. Android28 uses the same package and signing certificate as Android27. No new physical-device validation is claimed.

Joey: el duelo coincide mucho más con grabaciones del original; tres duelos completos (normal, mágicas y trampas) repiten cada comando del motor igual que el original. El efecto de colocar carta está portado del original, el panel de detalle sigue a las cartas jugadas y activadas, el rótulo de fase ya no retrasa las invocaciones y el de fin de duelo espera al sombreado. En Android, actualiza desde el launcher; no desinstales la app ni borres sus datos.
