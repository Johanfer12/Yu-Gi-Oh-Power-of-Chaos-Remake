# Android release and update contract

The public APK is identical for every user. Its package is
`org.porttesting.powerofchaos`; updates retain the established signing certificate.
Original game resources are never uploaded. GitHub Actions builds and signs the APK;
the Windows launcher downloads it from the release (**Download APK**) and prepares the
separate private PCK locally (**Create .pck resources**). Android imports
the PCK once into app storage and retains it, saves and preferences across APK updates.
Repacking an APK would invalidate its signature.

## In-app update

The Android launcher downloads `PowerOfChaos-Android.apk` into app storage
(`user://updates`, exposed by Godot's FileProvider) with progress, verifies its SHA-256
against the validated `ANDROID_RELEASE.json` (package, version code, signing certificate)
and opens the system installer with `OS.shell_open`. Android always asks the user to
confirm; the first time it also asks to allow installs from this app
(`REQUEST_INSTALL_PACKAGES`, declared in the preset's custom permissions). Pressing
Update again reopens the installer without downloading. A failed download, checksum or
installer launch falls back to the browser download. Old downloads are removed at start.
`android_updates_test.gd` covers the flow on desktop with an injected installer.

## Release procedure

1. PC and Android share `main`: game fixes need no port. Check that Android-only
   behaviour stays behind its platform checks or files (`docs/ANDROID.md`) and run the
   Android desktop tests with `--platform=android --mobile-controls=true`, plus
   `desktop_pointer_test` for PC. Local work is code and tests only.
2. Set `config/version` in `game/project.godot` to the release and increment the
   Android Tablet preset's `version/code`; an unchanged versionCode is not offered to
   installed apps.
3. Push to `main` and tag `vX.Y.Z[-alpha.N]`. GitHub Actions builds everything from that
   commit; nothing is built or uploaded by hand:
   - `tools/build_android.py` exports the allowlisted Android source snapshot
     (`tools/prepare_android_public.py`) and builds its engine-only APK with
     `tools/android/build_apk.py --engine-only --release`. The APK is signed with the
     repository secret `ANDROID_SIGNING_KEYSTORE` and `--release` refuses any key whose
     certificate differs from `PUBLIC_SIGNING_CERTIFICATE` (`3ecec96a…`), so installed
     apps can always update. It also verifies 16 KB alignment, ZIP integrity, absence of
     original resources and that a fresh profile boots to the importer.
   - `tools/build_windows.py --android` checks that APK and embeds in the EXE the exact
     source snapshot it came from, so the launcher packs PCKs in the format that APK
     reads; end users neither modify nor sign the APK.
   - A tag publishes the EXE, the APK and `ANDROID_RELEASE.json` together. A tag build
     without the signing secret fails; other builds without it (forks) use a throwaway
     key as a build check only.

The installed updater only recognizes semantic tags such as `v0.1.0-alpha.19`, and the
metadata `version` must equal that tag. Older `android-vNN` releases were immutable
downloads for the former pinned builder and are no longer created.

The signing key is a single file with Godot's debug-keystore password. Keep the
original outside Git as the backup; losing it means installed apps can only move to a
new key by uninstalling. To (re)install it as the repository secret:
`base64 -w0 debug.keystore | gh secret set ANDROID_SIGNING_KEYSTORE`.

For alpha.18, the compiled updater extracted from the actual alpha.17 APK
(versionCode21) first reproduced the missing notice with only `android-v22`,
then accepted alpha.18/versionCode22 through both the saved release response
and the real GitHub HTTP check. Signature and package checks remain enabled.
Reproducer: Android `game/tests/android_published_update_test.gd`; retained
fixtures, log and result: `artifacts/android/update-alpha18/` in that checkout.
The app checks once per process, so close it completely and reopen it after
a release is published. This check does not claim physical-device testing.

## Runtime behavior

Android checks trusted repository release assets, metadata, package, increasing
versionCode and the installed build's signing certificate before offering an update.
The update button downloads the APK inside the app and verifies its SHA-256 before
opening the system installer (see In-app update); the browser download is only the
fallback. Android asks the user to confirm installation and enforces the APK
signature. The app does not perform silent installation. Do not uninstall
or clear app storage to update. A new device or removed app needs its resource
PCK again. Legacy APKs using another key require that original build process, or
an explicitly chosen fresh installation of the public APK.

Content imports validate the asset-only PCK namespace before mounting, use a worker
for copying/hash verification, preserve an existing valid cache and leave recovery
copies for invalid previous files. No application code is accepted in resource PCKs.
The data format is version 1; resource-contract changes require a separate migration
review rather than assuming every old PCK is compatible.

## Validation scope

Android20's direct importer checks passed with the real three-game PCK, including
second startup, but missed the actual empty-profile boot route: boot displayed an
old missing-data message before the importer could open. A user device screenshot
identified this gap. Android21 routes that startup to the PCK selector and adds a
regression through the configured main scene. Existing resource PCKs remain compatible.
The earlier native regressions, 25 standard and 25 animated replays, touch 1x/2x and
tribute selection remain the baseline; this boot fix requires focused import checks.
The whole workflow has not been tested on a physical Android device. Older tests
retain documented ObjectDB exit warnings and a historical WebP/PNG comparison limit;
these are not presented as clean passes. Sources and reports remain in the private
Android checkout; public exports exclude original assets and native fixtures.
