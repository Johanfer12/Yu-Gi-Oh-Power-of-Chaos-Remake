extends RefCounted
## Import, Android-pack and import-error texts in the launcher languages (Assets.LANGUAGES).
## Python importer messages live in tools/pocx/messages.py; the launcher passes --lang.

const TEXT := {
	"apk_tooltip": {
		"s": "Crea tus recursos privados (.pck) para importarlos una vez en el APK público.",
		"e": "Creates your private content (.pck) to import once into the public APK.",
		"g": "Erstellt deine privaten Ressourcen (.pck), die du einmal in die öffentliche APK importierst.",
		"f": "Crée tes ressources privées (.pck) à importer une seule fois dans l’APK public.",
		"i": "Crea le tue risorse private (.pck) da importare una sola volta nell'APK pubblico.",
		"j": "公開 APK に 1 回だけ取り込む非公開リソース (.pck) を作成します。"},
	"download_tooltip": {
		"s": "Descarga el APK público de esta versión desde GitHub.",
		"e": "Downloads this version's public APK from GitHub.",
		"g": "Lädt die öffentliche APK dieser Version von GitHub herunter.",
		"f": "Télécharge l’APK public de cette version depuis GitHub.",
		"i": "Scarica da GitHub l'APK pubblico di questa versione.",
		"j": "このバージョンの公開 APK を GitHub からダウンロードします。"},
	"apk_preparing": {
		"s": "Preparando tus recursos Android (.pck)… Puede tardar varios minutos.",
		"e": "Preparing your Android content (.pck)… This may take several minutes.",
		"g": "Deine Android-Ressourcen (.pck) werden vorbereitet… Das kann einige Minuten dauern.",
		"f": "Préparation de tes ressources Android (.pck)… Cela peut prendre plusieurs minutes.",
		"i": "Preparazione delle tue risorse Android (.pck)… Potrebbe richiedere alcuni minuti.",
		"j": "Android 用リソース (.pck) を準備しています… 数分かかることがあります。"},
	"apk_ready": {
		"s": "Recursos listos en PoC Data/android/pck. Instala el APK público e importa el archivo .pck.",
		"e": "Content ready in PoC Data/android/pck. Install the public APK and import the .pck file.",
		"g": "Ressourcen bereit in PoC Data/android/pck. Installiere die öffentliche APK und importiere die .pck-Datei.",
		"f": "Ressources prêtes dans PoC Data/android/pck. Installe l’APK public et importe le fichier .pck.",
		"i": "Risorse pronte in PoC Data/android/pck. Installa l'APK pubblico e importa il file .pck.",
		"j": "PoC Data/android/pck にリソースを用意しました。公開 APK をインストールし、.pck ファイルを取り込んでください。"},
	"settings_failed": {
		"s": "Los recursos se prepararon, pero no se pudieron guardar los ajustes: ",
		"e": "Resources were prepared, but settings could not be saved: ",
		"g": "Die Ressourcen wurden vorbereitet, aber die Einstellungen konnten nicht gespeichert werden: ",
		"f": "Les ressources sont prêtes, mais les paramètres n’ont pas pu être enregistrés : ",
		"i": "Le risorse sono pronte, ma non è stato possibile salvare le impostazioni: ",
		"j": "リソースは準備できましたが、設定を保存できませんでした: "},
	"title_apk_failed": {
		"s": "No se pudieron crear los recursos Android", "e": "Android content build failed",
		"g": "Android-Ressourcen konnten nicht erstellt werden", "f": "Échec de la création des ressources Android",
		"i": "Impossibile creare le risorse Android", "j": "Android 用リソースを作成できませんでした"},
	"title_import_failed": {
		"s": "No se pudo importar", "e": "Import failed", "g": "Import fehlgeschlagen",
		"f": "Échec de l’importation", "i": "Importazione non riuscita", "j": "インポートできませんでした"},
	"process_failed": {
		"s": "El proceso no se pudo iniciar o terminó con código %s.",
		"e": "The process could not start or exited with code %s.",
		"g": "Der Vorgang konnte nicht starten oder endete mit Code %s.",
		"f": "Le processus n’a pas pu démarrer ou s’est terminé avec le code %s.",
		"i": "Il processo non è riuscito ad avviarsi o è terminato con codice %s.",
		"j": "処理を開始できなかったか、コード %s で終了しました。"},
	"source_label": {
		"s": "Archivo o carpeta: ", "e": "File or folder: ", "g": "Datei oder Ordner: ",
		"f": "Fichier ou dossier : ", "i": "File o cartella: ", "j": "ファイルまたはフォルダー: "},
	"details_label": {
		"s": "Detalle técnico:", "e": "Technical details:", "g": "Technische Details:",
		"f": "Détails techniques :", "i": "Dettagli tecnici:", "j": "技術的な詳細:"},
	"log_label": {
		"s": "Registro completo: ", "e": "Full log: ", "g": "Vollständiges Protokoll: ",
		"f": "Journal complet : ", "i": "Registro completo: ", "j": "完全なログ: "},
	"log_not_saved": {
		"s": "No se pudo guardar el registro. Puedes copiar estos detalles.",
		"e": "Could not save the log. You can copy these details.",
		"g": "Das Protokoll konnte nicht gespeichert werden. Du kannst diese Details kopieren.",
		"f": "Impossible d’enregistrer le journal. Tu peux copier ces détails.",
		"i": "Impossibile salvare il registro. Puoi copiare questi dettagli.",
		"j": "ログを保存できませんでした。この詳細をコピーできます。"},
	"close": {"s": "Cerrar", "e": "Close", "g": "Schließen", "f": "Fermer", "i": "Chiudi", "j": "閉じる"},
	"copy_details": {"s": "Copiar detalles", "e": "Copy details", "g": "Details kopieren", "f": "Copier les détails", "i": "Copia dettagli", "j": "詳細をコピー"},
	"open_log": {"s": "Abrir registro", "e": "Open log", "g": "Protokoll öffnen", "f": "Ouvrir le journal", "i": "Apri registro", "j": "ログを開く"},
	"view_error": {"s": "Ver error", "e": "View error", "g": "Fehler anzeigen", "f": "Voir l’erreur", "i": "Vedi errore", "j": "エラーを表示"},
	"stage_iso": {"s": "ISO / extracción", "e": "ISO / extraction", "g": "ISO / Entpacken", "f": "ISO / extraction", "i": "ISO / estrazione", "j": "ISO / 展開"},
	"stage_installation": {"s": "Archivos del juego", "e": "Game files", "g": "Spieldateien", "f": "Fichiers du jeu", "i": "File del gioco", "j": "ゲームファイル"},
	"stage_write": {"s": "Escritura de archivos", "e": "Writing files", "g": "Dateien schreiben", "f": "Écriture des fichiers", "i": "Scrittura dei file", "j": "ファイルの書き込み"},
	"stage_conversion": {"s": "Conversión", "e": "Conversion", "g": "Konvertierung", "f": "Conversion", "i": "Conversione", "j": "変換"},
	"stage_audio": {"s": "Conversión de audio", "e": "Audio conversion", "g": "Audiokonvertierung", "f": "Conversion audio", "i": "Conversione audio", "j": "音声の変換"},
	"stage_compact": {"s": "Compresión", "e": "Compression", "g": "Komprimierung", "f": "Compression", "i": "Compressione", "j": "圧縮"},
	"stage_voices": {"s": "Voces adicionales", "e": "Additional voices", "g": "Zusätzliche Stimmen", "f": "Voix supplémentaires", "i": "Voci aggiuntive", "j": "追加音声"},
	"stage_setup": {"s": "Preparación", "e": "Setup", "g": "Vorbereitung", "f": "Préparation", "i": "Preparazione", "j": "準備"},
	"stage_process": {"s": "Proceso", "e": "Process", "g": "Vorgang", "f": "Processus", "i": "Processo", "j": "処理"},
	# Android pack import screen.
	"pack_title": {"s": "Añade tus juegos", "e": "Add your games", "g": "Füge deine Spiele hinzu", "f": "Ajoute tes jeux", "i": "Aggiungi i tuoi giochi", "j": "ゲームを追加"},
	"pack_instructions": {
		"s": "Esta aplicación necesita los recursos de tus juegos.\n\nEn el launcher de PC, crea el paquete de recursos para Android y copia el archivo .pck a este dispositivo. Después, selecciónalo aquí.\n\nSólo hace falta importarlo una vez. Tus partidas y recursos se conservan al actualizar la aplicación.",
		"e": "This app needs the resources from your games.\n\nUse the PC launcher to create the Android resource pack and copy the .pck file to this device. Then select it here.\n\nImport it once. App updates keep your game resources and saved games.",
		"g": "Diese App braucht die Ressourcen deiner Spiele.\n\nErstelle im PC-Launcher das Ressourcenpaket für Android und kopiere die .pck-Datei auf dieses Gerät. Wähle sie dann hier aus.\n\nDu musst sie nur einmal importieren. App-Updates behalten deine Ressourcen und Spielstände.",
		"f": "Cette application a besoin des ressources de tes jeux.\n\nDans le lanceur PC, crée le pack de ressources pour Android et copie le fichier .pck sur cet appareil. Ensuite, sélectionne-le ici.\n\nUne seule importation suffit. Les mises à jour de l’application conservent tes ressources et sauvegardes.",
		"i": "Questa app ha bisogno delle risorse dei tuoi giochi.\n\nNel launcher per PC, crea il pacchetto di risorse per Android e copia il file .pck su questo dispositivo. Poi selezionalo qui.\n\nBasta importarlo una volta. Gli aggiornamenti dell'app conservano risorse e salvataggi.",
		"j": "このアプリにはゲームのリソースが必要です。\n\nPC のランチャーで Android 用リソースパックを作成し、.pck ファイルをこの端末にコピーしてから、ここで選んでください。\n\n取り込みは 1 回だけで済みます。アプリを更新してもリソースとセーブデータは保持されます。"},
	"pack_choose": {"s": "Seleccionar paquete .pck", "e": "Select .pck resource pack", "g": ".pck-Ressourcenpaket auswählen", "f": "Sélectionner le pack .pck", "i": "Seleziona il pacchetto .pck", "j": ".pck リソースパックを選択"},
	"pack_filter": {"s": "Recursos del juego", "e": "Game resources", "g": "Spielressourcen", "f": "Ressources du jeu", "i": "Risorse del gioco", "j": "ゲームリソース"},
	"pack_cancelled": {
		"s": "Selección cancelada. Puedes intentarlo cuando quieras.", "e": "Selection cancelled. You can try again whenever you want.",
		"g": "Auswahl abgebrochen. Du kannst es jederzeit erneut versuchen.", "f": "Sélection annulée. Tu peux réessayer quand tu veux.",
		"i": "Selezione annullata. Puoi riprovare quando vuoi.", "j": "選択をキャンセルしました。いつでもやり直せます。"},
	"pack_copying": {
		"s": "Copiando y comprobando tus recursos…", "e": "Copying and checking your resources…",
		"g": "Deine Ressourcen werden kopiert und geprüft…", "f": "Copie et vérification de tes ressources…",
		"i": "Copia e verifica delle tue risorse…", "j": "リソースをコピーして確認しています…"},
	"pack_ready": {"s": "Recursos listos.", "e": "Resources ready.", "g": "Ressourcen bereit.", "f": "Ressources prêtes.", "i": "Risorse pronte.", "j": "リソースの準備ができました。"},
	"pack_engine": {
		"s": "El paquete no incluye los datos del motor de duelo de %s. Vuelve a crear el .pck con la versión actual del launcher de PC, importando ese juego desde su ISO o instalación original.",
		"e": "The pack is missing the %s duel engine data. Create the .pck again with the current PC launcher, importing that game from its original ISO or installation.",
		"g": "Dem Paket fehlen die Duell-Engine-Daten von %s. Erstelle die .pck erneut mit dem aktuellen PC-Launcher und importiere das Spiel aus seiner originalen ISO oder Installation.",
		"f": "Le pack ne contient pas les données du moteur de duel de %s. Recrée le .pck avec la version actuelle du lanceur PC, en important ce jeu depuis son ISO ou son installation d’origine.",
		"i": "Il pacchetto non include i dati del motore di duello di %s. Crea di nuovo il .pck con la versione attuale del launcher per PC, importando il gioco dalla sua ISO o installazione originale.",
		"j": "パックに %s のデュエルエンジンのデータがありません。現在の PC ランチャーで、そのゲームを元の ISO またはインストールから取り込み、.pck を作り直してください。"},
	"pack_invalid": {
		"s": "Ese archivo no es un paquete de recursos válido. Crea uno nuevo desde el launcher de PC.",
		"e": "That file is not a valid game resource pack. Create a new one with the PC launcher.",
		"g": "Diese Datei ist kein gültiges Ressourcenpaket. Erstelle ein neues mit dem PC-Launcher.",
		"f": "Ce fichier n’est pas un pack de ressources valide. Crée-en un nouveau avec le lanceur PC.",
		"i": "Questo file non è un pacchetto di risorse valido. Creane uno nuovo con il launcher per PC.",
		"j": "このファイルは有効なリソースパックではありません。PC のランチャーで新しく作成してください。"},
	"pack_installed": {
		"s": "Ya hay un paquete de recursos guardado. Cierra y abre la aplicación para cargarlo.",
		"e": "A resource pack is already saved. Close and reopen the app to load it.",
		"g": "Ein Ressourcenpaket ist bereits gespeichert. Schließe die App und öffne sie erneut, um es zu laden.",
		"f": "Un pack de ressources est déjà enregistré. Ferme puis rouvre l’application pour le charger.",
		"i": "C'è già un pacchetto di risorse salvato. Chiudi e riapri l'app per caricarlo.",
		"j": "リソースパックは既に保存されています。読み込むにはアプリを閉じて開き直してください。"},
	"pack_copy_failed": {
		"s": "No se pudo copiar el archivo. Comprueba el espacio disponible y vuelve a seleccionarlo.",
		"e": "The file could not be copied. Check available storage and select it again.",
		"g": "Die Datei konnte nicht kopiert werden. Prüfe den freien Speicher und wähle sie erneut aus.",
		"f": "Impossible de copier le fichier. Vérifie l’espace disponible et sélectionne-le à nouveau.",
		"i": "Impossibile copiare il file. Controlla lo spazio disponibile e selezionalo di nuovo.",
		"j": "ファイルをコピーできませんでした。空き容量を確認して、もう一度選んでください。"},
}

## Android has no launcher selection yet when the pack is imported: follow the device locale.
const LOCALES := {"es": "s", "en": "e", "de": "g", "fr": "f", "it": "i", "ja": "j"}


static func text(key: String, lang: String) -> String:
	var entry: Dictionary = TEXT[key]
	return str(entry.get(lang, entry["e"]))


static func device_language() -> String:
	return str(LOCALES.get(OS.get_locale_language(), "e"))
