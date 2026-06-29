# MYTGS Native macOS Port

This repository contains the native macOS 26 port scaffold for MYTGS.

## Shape

- `Sources/MYTGSCore`: Firefly models, API client, EPR parser, timetable engine, SwiftData cache, Keychain token storage, settings, task search, and the local HTTP API.
- `Sources/MYTGSMac`: SwiftUI/AppKit app shell with native sidebar navigation, macOS 26 Liquid Glass surfaces, settings, WebKit SSO, menu bar item, notifications, and floating clock panel.
- `Tests/MYTGSCoreTests`: fixture-based tests for the highest-risk behavior translations.
- `Tests/MYTGSMacUITests`: signed-out UI smoke tests for the Xcode app bundle.
- `Resources`: app icon assets, including the upstream MYTGS logo source and generated macOS `.icns`.

## Xcode

This is implemented as a root-level Swift package plus `MYTGS.xcodeproj`. Open the project to run the real `MYTGS.app` bundle; keep using `Package.swift` for command-line builds and core checks.

## Tests

`swift test` runs offline synthetic Firefly fixture tests under `Tests/MYTGSCoreTests`. The fixtures are fake and sanitized by design; live Firefly captures should only be added after manual redaction.

Manual live Firefly acceptance is tracked in `Docs/ManualLiveTesting.md` and must not produce committed real student data.

## Remaining Production Work

- Install local Apple Developer credentials and run the prepared release script.
- Decide whether `com.freeteaspoon.mytgs` needs an Apple Developer team-specific prefix before public distribution.
