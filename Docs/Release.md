# Release Setup

MYTGS is prepared for direct distribution outside the Mac App Store. Debug builds still run locally with ad-hoc signing. Release builds are set up for Developer ID signing, hardened runtime, notarization, and Sparkle updates.

## One-Time Local Setup

1. Install a Developer ID Application certificate in Keychain Access.
2. Copy `Config/Signing.local.xcconfig.example` to `Config/Signing.local.xcconfig`.
3. Fill in your Apple Developer Team ID and full Developer ID signing identity.
4. Store notarization credentials:

```sh
xcrun notarytool store-credentials MYTGS-notarytool --team-id YOURTEAMID --apple-id you@example.com
```

5. Keep the Sparkle private EdDSA key in this Mac's Keychain. The matching public key is committed in `Config/MYTGS-Release.xcconfig`.

`Config/Signing.local.xcconfig` is ignored by git. Do not commit Apple credentials or Sparkle private keys. If the Sparkle key ever needs to be rotated, generate a new key with Sparkle's `generate_keys` tool, commit only the new public key, and keep the private key in Keychain.

## Release Build

Run a preflight check first:

```sh
Scripts/release.sh preflight
```

Build, notarize, staple, and verify:

```sh
Scripts/release.sh release
```

The script writes archives under `build/release/` and release zips under `dist/`.

## Unsigned Alpha DMG

If you are publishing an alpha build without Apple Developer ID, build the app locally with ad-hoc signing, then package it as a drag-and-drop DMG:

```sh
xcodebuild -project MYTGS.xcodeproj -scheme MYTGS -configuration Release -destination "generic/platform=macOS" -derivedDataPath build/unsigned CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY=- DEVELOPMENT_TEAM= ENABLE_HARDENED_RUNTIME=NO OTHER_CODE_SIGN_FLAGS= build
Scripts/package-unsigned-dmg.sh 0.1.0-alpha.1
```

This creates `dist/MYTGS-0.1.0-alpha.1-installer.dmg` with `MYTGS.app`, an Applications shortcut, and a Finder background. Upload this only as a prerelease and clearly note that macOS will show an unidentified developer warning.

## Sparkle Appcast

Sparkle is configured to read:

```text
https://freeteaspoon.github.io/MYTGS-MAC/appcast.xml
```

Use GitHub Releases for the notarized zip download, then publish the Sparkle appcast through GitHub Pages. When creating the appcast, sign update archives with Sparkle's EdDSA key. Do not publish or commit the private key.

The committed `MYTGS_SPARKLE_PUBLIC_ED_KEY` lets release builds verify Sparkle updates. The private key must stay available locally when creating signed appcasts.
