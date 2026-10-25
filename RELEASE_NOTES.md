## v0.1.0-alpha.20

- PC launcher: **Download APK** gets this version's public Android APK from GitHub and **Create .pck resources** only prepares your private resource pack in `PoC Data/android/pck/`. The launcher no longer packages an APK.
- The public APK is now built and signed by GitHub Actions with the same certificate as every previous public APK.

Android: update from the launcher; the APK downloads inside the app and Android asks you to confirm the installation. Keep the app installed to retain your imported PCK and saves. Android24 uses the same package and signing certificate as Android23. No new physical-device validation is claimed.

Launcher PC: **Descargar APK** baja de GitHub el APK público de esta versión y **Crear recursos .pck** prepara solo tu paquete privado en `PoC Data/android/pck/`. En Android, actualiza desde el launcher; no desinstales la app ni borres sus datos.
