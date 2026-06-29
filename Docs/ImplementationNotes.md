# MYTGS Native macOS Port

This repository contains the native macOS 26 port scaffold for MYTGS.

## Shape

- `Sources/MYTGSCore`: Firefly models, API client, EPR parser, timetable engine, SwiftData cache, Keychain token storage, settings, task search, and the local HTTP API.
- `Sources/MYTGSMac`: SwiftUI/AppKit app shell with native sidebar navigation, settings, WebKit SSO, menu bar item, notifications, and floating clock panel.
- `Tests/MYTGSCoreTests`: fixture-based tests for the highest-risk behavior translations.

## Xcode

This is implemented as a root-level Swift package that Xcode 26 can open directly. Sparkle should be added when the package is promoted into a signed `.xcodeproj` app bundle; keeping the package dependency out of this scaffold avoids Xcode package-graph failures while running the app from `Package.swift`.

## Remaining Production Work

- Configure Apple Developer signing, hardened runtime, notarization, Sparkle `SUFeedURL`, and Sparkle EdDSA appcast signing.
- Add sanitized live Firefly fixtures for every endpoint.
- Decide the final bundle identifier if `com.freeteaspoon.mytgs` needs a team-specific prefix.
