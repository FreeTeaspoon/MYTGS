# MYTGS for macOS

Native macOS 26 port of MYTGS, built with SwiftUI, AppKit, WebKit, and Swift Package Manager.

## Status

This repository is now macOS-only. The original Windows WPF source has been removed from this fork so the Swift package lives at the repository root.

Implemented scaffold:

- Firefly school lookup, SSO login, token validation, dashboard fetch, task fetch, timetable events, profile image fetch, EPR fetch, and logout calls.
- Keychain token storage, SwiftData task cache, local settings persistence, EPR parsing, timetable processing, task search, and local HTTP API shape.
- SwiftUI/AppKit app shell with native sidebar navigation, settings, WebKit login, menu bar item, notifications, and floating clock panel.

## Open In Xcode

Open `MYTGS.xcodeproj` in Xcode 26.

Run the `MYTGS` scheme to launch the app as a real `MYTGS.app` bundle.

## Command Line

The Swift package remains available for command-line development and core checks:

```sh
swift test
swift build --product MYTGSMac
swift run MYTGSCoreChecks
```

`swift test` runs the offline fixture test suite. `MYTGSCoreChecks` remains a quick smoke check.

## Release Prep

Release signing is prepared but not active until local Apple Developer details are added. Copy `Config/Signing.local.xcconfig.example` to `Config/Signing.local.xcconfig`, fill in the private local values, then use:

```sh
Scripts/release.sh preflight
```

The Sparkle feed is prepared for `https://freeteaspoon.github.io/MYTGS-MAC/appcast.xml`. See `Docs/Release.md` for the full direct-distribution flow.

## Remaining Production Work

- Finish polishing macOS 26-specific UI behavior once the app bundle is in place.
