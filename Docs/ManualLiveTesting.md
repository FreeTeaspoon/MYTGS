# Manual Live Firefly Testing

Use this checklist before a public build. Automated tests use synthetic fixtures, so this is the pass that proves the live Firefly account flow still works.

## Setup

- Open `MYTGS.xcodeproj` in Xcode 26.
- Run the `MYTGS` scheme as a Debug app bundle.
- Use a real MYTGS Firefly account only on your own Mac.
- Do not save screenshots, logs, or fixtures containing real student names, IDs, emails, task content, or tokens.

## Account And Refresh

- Launch starts on Dashboard and shows a signed-out state if no token is stored.
- Account > Sign In opens the Firefly WebView.
- SSO completes and Account shows the expected name, email, and school.
- Refresh completes without showing `Refresh failed`.
- Relaunch restores the saved login from Keychain.
- Sign Out deletes the token and returns the app to signed-out state.

## Data Parity

- Dashboard content loads and is readable in the native container.
- Tasks load, search filters by title, sort options reorder as expected, and task detail shows description, teacher, class, set date, due date, and ID.
- Timetable shows today and the two-week grid with sensible periods, rooms, and times.
- EPR shows current changes and the original EPR page when available.
- Local API works on the configured port:
  - `GET /api/timetable`
  - `GET /api/info`
  - `GET /api/epr`

## macOS Behavior

- Notification permission appears once when appropriate.
- EPR notifications do not repeat unexpectedly during ordinary refreshes.
- Launch at Login applies only when running as `MYTGS.app`.
- Menu bar actions show the app, refresh, check updates, and quit.
- Floating clock shows the current or next period, updates progress, fades on hover when enabled, and respects placement/hide settings.
- Light mode, dark mode, narrow windows, sidebar collapse, keyboard navigation, and Settings tabs do not overlap text or controls.

## Privacy Check

- Before sharing logs or screenshots, confirm they do not include real names, IDs, emails, task titles, task descriptions, timetable details, tokens, or school-private URLs.
