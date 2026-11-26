# Android build — Faza 6

## Project
- Engine: Godot 4.7.2 stable
- Renderer: Mobile
- Package: `com.vlado.lastoutlaw.game`
- Version: `0.6.0-dev` (`versionCode 6`)
- Architecture: ARM64-v8a only
- Minimum Android SDK: 24
- Target Android SDK: 36
- Orientation: landscape sensor
- Immersive mode: enabled
- Launcher application: enabled

The project ZIP can be opened in Godot 4.7.2, including the Godot Android editor. The exported APK is a separate installable debug build.

## Debug APK
File: `VladoSipcic_Faza6_Debug_ARM64.apk`

- Size: 115,827,065 bytes
- MD5: `c0e1904bba72fa38a74da222c286a82a`
- SHA-256: `c629fe4f55553ee5fea5e480013db0099ce327d5fbffb5a21b24e6182176ae88`
- APK Signature Scheme v2: verified
- APK Signature Scheme v3: verified
- ZIP alignment: verified
- APK archive integrity: verified
- Native libraries: ARM64-v8a only

This is a development/debug APK. Android may require permission to install unknown apps. It is not a Play Store release and is not signed with a production release key.

## Security correction
The old preset contained a hardcoded release-keystore path, user and password. Those values were removed. The project contains no release signing secret. A future release APK/AAB must be signed using a separately stored private production key.

## Device testing
The APK was not run on a physical Samsung Galaxy S25 Ultra in this phase. Static Android package validation and Godot runtime regression tests passed, but real-device thermals, touch feel, sustained FPS and memory remain pending.
