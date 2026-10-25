<p align="center">
  <img src="game/assets/icons/launcher.svg" width="112" height="112" alt="PoC Remake icon">
</p>

# Yu-Gi-Oh! Power of Chaos Remake

**English** | [Español](README.es.md)

[![Download EXE for Windows](https://img.shields.io/badge/Download_EXE-Windows-2ea44f?style=for-the-badge)](https://github.com/Johanfer12/Yu-Gi-Oh-Power-of-Chaos-Remake/releases/download/v0.1.0-alpha.20/PowerOfChaos.exe)

[![Download Android APK](https://img.shields.io/badge/Android-APK-3DDC84?style=for-the-badge)](https://github.com/Johanfer12/Yu-Gi-Oh-Power-of-Chaos-Remake/releases/download/v0.1.0-alpha.20/PowerOfChaos-Android.apk)

**Direct download · Windows · v0.1.0-alpha.20 preview · No ZIP required**

**Bring your Power of Chaos games together in one modern Windows launcher.**

## Contents

- [Why use it?](#why-use-it)
- [Launcher settings](#launcher-settings)
- [Your ISO → PC or Android APK](#your-iso--pc-or-android-apk)
- [Launcher screenshots](#launcher-screenshots)
- [What is this remake?](#what-is-this-remake)
- [Get started on Windows](#get-started-on-windows)
- [How it works](#how-it-works)
- [Compatibility and current limits](#compatibility-and-current-limits)
- [Languages and voice packs](#languages-and-voice-packs)
- [Run from source](#run-from-source)
- [Automatic Windows builds](#automatic-windows-builds)
- [Project status and notices](#project-status-and-notices)
- [Build your Android APK](#build-your-android-apk)

## Why use it?

- **PC or Android from the same launcher.** Prepare your games for Windows, or get the public Android APK together with a private resource pack. Import the pack once on Android and keep it through app updates.
- **Joey network duels without DirectPlay.** Modern LAN networking replaces the legacy Windows component. Connections have been tested between PC and PC, and between PC and Android.
- **Portable.** Keep the EXE and its **`PoC Data`** folder together: your resources, saves and settings travel with them.
- **Lighter game resources.** Lossless WebP images and OGG audio reduce storage; the tested Yugi library takes about **44% less space** than its uncompressed converted version. Savings vary by game and edition.
- **16:9 decorative side panels.** Widescreen decorations surround the original 4:3 duel area in the supported Yugi, Kaiba and Joey views, each with its own background.
- **All three games in one place.** Yugi the Destiny, Kaiba the Revenge and Joey the Passion share one launcher. Import just one to start and add the others whenever you want.
- **Shared collection, separate decks.** Keep your cards across games with the original compatibility: Yugi uses its own catalog, Kaiba also uses Yugi cards, and Joey uses all three. Each title keeps its active deck.
- **Choose your pace and display.** Select 30 FPS, 60 FPS or your display refresh rate, choose stretched, original 4:3 or decorative backgrounds, and play at normal or 2× speed.
- **Optional quick play in all three games.** Skip character scenes, voices and scene wipes while keeping music and sound effects. [See launcher settings](#launcher-settings).
- **The same play options on Android.** Aspect, FPS, simulation speed, quick play and improved Spanish card text accompany the existing touch controls, scrolling, dragging and tribute selection.

## Launcher settings

Open the **gear** in the launcher to choose how you play:

| Setting | Options |
|---|---|
| Aspect | **Stretched** fills the window; **Original, no background** keeps 4:3 with black bars; **Overlay** adds each game's decorative duel background around the original 4:3 area. |
| FPS | **30**, **60**, or **Display**, which follows the current monitor's refresh rate. |
| Simulation | **Normal** or **2×**. Simulation speed is independent of the FPS limit. |
| Quick play | Skip character introductions, outros, portrait reactions, spoken lines and scene wipes in **Yugi, Kaiba and Joey**. Music and sound effects remain enabled. |
| Improved card translations | **Original** or **Improved (ES)**: Spanish names and descriptions for all **771 cards**, using public community sources and adaptations that preserve the original effects. |

**Default settings:** display refresh rate, normal simulation speed and quick play off.

Preferences are remembered between launches. Quick play is optional and starts **off**;
turn it off to restore the original presentation. The launcher opens maximized from
the start, and you can still resize the window or use **F11 / Alt+Enter** for fullscreen.

**Improved card translations** is optional and starts **off**. It covers Spanish names and descriptions for all **771 cards** across the three games, using public community databases with reviewed adaptations for the original English effects. Menus and game rules stay as they are; this is a community improvement, not an official translation pack.

Enable it with an internet connection to prepare the local pack. The first download is approximately **110 MB**; afterward the texts work offline. Opening the launcher does not start downloads. If preparation fails, imported texts remain available. Turn the option off at any time to restore them.

## Your ISO → PC or Android APK

Select your ISO images or installed game folders, then choose:

- **Extract for PC** to prepare the games for Windows.
- **Create .pck resources** to prepare a private **`.pck` resource pack** made from your games, saved with its validation receipt in **`PoC Data/android/pck/`**. Already prepared games can also be reused.
- **Download APK** to download this version's public Android APK from GitHub.

**Android setup is handled by the launcher.** The public APK is built and signed by GitHub Actions; the launcher prepares the resource pack locally. No account, Android SDK, JDK, signing-key setup or author signing key is needed for this normal workflow. Install the APK, open it and select your `.pck` once. Later compatible updates keep those resources and your saves. [Prepare your Android files](#build-your-android-apk).

Your ISO images and converted resources stay on your computer; no original game data is included in the download. Joey's networking has been tested between **PC and PC**, and between **PC and Android**. This is still an alpha: feedback, bug reports and testing on other editions and devices are welcome.

## Launcher screenshots

**Your library, with all three games prepared (English interface)**

![English launcher with Yugi, Kaiba and Joey ready to play](docs/images/launcher-library-en.png)

**Import your resources and choose PC extraction or Android APK creation**

![English import screen showing ISO and folder selection, Extract for PC, Create .pck resources and Download APK](docs/images/launcher-import-en.png)

The screenshots show the Windows launcher. Game logos appear after importing your own compatible copies.

## What is this remake?

Yu-Gi-Oh! Power of Chaos Remake is an experimental Godot reimplementation of the engine behind **Yugi the Destiny, Kaiba the Revenge, and Joey the Passion**. It aims to preserve the original games' rules, presentation and feel while making them easier to launch and maintain on modern PCs.

You provide a compatible copy of the game you want to play. The launcher reads its resources locally and prepares them for the new engine. **One game is enough to get started.** You can add the other two later.

> **Early preview:** development and compatibility testing are ongoing. This is not a finished, fully faithful replacement for every original release.

### More launcher features

- **One launcher for three games.** Open an imported game by clicking its logo, or add another from the same menu.
- **One Windows executable.** The packaged launcher includes Godot, the local converter and 7-Zip. Players do not need to install those tools separately.
- **Start with the game you own.** Import Yugi, Kaiba or Joey independently; the other two are optional.
- **Use an ISO or an installed game folder.** Supported disc images are read as archives without running their installers or original game executables.
- **A portable game folder.** Resources, saves, preferences, conversion tools and temporary extraction files stay in **`PoC Data` beside the EXE**. Move the EXE and that folder together.
- **Smaller resource storage.** Images use pixel-exact lossless WebP when smaller; music and longer voices use OGG Vorbis. Very short effects remain WAV, as in the Android optimization process.
- **Keep your files local.** Your disc images, extracted resources and saved games are not uploaded to GitHub or a conversion service.
- **Add games without starting over.** Later imports preserve previously prepared games and existing remake saves.
- **Choose your language.** The launcher offers English, Spanish, German, French, Italian and Japanese, selects a supported system language on first use and remembers your preference.
- **A launcher made for this project.** Original launcher music, gold-accented controls, a custom application icon, volume settings and quick access to your games.
- **A maintainable engine.** Gameplay runs in Godot rather than by patching or launching the original Windows executables. Original resources are supplied separately by each player.

"Remake" refers to the engine reconstruction. It does not mean the original card illustrations, voices or music have been redrawn or re-recorded.

## Get started on Windows

1. [Download **`PowerOfChaos.exe`** directly](https://github.com/Johanfer12/Yu-Gi-Oh-Power-of-Chaos-Remake/releases/download/v0.1.0-alpha.20/PowerOfChaos.exe). Development builds are also available in [Actions](https://github.com/Johanfer12/Yu-Gi-Oh-Power-of-Chaos-Remake/actions/workflows/build-windows.yml).
2. Put the EXE in a folder where you want to keep the launcher and its saves, then open it.
3. In **ADD YOUR RESOURCES**, move over the game you want to add and choose **ISO** or **Folder**.
4. Select a compatible disc image or installed game folder, then click **Extract for PC** and wait for conversion to finish.
5. Click the prepared game's logo to play. The remaining games can be added later from the same screen.

The download is a single EXE; no installation wizard is required. The first import extracts and verifies the bundled conversion tools in `PoC Data/tools/`. Opening the menu does not wait for that extraction.

GitHub may package Actions artifacts in a ZIP. Release downloads expose the EXE directly.

### What you need

- A Windows PC capable of running Godot's OpenGL compatibility renderer.
- A compatible copy of at least one original game.
- Enough free disk space for the converted resources and temporary extraction files.

An installed game folder must contain `Data.dat`, `Voice.dat`, `Region.dat` and the corresponding original executable. The executable is read to obtain supported engine tables; it is not launched.

## How it works

```text
Your ISO or installed game folder
                |
       Local validation and extraction
                |
       Converted resources on your PC
                |
          Godot game engine
```

The distributed EXE contains the launcher, engine code and conversion tools. Original game binaries, card artwork, voices and in-game music are not distributed with it. They are read from the copy you select and converted locally.

Conversion works in a temporary directory inside `PoC Data`. It validates and compresses the new library before switching it into `PoC Data/resources/`. When adding a game, it uses the existing library as its base and retires the superseded generated copy after a successful switch. Original disc images, installed game folders and saves are not overwritten.

The importer validates supported executable profiles and rejects unsupported revisions. It also rejects damaged or truncated disc images. It does not download missing game resources.

### Where files are stored

| Files | Location relative to the EXE |
| --- | --- |
| Converted WebP/OGG resources and engine data | `PoC Data/resources/` |
| Remake saves | `PoC Data/saves/` |
| Launcher settings | `PoC Data/content.cfg` |
| Bundled conversion tools and licenses | `PoC Data/tools/` |
| Temporary extraction files | `PoC Data/temp/` and transient staging directories inside `PoC Data/` |
| Last import error report | `PoC Data/import-last-error.log` |

Import failures show the affected game, source file or folder, stage and cause. Use **Copy details** or **Open log** in the error dialog, and **View error** to reopen it. General conversion, compression or write failures identify their stage without blaming an ISO without evidence.

Keep **`PowerOfChaos.exe` and `PoC Data` together** when moving or backing up the game. The launcher uses relative resource paths, so moving the pair to another folder or drive does not require importing again. Choose a writable folder; if it is read-only, the launcher asks you to move it instead of silently storing games elsewhere.

When upgrading in the same folder, the launcher copies existing adjacent `saves/` into `PoC Data/saves/` without replacing newer portable saves. It also migrates the older application preferences and prepares a compact local copy of the previous imported library. Migration keeps the old source intact until the new library is verified. If upgrading to a different folder, copy your previous `saves/` beside the new EXE before its first run, or move an existing `PoC Data` folder with it.

## Compatibility and current limits

The launcher checks GitHub releases on startup. The circular **update** button next to the power button appears only when a newer version is detected. The footer shows your version, update status, GitHub and license links. You can download an update and restart from the launcher: SHA-256 is verified before replacing only the EXE, preserving `PoC Data`. Downloads can be canceled. If replacement or process launch fails, the helper attempts to restore the previous EXE; diagnostics are saved in `PoC Data/updates/last-update.log`. Alpha/beta builds also follow previews; stable builds stay on stable releases. Windows, an internet connection and a writable EXE folder are required.

This preview targets **Windows PC**. Other platforms are not part of this release workflow.

The current development checks cover:

| Game | Import sources checked | Engine checks |
| --- | --- | --- |
| Yugi the Destiny | Compatible ISO and installed folder | Independent title and normal-duel startup |
| Kaiba the Revenge | Compatible ISO and installed folder | Independent title and normal-duel startup; supported executable profiles normalized without requiring Yugi |
| Joey the Passion | Compatible ISO and installed folder | Independent title and normal-duel startup |

Compatible ISO images of all three games have been imported; truncated images are rejected with details identifying the affected game. Support for other revisions and regions is still expanding.

Gameplay, AI, presentation and timing are under active comparison with the originals. Passing these checks does not certify every duel or every card interaction. Please report the game, edition, import source and steps needed to reproduce a problem; do not attach original game files to issues.

Supported original MSI/CAB discs are extracted with bundled 7-Zip. Inno Setup media require `innoextract` on `PATH`; other unsupported installers should be installed separately before selecting their installed folder.

## Languages and voice packs

The language selector controls the launcher and the game's available text resources. Availability depends on the imported edition. `Data.dat` can differ between regions and revisions; the importer does not assume every release has identical data.

Voice packs are detected from the supplied `Voice.dat`. Switching language uses the matching installed dub when available, otherwise the primary imported dub remains in use. Selecting a language does not download its voices.

Additional voice packs from another compatible copy of the same game can be imported from the source tools:

```powershell
python -m pocx.import_games --base "existing-data" --voice "joey=C:\My Joey Copy\Voice.dat" --out "new-data"
```

Use a new output directory for manual imports. The launcher manages its own atomic in-place updates. Two different voice packs for the same game and language are rejected as a conflict rather than silently replacing one another.

## Run from source

Development requires **Godot 4.7.2** and **Python 3.12 or newer**. The Windows build workflow uses Python 3.13.

```powershell
git clone https://github.com/Johanfer12/Yu-Gi-Oh-Power-of-Chaos-Remake.git
cd Yu-Gi-Oh-Power-of-Chaos-Remake
python -m pip install ./tools
godot --editor --path game
```

Run `game/project.godot` from the editor. Start with an ISO or installed folder, just as in the packaged launcher. If Python is in a virtual environment, launch Godot from a shell with that environment activated.

Source-based imports need 7-Zip available through `PATH` or its usual Windows installation location. The distributed EXE already includes it and the audio encoder; FFmpeg is not needed for normal imports.

Synthetic importer checks do not require original game resources:

```powershell
$env:PYTHONPATH = "tools"
python -m unittest discover -s tools/tests -p "test_*import.py" -v
```

## Automatic Windows builds

Shared code changes require an Android parity review before publication; see the [Android release procedure](docs/ANDROID_UPDATES.md).

Each release includes [English change notes](RELEASE_NOTES.md) describing its improvements and fixes.

[Launcher Windows](https://github.com/Johanfer12/Yu-Gi-Oh-Power-of-Chaos-Remake/actions/workflows/build-windows.yml) builds from the public sources:

- Pushes to `main` and pull requests generate a Windows build.
- The workflow can also be started manually.
- Tags beginning with `v` generate a GitHub prerelease containing the EXE, its SHA-256 checksum and a build manifest.

Each build checks the source file policy, runs synthetic importer tests, creates a clean export project, bundles the local converter and verifies the embedded tools. Game resources are not required by the build and are not included in it.

Installed copies can check and download new releases with the update button; replacement and restart require confirming the update.

## Project status and notices

PoC Remake is an independent, unofficial project. It is not affiliated with or endorsed by the original games' publishers or rights holders. Game names identify compatible titles; their assets and trademarks remain with their respective owners.

The launcher theme, the three external duel backgrounds and the custom application icon belong to this project. The pending-game frames include vector outlines derived from the original logos; the original logo images are loaded only after importing a user's copy.

The source includes work derived through reverse engineering. Its provenance and project-wide licensing remain under review; no blanket license for the repository has been assigned. Publishing the sources does not license the original games or grant rights to redistribute their assets.

Third-party components retain their own licenses. See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) and **Licenses** in the packaged launcher for the bundled engine and tool notices, including the matching 7-Zip source archive.

## Build your Android APK

1. Select your ISO images/folders or reuse the library already prepared for PC.
2. Click **Create .pck resources**. The launcher downloads Godot's resource packer when needed, verifies its SHA-256 checksum and prepares your private resources locally. It opens **`PoC Data/android/pck/`**, containing the **`.pck`** and a JSON validation receipt.
3. Click **Download APK** to get this version's public APK from GitHub. Copy both the APK and PCK to your Android device.
4. Install the APK. At first launch, choose **Select .pck resource pack** and select that PCK. Import it once; the app keeps its own copy alongside your saves.

The normal workflow needs no account, SDK, JDK, Android Studio or personal signing key. The APK is the same public, consistently signed application for every player; the private PCK contains the resources from your games and is never uploaded. Original game resources and the author's signing key are not included in the public download. Initial preparation requires internet and free space; downloaded tools are reused.

Android keeps the same display and play settings as PC, including optional improved Spanish names and descriptions for all 771 cards. Touch controls include scrolling, dragging and native selection of one or two tribute monsters.

### Android updates and existing installations

Use the update button in the Android launcher: from alpha.19 it downloads and verifies the APK inside the app and opens Android's installer, where you confirm the update. The first time, Android asks you to allow installs from Power of Chaos. **Update the installed app without uninstalling it** to retain its private resource pack, preferences and saves. If the in-app download fails, the APK download opens in your browser instead.

For an older installation, prepare your resource PCK from PC before switching to the public APK. If its signing key differs, Android cannot install it as an update. You can uninstall the old app if you accept losing its app data, then install the public APK and import your PCK once. Future compatible public updates keep your resources and saves without repeating that import.

Advanced users who need to retain a differently signed installation can keep their original key and optional `android-builder.json` configuration to produce matching updates. The public updater reports a signing mismatch instead of replacing the app. Saves remain in that installation while it is updated without uninstalling.

Everything stays inside the data folder:

| Android content | Location |
| --- | --- |
| Reusable tools and bundled sources | `PoC Data/android/tools/` |
| Private PCK and JSON validation receipt | `PoC Data/android/pck/` |
| Build logs and validation reports | `PoC Data/android/builds/` |
| Existing custom-build signing key, when used | `PoC Data/android/signing/debug.keystore` |

The APK is copied unchanged only after its pinned checksum and the private PCK's validation receipt match. Failed preparation leaves no incomplete installable pair. Temporary converted resources are removed without modifying your PC library. Failures show details and retain `PoC Data/apk-last-error.log`. Back up `PoC Data` with the EXE, especially any existing custom-build signing key.

Joey connections have previously been tested PC↔PC and PC↔Android. The new import and update workflow has been validated on the build computer; it has not yet been verified on a physical Android device. Engine fidelity and support for other configurations are still in development.

For developers, `tools/configure_android_builder.py --help` allows an optional custom toolchain and Android checkout through `android-builder.json`. The distributed EXE handles its normal setup inside the launcher.
