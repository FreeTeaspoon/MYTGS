# MYTGS Native macOS Port

This repository contains the native macOS 26 port scaffold for MYTGS.

## Shape

- `Sources/MYTGSCore`: Firefly models, API client, EPR parser, timetable engine, SwiftData cache, Keychain token storage, settings, task search, and the local HTTP API.
- `Sources/MYTGSMac`: SwiftUI/AppKit app shell with native sidebar navigation, settings, WebKit SSO, menu bar item, notifications, and floating clock panel.
- `Tests/MYTGSCoreTests`: fixture-based tests for the highest-risk behavior translations.

## Xcode

This is implemented as a root-level Swift package plus `MYTGS.xcodeproj`. Open the project to run the real `MYTGS.app` bundle; keep using `Package.swift` for command-line builds and core checks.

## Remaining Production Work

- Install local Apple Developer credentials, generate the Sparkle EdDSA key, and run the prepared release script.
- Add sanitized live Firefly fixtures for every endpoint.
- Decide whether `com.freeteaspoon.mytgs` needs an Apple Developer team-specific prefix before public distribution.
