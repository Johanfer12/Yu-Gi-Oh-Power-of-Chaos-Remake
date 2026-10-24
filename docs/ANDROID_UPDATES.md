# Android release and update contract

The public APK is identical for every user. Its package is
`org.porttesting.powerofchaos`; updates retain the established signing certificate.
Original game resources are never uploaded. The Windows launcher embeds a verified
copy of the public APK and prepares a separate private PCK locally. Android imports
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
   `desktop_pointer_test` for PC.
2. Increment Android versionCode and set its build version to the intended PC release.
   Export a fresh allowlisted Android source snapshot (`tools/prepare_android_public.py`,
   source `main` by default). Build its engine-only APK using
   `tools/android/build_apk.py --engine-only`, the established local signing key and
   the previous APK for certificate comparison. Keep signing keys outside Git/GitHub.
3. Verify signature, certificate continuity, 16 KB alignment, ZIP integrity and absence
   of original resources. Run touch, content import/persistence and native regressions.
   On an empty profile, launch the configured main scene and verify it reaches the
   import button. Instantiating the importer directly does not test the boot route.
   Publish the signed APK, checksum and ANDROID_RELEASE.json under its Android tag.
4. Update the Windows builder's source commit/manifest hash and public APK URL/hash.
   The EXE embeds that exact APK; end users neither modify nor sign it. No SDK/JDK or
   account is needed for the normal APK + PCK workflow. Explicit custom-key builds
   retain their separate advanced configuration.
5. Windows CI downloads the pinned signed public APK without receiving any private
   signing material. When Android metadata names this PC release version, CI also
   publishes the APK and its metadata with the EXE, making them visible to the Android
   updater. A PC-only release does not masquerade as a newer Android build.

The installed updater only recognizes semantic tags such as
`v0.1.0-alpha.18`. Publishing solely under `android-v22` does not expose an
update to an installed app. Before declaring an update available, publish the
APK and `ANDROID_RELEASE.json` together under the semantic release tag; its
metadata `version` must equal that tag. The Android-specific tag may remain as
the immutable download pinned by the Windows builder.

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
The update button opens the APK download in a browser. Android asks the user to
confirm installation and enforces the APK signature. The app does not claim to
verify browser downloads itself or perform silent installation. Do not uninstall
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
