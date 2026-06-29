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

5. Generate Sparkle EdDSA keys using Sparkle's `generate_keys` tool. Keep the private key in Keychain and paste only the public key into `MYTGS_SPARKLE_PUBLIC_ED_KEY`.

`Config/Signing.local.xcconfig` is ignored by git. Do not commit Apple credentials or Sparkle private keys.

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

## Sparkle Appcast

Sparkle is configured to read:

```text
https://freeteaspoon.github.io/MYTGS-MAC/appcast.xml
```

Use GitHub Releases for the notarized zip download, then publish the Sparkle appcast through GitHub Pages. When creating the appcast, sign update archives with Sparkle's EdDSA key. Do not publish or commit the private key.

Until `MYTGS_SPARKLE_PUBLIC_ED_KEY` is filled in for a build, the app will show that updates are not configured instead of starting Sparkle.
