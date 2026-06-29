# MYTGS for macOS

Native macOS 26 port of MYTGS, built with SwiftUI, AppKit, WebKit, and Swift Package Manager.

## Status

This repository is now macOS-only. The original Windows WPF source has been removed from this fork so the Swift package lives at the repository root.

Implemented scaffold:

- Firefly school lookup, SSO login, token validation, dashboard fetch, task fetch, timetable events, profile image fetch, EPR fetch, and logout calls.
- Keychain token storage, SwiftData task cache, local settings persistence, EPR parsing, timetable processing, task search, and local HTTP API shape.
- SwiftUI/AppKit app shell with native sidebar navigation, settings, WebKit login, menu bar item, notifications, and floating clock panel.

## Open In Xcode

Open this repository folder, or open `Package.swift` directly in Xcode 26.

Run the `MYTGSMac` scheme.

## Command Line

```sh
swift build --product MYTGSMac
swift run MYTGSCoreChecks
```

## Remaining Production Work

- Promote the Swift package into a signed app bundle or Xcode project for distribution.
- Configure Apple Developer signing, hardened runtime, notarization, and direct updates.
- Add sanitized Firefly fixtures for broader tests.
- Finish polishing macOS 26-specific UI behavior once the app bundle is in place.
