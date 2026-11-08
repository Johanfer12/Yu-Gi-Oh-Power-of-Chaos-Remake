"""User-facing importer and Android-builder messages in the launcher languages.

The launcher passes its language with --lang (Assets.lang: s, e, g, f, i, j).
Spanish stays the default so command-line use and tests keep their wording.
Internal/technical errors are not listed here: the launcher shows a translated
summary for their stage and keeps the original text as technical details.
"""
from __future__ import annotations

LANGUAGES = ("s", "e", "g", "f", "i", "j")
LANGUAGE = "s"


class UserError(ValueError):
    """An error whose text is already translated for the launcher language."""


def set_language(value: str) -> None:
    global LANGUAGE
    LANGUAGE = value if value in LANGUAGES else "e"


def t(key: str, **values) -> str:
    entry = MESSAGES[key]
    return entry.get(LANGUAGE, entry["e"]).format(**values)


def error(key: str, **values) -> UserError:
    return UserError(t(key, **values))


MESSAGES: dict[str, dict[str, str]] = {
    # --- Game sources -------------------------------------------------------------
    "install_count": {
        "s": "{game}: se esperaba una instalación con Data.dat, Voice.dat, Region.dat y {exe}; encontradas: {count}",
        "e": "{game}: expected one installation with Data.dat, Voice.dat, Region.dat and {exe}; found: {count}",
        "g": "{game}: Erwartet wurde eine Installation mit Data.dat, Voice.dat, Region.dat und {exe}; gefunden: {count}",
        "f": "{game} : une installation avec Data.dat, Voice.dat, Region.dat et {exe} était attendue ; trouvées : {count}",
        "i": "{game}: era prevista un'installazione con Data.dat, Voice.dat, Region.dat e {exe}; trovate: {count}",
        "j": "{game}: Data.dat、Voice.dat、Region.dat、{exe} を含むインストールが 1 つ必要です。見つかった数: {count}",
    },
    "archive_empty": {
        "s": "{game}: {name} está vacío",
        "e": "{game}: {name} is empty",
        "g": "{game}: {name} ist leer",
        "f": "{game} : {name} est vide",
        "i": "{game}: {name} è vuoto",
        "j": "{game}: {name} が空です",
    },
    "archive_damaged": {
        "s": "{game}: {name} está dañado o no es un archivo de Power of Chaos. Usa una instalación o ISO completa.",
        "e": "{game}: {name} is damaged or is not a Power of Chaos file. Use a complete installation or ISO.",
        "g": "{game}: {name} ist beschädigt oder keine Power-of-Chaos-Datei. Verwende eine vollständige Installation oder ISO.",
        "f": "{game} : {name} est endommagé ou n’est pas un fichier de Power of Chaos. Utilise une installation ou une ISO complète.",
        "i": "{game}: {name} è danneggiato o non è un file di Power of Chaos. Usa un'installazione o una ISO completa.",
        "j": "{game}: {name} が壊れているか、Power of Chaos のファイルではありません。完全なインストールまたは ISO を使ってください。",
    },
    "foreign_owner": {
        "s": "{game}: el Data.dat de {folder} es de {found}, no de {title}. Si instalaste varios juegos en la misma carpeta, uno sobrescribió los datos del otro: selecciona la instalación o ISO propia de {title}.",
        "e": "{game}: the Data.dat in {folder} belongs to {found}, not {title}. If several games were installed in the same folder, one overwrote the other's data: select {title}'s own installation or ISO.",
        "g": "{game}: Die Data.dat in {folder} gehört zu {found}, nicht zu {title}. Wenn mehrere Spiele im selben Ordner installiert wurden, hat eines die Daten des anderen überschrieben: Wähle die eigene Installation oder ISO von {title}.",
        "f": "{game} : le Data.dat de {folder} appartient à {found}, pas à {title}. Si plusieurs jeux ont été installés dans le même dossier, l’un a écrasé les données de l’autre : sélectionne l’installation ou l’ISO propre à {title}.",
        "i": "{game}: il Data.dat in {folder} appartiene a {found}, non a {title}. Se hai installato più giochi nella stessa cartella, uno ha sovrascritto i dati dell'altro: seleziona l'installazione o la ISO di {title}.",
        "j": "{game}: {folder} の Data.dat は {title} ではなく {found} のものです。複数のゲームを同じフォルダーにインストールすると、データが上書きされます。{title} 専用のインストールまたは ISO を選んでください。",
    },
    "foreign_unknown": {
        "s": "{game}: el Data.dat de {folder} no corresponde a ninguna versión compatible de {title} (falta {missing}). Puede estar modificado por un mod o pack de cartas: usa una instalación o ISO original sin mods.",
        "e": "{game}: the Data.dat in {folder} does not match any compatible version of {title} ({missing} is missing). It may have been changed by a mod or card pack: use an original, unmodified installation or ISO.",
        "g": "{game}: Die Data.dat in {folder} passt zu keiner kompatiblen Version von {title} ({missing} fehlt). Sie wurde womöglich durch eine Mod oder ein Kartenpaket verändert: Verwende eine originale, unveränderte Installation oder ISO.",
        "f": "{game} : le Data.dat de {folder} ne correspond à aucune version compatible de {title} ({missing} manquant). Il a peut-être été modifié par un mod ou un pack de cartes : utilise une installation ou une ISO d’origine, sans mods.",
        "i": "{game}: il Data.dat in {folder} non corrisponde a nessuna versione compatibile di {title} (manca {missing}). Potrebbe essere stato modificato da una mod o da un pacchetto di carte: usa un'installazione o una ISO originale senza mod.",
        "j": "{game}: {folder} の Data.dat は {title} の対応バージョンと一致しません ({missing} がありません)。MOD やカードパックで変更されている可能性があります。MOD のない元のインストールまたは ISO を使ってください。",
    },
    "exe_incompatible": {
        "s": "{game}: {exe} no es una versión compatible de {title}. Puede estar modificado por un mod: usa el ejecutable de una instalación o ISO original.",
        "e": "{game}: {exe} is not a compatible version of {title}. It may have been changed by a mod: use the executable from an original installation or ISO.",
        "g": "{game}: {exe} ist keine kompatible Version von {title}. Sie wurde womöglich durch eine Mod verändert: Verwende die ausführbare Datei einer originalen Installation oder ISO.",
        "f": "{game} : {exe} n’est pas une version compatible de {title}. Il a peut-être été modifié par un mod : utilise l’exécutable d’une installation ou d’une ISO d’origine.",
        "i": "{game}: {exe} non è una versione compatibile di {title}. Potrebbe essere stato modificato da una mod: usa l'eseguibile di un'installazione o di una ISO originale.",
        "j": "{game}: {exe} は {title} の対応バージョンではありません。MOD で変更されている可能性があります。元のインストールまたは ISO の実行ファイルを使ってください。",
    },
    "no_7zip": {
        "s": "No se encuentra 7-Zip. Instálalo o selecciona una carpeta instalada.",
        "e": "7-Zip was not found. Install it or select an installed folder.",
        "g": "7-Zip wurde nicht gefunden. Installiere es oder wähle einen installierten Ordner.",
        "f": "7-Zip est introuvable. Installe-le ou sélectionne un dossier installé.",
        "i": "7-Zip non trovato. Installalo o seleziona una cartella installata.",
        "j": "7-Zip が見つかりません。インストールするか、インストール済みのフォルダーを選んでください。",
    },
    "select_media": {
        "s": "Selecciona una carpeta instalada o un archivo .iso",
        "e": "Select an installed folder or an .iso file",
        "g": "Wähle einen installierten Ordner oder eine .iso-Datei",
        "f": "Sélectionne un dossier installé ou un fichier .iso",
        "i": "Seleziona una cartella installata o un file .iso",
        "j": "インストール済みのフォルダーか .iso ファイルを選んでください",
    },
    "iso_truncated": {
        "s": "La ISO está incompleta o truncada. Selecciona una imagen completa o una carpeta instalada.",
        "e": "The ISO is incomplete or truncated. Select a complete image or an installed folder.",
        "g": "Die ISO ist unvollständig oder abgeschnitten. Wähle ein vollständiges Abbild oder einen installierten Ordner.",
        "f": "L’ISO est incomplète ou tronquée. Sélectionne une image complète ou un dossier installé.",
        "i": "La ISO è incompleta o troncata. Seleziona un'immagine completa o una cartella installata.",
        "j": "ISO が不完全か途中で切れています。完全なイメージかインストール済みのフォルダーを選んでください。",
    },
    "iso_failed": {
        "s": "7-Zip no pudo extraer la ISO (código {code}). Revisa el detalle técnico.",
        "e": "7-Zip could not extract the ISO (code {code}). See the technical details.",
        "g": "7-Zip konnte die ISO nicht entpacken (Code {code}). Siehe technische Details.",
        "f": "7-Zip n’a pas pu extraire l’ISO (code {code}). Consulte les détails techniques.",
        "i": "7-Zip non è riuscito a estrarre la ISO (codice {code}). Controlla i dettagli tecnici.",
        "j": "7-Zip で ISO を展開できませんでした (コード {code})。技術的な詳細を確認してください。",
    },
    "installer_needs_inno": {
        "s": "El medio contiene un instalador. Instala innoextract en PATH o selecciona el juego ya instalado.",
        "e": "The media contains an installer. Install innoextract on PATH or select the installed game.",
        "g": "Das Medium enthält ein Installationsprogramm. Installiere innoextract im PATH oder wähle das installierte Spiel.",
        "f": "Le support contient un programme d’installation. Installe innoextract dans le PATH ou sélectionne le jeu installé.",
        "i": "Il supporto contiene un programma di installazione. Installa innoextract nel PATH o seleziona il gioco installato.",
        "j": "メディアにインストーラーが含まれています。innoextract を PATH に入れるか、インストール済みのゲームを選んでください。",
    },
    "no_compatible_install": {
        "s": "{game}: no se encontró una instalación compatible en el medio",
        "e": "{game}: no compatible installation was found on the media",
        "g": "{game}: Auf dem Medium wurde keine kompatible Installation gefunden",
        "f": "{game} : aucune installation compatible n’a été trouvée sur le support",
        "i": "{game}: nessuna installazione compatibile trovata sul supporto",
        "j": "{game}: メディアに対応するインストールが見つかりませんでした",
    },
    # --- Library ------------------------------------------------------------------
    "dest_exists_kept": {
        "s": "La carpeta de destino ya existe; se conserva intacta. Selecciona un destino nuevo.",
        "e": "The destination folder already exists and was left untouched. Select a new destination.",
        "g": "Der Zielordner existiert bereits und bleibt unverändert. Wähle ein neues Ziel.",
        "f": "Le dossier de destination existe déjà et reste intact. Sélectionne une nouvelle destination.",
        "i": "La cartella di destinazione esiste già e non è stata toccata. Seleziona una nuova destinazione.",
        "j": "保存先フォルダーは既に存在するため、そのままにしました。新しい保存先を選んでください。",
    },
    "dest_not_library": {
        "s": "El destino no es una biblioteca de recursos compatible",
        "e": "The destination is not a compatible resource library",
        "g": "Das Ziel ist keine kompatible Ressourcenbibliothek",
        "f": "La destination n’est pas une bibliothèque de ressources compatible",
        "i": "La destinazione non è una libreria di risorse compatibile",
        "j": "保存先は対応するリソースライブラリではありません",
    },
    "select_one_game": {
        "s": "Selecciona al menos un juego compatible",
        "e": "Select at least one compatible game",
        "g": "Wähle mindestens ein kompatibles Spiel",
        "f": "Sélectionne au moins un jeu compatible",
        "i": "Seleziona almeno un gioco compatibile",
        "j": "対応するゲームを 1 つ以上選んでください",
    },
    "dest_inside_base": {
        "s": "El destino debe estar fuera de los datos existentes",
        "e": "The destination must be outside the existing data",
        "g": "Das Ziel muss außerhalb der vorhandenen Daten liegen",
        "f": "La destination doit se trouver en dehors des données existantes",
        "i": "La destinazione deve trovarsi fuori dai dati esistenti",
        "j": "保存先は既存のデータの外にする必要があります",
    },
    "game_already": {
        "s": "Ese juego ya está preparado",
        "e": "That game is already prepared",
        "g": "Dieses Spiel ist bereits vorbereitet",
        "f": "Ce jeu est déjà prêt",
        "i": "Quel gioco è già pronto",
        "j": "そのゲームは既に準備済みです",
    },
    "dest_exists": {
        "s": "El destino ya existe",
        "e": "The destination already exists",
        "g": "Das Ziel existiert bereits",
        "f": "La destination existe déjà",
        "i": "La destinazione esiste già",
        "j": "保存先は既に存在します",
    },
    # --- Voices -------------------------------------------------------------------
    "prepare_before_voices": {
        "s": "{game}: prepara el juego antes de añadir voces",
        "e": "{game}: prepare the game before adding voices",
        "g": "{game}: Bereite das Spiel vor, bevor du Stimmen hinzufügst",
        "f": "{game} : prépare le jeu avant d’ajouter des voix",
        "i": "{game}: prepara il gioco prima di aggiungere le voci",
        "j": "{game}: 音声を追加する前にゲームを準備してください",
    },
    "unknown_voice_game": {
        "s": "Juego no reconocido para voces: {game}",
        "e": "Unrecognized game for voices: {game}",
        "g": "Unbekanntes Spiel für Stimmen: {game}",
        "f": "Jeu non reconnu pour les voix : {game}",
        "i": "Gioco non riconosciuto per le voci: {game}",
        "j": "音声の対象として認識できないゲーム: {game}",
    },
    "voice_usage": {
        "s": "Usa --voice juego=ruta/Voice.dat",
        "e": "Use --voice game=path/Voice.dat",
        "g": "Verwende --voice spiel=pfad/Voice.dat",
        "f": "Utilise --voice jeu=chemin/Voice.dat",
        "i": "Usa --voice gioco=percorso/Voice.dat",
        "j": "--voice ゲーム=パス/Voice.dat の形式で指定してください",
    },
    "voice_path_bad": {
        "s": "{game}: ruta de voces no compatible: {name}",
        "e": "{game}: unsupported voice path: {name}",
        "g": "{game}: nicht unterstützter Stimmenpfad: {name}",
        "f": "{game} : chemin de voix non pris en charge : {name}",
        "i": "{game}: percorso delle voci non supportato: {name}",
        "j": "{game}: 対応していない音声パス: {name}",
    },
    "voice_duplicate": {
        "s": "{game}: dos paquetes distintos para el mismo idioma {language}; no se sobrescriben",
        "e": "{game}: two different packs for the same language {language}; neither is overwritten",
        "g": "{game}: zwei verschiedene Pakete für dieselbe Sprache {language}; keines wird überschrieben",
        "f": "{game} : deux packs différents pour la même langue {language} ; aucun n’est écrasé",
        "i": "{game}: due pacchetti diversi per la stessa lingua {language}; nessuno viene sovrascritto",
        "j": "{game}: 同じ言語 {language} に異なるパックが 2 つあります。上書きはしません",
    },
    "voice_empty": {
        "s": "{game}: el paquete de voces no contiene WAV compatibles",
        "e": "{game}: the voice pack contains no compatible WAV files",
        "g": "{game}: Das Stimmenpaket enthält keine kompatiblen WAV-Dateien",
        "f": "{game} : le pack de voix ne contient aucun fichier WAV compatible",
        "i": "{game}: il pacchetto di voci non contiene file WAV compatibili",
        "j": "{game}: 音声パックに対応する WAV がありません",
    },
    # --- Progress -----------------------------------------------------------------
    "validating": {
        "s": "Validando {game}…", "e": "Checking {game}…", "g": "{game} wird geprüft…",
        "f": "Vérification de {game}…", "i": "Verifica di {game}…", "j": "{game} を確認しています…",
    },
    "import_done": {
        "s": "Importación completa.", "e": "Import complete.", "g": "Import abgeschlossen.",
        "f": "Importation terminée.", "i": "Importazione completata.", "j": "インポートが完了しました。",
    },
    "cli_failed": {
        "s": "No se pudo importar: {error}", "e": "Could not import: {error}", "g": "Import fehlgeschlagen: {error}",
        "f": "Échec de l’importation : {error}", "i": "Importazione non riuscita: {error}", "j": "インポートできませんでした: {error}",
    },
    # --- Summary for internal errors, by stage (original text goes to details) --------
    "stage.iso": {
        "s": "No se pudo leer la ISO o el medio seleccionado. Revisa el detalle técnico.",
        "e": "The selected ISO or media could not be read. See the technical details.",
        "g": "Die gewählte ISO bzw. das Medium konnte nicht gelesen werden. Siehe technische Details.",
        "f": "Impossible de lire l’ISO ou le support sélectionné. Consulte les détails techniques.",
        "i": "Impossibile leggere la ISO o il supporto selezionato. Controlla i dettagli tecnici.",
        "j": "選んだ ISO またはメディアを読み込めませんでした。技術的な詳細を確認してください。",
    },
    "stage.installation": {
        "s": "Los archivos del juego no son compatibles o están dañados. Revisa el detalle técnico.",
        "e": "The game files are incompatible or damaged. See the technical details.",
        "g": "Die Spieldateien sind nicht kompatibel oder beschädigt. Siehe technische Details.",
        "f": "Les fichiers du jeu sont incompatibles ou endommagés. Consulte les détails techniques.",
        "i": "I file del gioco non sono compatibili o sono danneggiati. Controlla i dettagli tecnici.",
        "j": "ゲームファイルが対応していないか、壊れています。技術的な詳細を確認してください。",
    },
    "stage.write": {
        "s": "No se pudieron escribir los archivos. Comprueba el espacio libre y los permisos de la carpeta.",
        "e": "The files could not be written. Check free space and folder permissions.",
        "g": "Die Dateien konnten nicht geschrieben werden. Prüfe den freien Speicher und die Ordnerberechtigungen.",
        "f": "Impossible d’écrire les fichiers. Vérifie l’espace libre et les autorisations du dossier.",
        "i": "Impossibile scrivere i file. Controlla lo spazio libero e i permessi della cartella.",
        "j": "ファイルを書き込めませんでした。空き容量とフォルダーの権限を確認してください。",
    },
    "stage.conversion": {
        "s": "No se pudieron convertir los recursos del juego. Revisa el detalle técnico.",
        "e": "The game resources could not be converted. See the technical details.",
        "g": "Die Spielressourcen konnten nicht konvertiert werden. Siehe technische Details.",
        "f": "Impossible de convertir les ressources du jeu. Consulte les détails techniques.",
        "i": "Impossibile convertire le risorse del gioco. Controlla i dettagli tecnici.",
        "j": "ゲームのリソースを変換できませんでした。技術的な詳細を確認してください。",
    },
    "stage.audio": {
        "s": "No se pudo convertir el audio del juego. Revisa el detalle técnico.",
        "e": "The game audio could not be converted. See the technical details.",
        "g": "Der Spielton konnte nicht konvertiert werden. Siehe technische Details.",
        "f": "Impossible de convertir l’audio du jeu. Consulte les détails techniques.",
        "i": "Impossibile convertire l'audio del gioco. Controlla i dettagli tecnici.",
        "j": "ゲームの音声を変換できませんでした。技術的な詳細を確認してください。",
    },
    "stage.compact": {
        "s": "No se pudieron comprimir los recursos convertidos. Revisa el detalle técnico.",
        "e": "The converted resources could not be compressed. See the technical details.",
        "g": "Die konvertierten Ressourcen konnten nicht komprimiert werden. Siehe technische Details.",
        "f": "Impossible de compresser les ressources converties. Consulte les détails techniques.",
        "i": "Impossibile comprimere le risorse convertite. Controlla i dettagli tecnici.",
        "j": "変換したリソースを圧縮できませんでした。技術的な詳細を確認してください。",
    },
    "stage.voices": {
        "s": "No se pudieron añadir las voces adicionales. Revisa el detalle técnico.",
        "e": "The additional voices could not be added. See the technical details.",
        "g": "Die zusätzlichen Stimmen konnten nicht hinzugefügt werden. Siehe technische Details.",
        "f": "Impossible d’ajouter les voix supplémentaires. Consulte les détails techniques.",
        "i": "Impossibile aggiungere le voci aggiuntive. Controlla i dettagli tecnici.",
        "j": "追加音声を追加できませんでした。技術的な詳細を確認してください。",
    },
    "stage.setup": {
        "s": "No se pudo completar el proceso. Revisa el detalle técnico.",
        "e": "The process could not be completed. See the technical details.",
        "g": "Der Vorgang konnte nicht abgeschlossen werden. Siehe technische Details.",
        "f": "Le processus n’a pas pu aboutir. Consulte les détails techniques.",
        "i": "Impossibile completare il processo. Controlla i dettagli tecnici.",
        "j": "処理を完了できませんでした。技術的な詳細を確認してください。",
    },
    # --- Android resources and APK -----------------------------------------------------
    "android_tool_missing": {
        "s": "Falta una herramienta Android: {path}", "e": "An Android tool is missing: {path}",
        "g": "Ein Android-Werkzeug fehlt: {path}", "f": "Un outil Android est manquant : {path}",
        "i": "Manca uno strumento Android: {path}", "j": "Android ツールがありません: {path}",
    },
    "android_file_missing": {
        "s": "Falta {name}: {path}", "e": "Missing {name}: {path}", "g": "{name} fehlt: {path}",
        "f": "{name} manquant : {path}", "i": "Manca {name}: {path}", "j": "{name} がありません: {path}",
    },
    "android_reference_missing": {
        "s": "Falta el APK de referencia: {path}", "e": "The reference APK is missing: {path}",
        "g": "Die Referenz-APK fehlt: {path}", "f": "L’APK de référence est manquant : {path}",
        "i": "Manca l'APK di riferimento: {path}", "j": "参照用 APK がありません: {path}",
    },
    "android_need_game": {
        "s": "Selecciona un ISO o prepara un juego antes de crear los recursos",
        "e": "Select an ISO or prepare a game before creating the resources",
        "g": "Wähle eine ISO oder bereite ein Spiel vor, bevor du die Ressourcen erstellst",
        "f": "Sélectionne une ISO ou prépare un jeu avant de créer les ressources",
        "i": "Seleziona una ISO o prepara un gioco prima di creare le risorse",
        "j": "リソースを作成する前に ISO を選ぶか、ゲームを準備してください",
    },
    "android_no_report": {
        "s": "La compilación no generó un único informe de validación",
        "e": "The build did not produce exactly one validation report",
        "g": "Der Build hat nicht genau einen Prüfbericht erzeugt",
        "f": "La compilation n’a pas produit un rapport de validation unique",
        "i": "La compilazione non ha generato un unico rapporto di convalida",
        "j": "ビルドで検証レポートが 1 つだけ生成されませんでした",
    },
    "android_pack_sha": {
        "s": "El paquete privado de recursos no supera la validación SHA-256",
        "e": "The private resource pack failed SHA-256 validation",
        "g": "Das private Ressourcenpaket hat die SHA-256-Prüfung nicht bestanden",
        "f": "Le pack de ressources privé n’a pas passé la validation SHA-256",
        "i": "Il pacchetto privato di risorse non supera la verifica SHA-256",
        "j": "非公開リソースパックが SHA-256 の検証に失敗しました",
    },
    "android_output_exists": {
        "s": "Ya existe una salida Android: {path}", "e": "An Android output already exists: {path}",
        "g": "Eine Android-Ausgabe existiert bereits: {path}", "f": "Une sortie Android existe déjà : {path}",
        "i": "Esiste già un output Android: {path}", "j": "Android の出力が既に存在します: {path}",
    },
    "android_preparing": {
        "s": "Preparando tus recursos privados para Android…", "e": "Preparing your private resources for Android…",
        "g": "Deine privaten Ressourcen für Android werden vorbereitet…", "f": "Préparation de tes ressources privées pour Android…",
        "i": "Preparazione delle tue risorse private per Android…", "j": "Android 用の非公開リソースを準備しています…",
    },
    "android_compiling": {
        "s": "Compilando con los controles de la copia Android…", "e": "Building with the Android copy's controls…",
        "g": "Build mit den Steuerelementen der Android-Kopie…", "f": "Compilation avec les commandes de la copie Android…",
        "i": "Compilazione con i controlli della copia Android…", "j": "Android 版の操作系でビルドしています…",
    },
    "android_pack_ready": {
        "s": "Recursos privados: {path}\nInstala el APK público y selecciona este archivo .pck una sola vez al abrirlo. Las actualizaciones conservarán tus recursos y partidas.",
        "e": "Private resources: {path}\nInstall the public APK and select this .pck file once when you open it. Updates keep your resources and saves.",
        "g": "Private Ressourcen: {path}\nInstalliere die öffentliche APK und wähle diese .pck-Datei beim ersten Öffnen einmal aus. Updates behalten deine Ressourcen und Spielstände.",
        "f": "Ressources privées : {path}\nInstalle l’APK public et sélectionne ce fichier .pck une seule fois à l’ouverture. Les mises à jour conservent tes ressources et sauvegardes.",
        "i": "Risorse private: {path}\nInstalla l'APK pubblico e seleziona questo file .pck una sola volta all'apertura. Gli aggiornamenti conservano risorse e salvataggi.",
        "j": "非公開リソース: {path}\n公開 APK をインストールし、初回起動時にこの .pck ファイルを 1 回だけ選んでください。アップデート後もリソースとセーブデータは保持されます。",
    },
    "apk_created": {
        "s": "APK creado: {path}", "e": "APK created: {path}", "g": "APK erstellt: {path}",
        "f": "APK créé : {path}", "i": "APK creato: {path}", "j": "APK を作成しました: {path}",
    },
    "download_sha": {
        "s": "La descarga no supera SHA-256: {url}", "e": "The download failed SHA-256 verification: {url}",
        "g": "Der Download hat die SHA-256-Prüfung nicht bestanden: {url}", "f": "Le téléchargement n’a pas passé la vérification SHA-256 : {url}",
        "i": "Il download non supera la verifica SHA-256: {url}", "j": "ダウンロードが SHA-256 の検証に失敗しました: {url}",
    },
    "kit_unsafe_path": {
        "s": "Ruta insegura en el kit Android: {name}", "e": "Unsafe path in the Android kit: {name}",
        "g": "Unsicherer Pfad im Android-Kit: {name}", "f": "Chemin non sûr dans le kit Android : {name}",
        "i": "Percorso non sicuro nel kit Android: {name}", "j": "Android キット内の安全でないパス: {name}",
    },
    "kit_outside": {
        "s": "Ruta fuera del kit Android", "e": "Path outside the Android kit", "g": "Pfad außerhalb des Android-Kits",
        "f": "Chemin en dehors du kit Android", "i": "Percorso fuori dal kit Android", "j": "Android キットの外のパスです",
    },
    "android_source_invalid": {
        "s": "Fuente Android no válida: {name}", "e": "Invalid Android source: {name}", "g": "Ungültige Android-Quelle: {name}",
        "f": "Source Android non valide : {name}", "i": "Sorgente Android non valida: {name}", "j": "無効な Android ソース: {name}",
    },
    "no_public_apk": {
        "s": "Esta compilación del launcher no incluye el APK público Android",
        "e": "This launcher build does not include the public Android APK",
        "g": "Dieser Launcher-Build enthält die öffentliche Android-APK nicht",
        "f": "Cette version du lanceur n’inclut pas l’APK Android public",
        "i": "Questa build del launcher non include l'APK Android pubblico",
        "j": "このランチャーのビルドには公開 Android APK が含まれていません",
    },
    "no_audited_sha": {
        "s": "Esta compilación aún no incluye el SHA-256 auditado del APK público Android",
        "e": "This build does not yet include the audited SHA-256 of the public Android APK",
        "g": "Dieser Build enthält noch nicht den geprüften SHA-256 der öffentlichen Android-APK",
        "f": "Cette version n’inclut pas encore le SHA-256 vérifié de l’APK Android public",
        "i": "Questa build non include ancora lo SHA-256 verificato dell'APK Android pubblico",
        "j": "このビルドには公開 Android APK の監査済み SHA-256 がまだ含まれていません",
    },
    "apk_has_data": {
        "s": "El APK público Android no debe incluir datos originales",
        "e": "The public Android APK must not include original game data",
        "g": "Die öffentliche Android-APK darf keine Originaldaten enthalten",
        "f": "L’APK Android public ne doit pas inclure de données d’origine",
        "i": "L'APK Android pubblico non deve includere dati originali",
        "j": "公開 Android APK に元のゲームデータを含めてはいけません",
    },
    "sources_mismatch": {
        "s": "Las fuentes Android no coinciden con la revisión auditada",
        "e": "The Android sources do not match the audited revision",
        "g": "Die Android-Quellen stimmen nicht mit der geprüften Revision überein",
        "f": "Les sources Android ne correspondent pas à la révision vérifiée",
        "i": "Le sorgenti Android non corrispondono alla revisione verificata",
        "j": "Android ソースが監査済みのリビジョンと一致しません",
    },
    "no_godot": {
        "s": "El archivo oficial no contiene Godot", "e": "The official archive does not contain Godot",
        "g": "Das offizielle Archiv enthält Godot nicht", "f": "L’archive officielle ne contient pas Godot",
        "i": "L'archivio ufficiale non contiene Godot", "j": "公式アーカイブに Godot が含まれていません",
    },
    "missing_sources": {
        "s": "Faltan las fuentes Android incluidas en esta compilación del launcher",
        "e": "The Android sources included in this launcher build are missing",
        "g": "Die in diesem Launcher-Build enthaltenen Android-Quellen fehlen",
        "f": "Les sources Android incluses dans cette version du lanceur sont manquantes",
        "i": "Mancano le sorgenti Android incluse in questa build del launcher",
        "j": "このランチャーのビルドに含まれる Android ソースがありません",
    },
    "sdk_license": {
        "s": "Acepta la licencia del SDK Android desde Crear APK en el launcher: {url}",
        "e": "Accept the Android SDK license from Create APK in the launcher: {url}",
        "g": "Akzeptiere die Android-SDK-Lizenz über „APK erstellen“ im Launcher: {url}",
        "f": "Accepte la licence du SDK Android depuis Créer l’APK dans le lanceur : {url}",
        "i": "Accetta la licenza dell'SDK Android da Crea APK nel launcher: {url}",
        "j": "ランチャーの「APK を作成」から Android SDK のライセンスに同意してください: {url}",
    },
    "missing_tool_archive": {
        "s": "El archivo oficial no contiene las herramientas esperadas: {name}",
        "e": "The official archive does not contain the expected tools: {name}",
        "g": "Das offizielle Archiv enthält die erwarteten Werkzeuge nicht: {name}",
        "f": "L’archive officielle ne contient pas les outils attendus : {name}",
        "i": "L'archivio ufficiale non contiene gli strumenti previsti: {name}",
        "j": "公式アーカイブに必要なツールが含まれていません: {name}",
    },
    "signing_missing": {
        "s": "Falta tu firma Android anterior. Restaura PoC Data/android/signing de tu respaldo para actualizar tus APK.",
        "e": "Your previous Android signing key is missing. Restore PoC Data/android/signing from your backup to update your APKs.",
        "g": "Dein bisheriger Android-Signaturschlüssel fehlt. Stelle PoC Data/android/signing aus deiner Sicherung wieder her, um deine APKs zu aktualisieren.",
        "f": "Ta clé de signature Android précédente est manquante. Restaure PoC Data/android/signing depuis ta sauvegarde pour mettre à jour tes APK.",
        "i": "Manca la tua firma Android precedente. Ripristina PoC Data/android/signing dal tuo backup per aggiornare i tuoi APK.",
        "j": "以前の Android 署名鍵がありません。APK を更新するには、バックアップから PoC Data/android/signing を復元してください。",
    },
    "signing_changed": {
        "s": "La firma Android cambió. Restaura tu clave anterior de PoC Data/android/signing.",
        "e": "The Android signing key changed. Restore your previous key in PoC Data/android/signing.",
        "g": "Der Android-Signaturschlüssel hat sich geändert. Stelle deinen bisherigen Schlüssel in PoC Data/android/signing wieder her.",
        "f": "La clé de signature Android a changé. Restaure ta clé précédente dans PoC Data/android/signing.",
        "i": "La firma Android è cambiata. Ripristina la tua chiave precedente in PoC Data/android/signing.",
        "j": "Android の署名鍵が変わりました。PoC Data/android/signing の以前の鍵を復元してください。",
    },
    "st_packer": {
        "s": "Android: preparando el empaquetador de recursos…", "e": "Android: preparing the resource packer…",
        "g": "Android: Ressourcen-Packer wird vorbereitet…", "f": "Android : préparation de l’empaqueteur de ressources…",
        "i": "Android: preparazione del pacchettizzatore di risorse…", "j": "Android: リソースのパッケージツールを準備しています…",
    },
    "st_format": {
        "s": "Android: preparando el formato privado de recursos…", "e": "Android: preparing the private resource format…",
        "g": "Android: privates Ressourcenformat wird vorbereitet…", "f": "Android : préparation du format de ressources privé…",
        "i": "Android: preparazione del formato privato delle risorse…", "j": "Android: 非公開リソース形式を準備しています…",
    },
    "st_resources": {
        "s": "Android: preparando tus recursos privados…", "e": "Android: preparing your private resources…",
        "g": "Android: Deine privaten Ressourcen werden vorbereitet…", "f": "Android : préparation de tes ressources privées…",
        "i": "Android: preparazione delle tue risorse private…", "j": "Android: 非公開リソースを準備しています…",
    },
    "st_engine": {
        "s": "Android: preparando el motor táctil incluido…", "e": "Android: preparing the included touch engine…",
        "g": "Android: Mitgelieferte Touch-Engine wird vorbereitet…", "f": "Android : préparation du moteur tactile inclus…",
        "i": "Android: preparazione del motore touch incluso…", "j": "Android: 付属のタッチ対応エンジンを準備しています…",
    },
    "st_signing": {
        "s": "Android: creando tu firma local…", "e": "Android: creating your local signing key…",
        "g": "Android: Dein lokaler Signaturschlüssel wird erstellt…", "f": "Android : création de ta clé de signature locale…",
        "i": "Android: creazione della tua firma locale…", "j": "Android: ローカル署名鍵を作成しています…",
    },
    "st_ready": {
        "s": "Android: herramientas listas; preparando tus juegos…", "e": "Android: tools ready; preparing your games…",
        "g": "Android: Werkzeuge bereit; deine Spiele werden vorbereitet…", "f": "Android : outils prêts ; préparation de tes jeux…",
        "i": "Android: strumenti pronti; preparazione dei tuoi giochi…", "j": "Android: ツールの準備完了。ゲームを準備しています…",
    },
}
