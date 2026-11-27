# Yu-Gi-Oh! Power of Chaos Remake · Android

**English** | [Español](README.es.md) | [Windows launcher](https://github.com/Johanfer12/Yu-Gi-Oh-Power-of-Chaos-Remake/tree/main)

## Contents

- [Why use it?](#why-use-it)
- [Play options](#play-options)
- [First installation](#first-installation)
- [Updates and existing installations](#updates-and-existing-installations)
- [Build from source](#build-from-source)
- [Validation and notices](#validation-and-notices)

## Why use it?

- **All three games in one Android app.** Use your own compatible Yugi, Kaiba and Joey resources, starting with whichever games you own.
- **Import once, keep playing after updates.** Your private resource pack and saved games remain in app storage while compatible public APKs update the engine.
- **Prepare everything from Windows.** **Create APK** produces the public APK and your private PCK together, without an account, SDK/JDK installation or personal signing key.
- **Current PC play settings on Android.** Aspect, FPS, simulation speed, quick play and improved Spanish card text accompany the existing touch controls.
- **Touch controls built for duels.** Scrolling, dragging and native selection of one or two tribute monsters are retained, with menu and press-and-hold control modes.
- **Joey LAN play.** Connections have previously been tested PC↔PC and PC↔Android; current device testing remains separate.

The public APK contains the engine, without original game resources. Your private PCK is prepared locally and is not uploaded. This branch publishes sources without original assets or private signing keys.

## Play options

Open the launcher's gear to adjust:

| Setting | Options |
|---|---|
| Aspect | Stretched, original 4:3 without a background, or each game's decorative overlay. |
| FPS | 30, 60 or the display refresh rate. |
| Simulation | Normal or 2× speed. |
| Quick play | Optional skipping of character scenes, voices and wipes in all three games; music and sound effects remain enabled. |
| Improved card translations | Optional reviewed Spanish names and descriptions for all 771 cards, preserving the original effects. First preparation downloads approximately 110 MB; the pack then works offline. |
| Touch controls | Menu or press-and-hold, with scrolling, dragging and tribute selection. |

Preferences are saved. Quick play and improved translations start disabled; translations affect card text, not menus or game rules.

## First installation

1. Download the Windows EXE from [Releases](https://github.com/Johanfer12/Yu-Gi-Oh-Power-of-Chaos-Remake/releases). Select your ISO images or installed game folders, or reuse your prepared PC library.
2. Click **Create APK**. The launcher verifies the public APK and prepares a private resource pack. No SDK, JDK or signing-key setup is needed for this normal flow.
3. Copy both files from **PoC Data/android/apks/** to your Android device: the **.apk** and its **-resources.pck**.
4. Install and open the APK. On **Add your games**, tap **Select .pck resource pack**, open **Downloads** in the Android file picker and select your PCK. The app checks and copies it into its own storage. Copying the file to Downloads alone does not import it.

Import the pack once. You do not need to select it again after reopening the app or installing compatible updates. The PC launcher retains tools, validation receipts and logs under **PoC Data/android/**. Back up that folder with the EXE.

## Updates and existing installations

The Android update button checks GitHub releases and opens the public APK download when a compatible update is available. Download the APK and confirm the update in Android's installer. Android may ask permission to install from your browser or file manager. **Do not uninstall the app first:** an in-place update preserves resources, preferences and saved games.

The public APK maintains a stable signing certificate. The updater checks release metadata and certificate compatibility before offering it.

**Switching from an older installation:** prepare your PCK from PC first. If the old app uses a different signing key, Android cannot replace it with the public APK as an update. If you accept losing the old app's data, uninstall it, install the public APK and import your PCK once. Future compatible public updates preserve that imported pack and your saves.

Advanced users who need to keep a differently signed installation can retain their original key and optional **android-builder.json** configuration to create matching updates instead. The public updater reports the signing mismatch; it does not delete the app, personal keys or previous builds.

## Build from source

Cloning this branch is unnecessary for normal **Create APK** use. Developers can build a resource-free APK with their own tools and signing key:

    python tools/android/build_apk.py --engine-only --godot <godot_console.exe> --sdk <Android-SDK> --debug-keystore <your-debug.keystore> --first-build --work <new-work-directory> --output <new.apk>

For a matching update to a custom installation, replace `--first-build` with `--previous-apk <your-previous.apk>` and use its original signing key. Normal users receive the official public APK through **Create APK**.

For devices with a 32-bit ARM processor (armeabi-v7a), add `--abi armv7` to the same command. Only the staged export copy changes: the repository's export preset and the official public APK stay 64-bit (arm64-v8a). The in-app updater only knows the public 64-bit APK, so update 32-bit builds manually with the same signing key.

To prepare only a private resource pack, Godot is sufficient:

    python tools/android/build_apk.py --content-only --godot <godot_console.exe> --data <your-compact-data> --work <new-work-directory> --content-output <private-resources.pck>

Game code is in **game/**; generated export projects are not the editable source. Do not publish your resource pack or private signing key.

## Validation and notices

Build checks cover the signing certificate, APK integrity, 16 KB alignment and the appropriate first-run or bundled-resource startup path. Resource imports, persistence, update metadata and touch regressions have been checked on the build computer. **The new import/update flow has not yet been verified on a physical Android device.**

The source includes unofficial experimental work derived in part through reverse engineering. Fidelity, hardware support and licensing of the game implementation remain under review. The [Apache License 2.0](LICENSES/Apache-2.0.txt) covers the project-authored tools listed in [NOTICE](NOTICE) where present. See [third-party notices](THIRD_PARTY_NOTICES.md).
