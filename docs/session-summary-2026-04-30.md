# Transit Minute Session Summary - 2026-04-30

## Overview

This session built the first working version of Transit Minute, a native macOS menu bar app that shows when to leave for transit. The app uses a user-provided Google API key, home/work addresses, Google Places autocomplete, Google Routes transit planning, Core Location, and macOS notifications.

## App Foundation

- Created a Swift Package project with:
  - `TransitMinute` executable target.
  - `TransitMinuteCore` library target.
  - `TransitMinuteCoreTests` test target.
- Built a SwiftUI `MenuBarExtra` app for macOS 14+.
- Added local app bundle packaging through `Scripts/build_app.sh`.
- Added bundle metadata in `Packaging/Info.plist`.
- Added ad-hoc signing support and optional stable signing via `SIGN_IDENTITY`.

## Core Transit Logic

- Added core models for:
  - Coordinates.
  - Saved home/work places.
  - App settings.
  - Transit plans.
  - Countdown states.
  - Refresh policies.
- Implemented destination choice:
  - If closer to Home, route to Work.
  - If closer to Work, route to Home.
  - If location is unavailable, use manual origin.
- Implemented countdown logic:
  - `leaveAt = transitDepartureAt - walkingDuration - bufferDuration`.
  - Menu bar states include `Set up`, `Planning`, `N min`, `Leave now`, `Missed`, and `--`.
- Added adaptive refresh behavior:
  - 5 minutes when departure is more than 30 minutes away.
  - 1 minute inside 30 minutes.
  - 10 seconds inside 5 minutes.

## Google API Integration

- Added `GooglePlacesService` for:
  - Address autocomplete.
  - Place details lookup.
- Added `GoogleRoutesService` for:
  - Routes API transit planning.
  - Bus-first routing with broader transit fallback.
- Fixed a Routes API HTTP 400 issue by removing invalid field-mask entries.
- Improved Google API errors so the app shows Google’s actual response message instead of only `HTTP 400`.

## Setup And Settings

- Added first-run setup for:
  - Google API key.
  - Home address.
  - Work address.
- Stores the Google API key in macOS Keychain.
- Stores non-secret settings in `UserDefaults`.
- Added a built-in help window explaining how to create and enable a Google API key.
- Moved settings out of the menu popover into a proper floating macOS settings window.
- Refactored settings UI to follow a System Settings-style layout:
  - Native AppKit segmented tab control.
  - Grouped rounded sections.
  - Left-aligned row labels.
  - Right-side controls.
- Changed address suggestions to open in a floating popover instead of expanding the settings window height.

## Location Handling

- Added Core Location support.
- Added visible location status messages.
- Added a Request Location button.
- Added manual origin fallback:
  - At Home routes to Work.
  - At Work routes to Home.
- Fixed a dead-end where the app could stay stuck on `Locating`.

## Menu Bar And Popover UI

- Updated the menu bar title to show the live countdown directly, without opening the popover.
- Added smooth numeric text transition for the large countdown text in the popover.
- Added route number display under the blue bus icon.
- Normalized route badge text so `Bus 90` displays as `90`.
- Removed the old route-number row from the route summary.
- Kept the popover focused on:
  - Countdown.
  - Destination subtitle.
  - Route summary.
  - Refresh.
  - Settings.
  - Quit.

## Alerts

- Added departure notifications with sound.
- Added repeating alert behavior until dismissed.
- Fixed the bug where dismissing an alert caused it to immediately pop back up.
- Alert dismissal is now keyed to the current plan’s `leaveAt`, so future departures can still alert normally.

## Startup And Packaging Fixes

- Fixed app bundle launch issue by adding required `CFBundleExecutable` and related bundle keys.
- Fixed issue where startup refresh did not run until clicking the menu icon:
  - Startup now begins from `AppModel.init`.
  - `AppModel.start()` is idempotent to avoid duplicate timers.
- Documented Keychain prompts during development:
  - Repeated prompts are expected with ad-hoc signing.
  - Stable Developer ID/App Store signing should avoid repeated prompts after normal first approval.

## Tests Added

- Destination choice tests.
- Leave-time countdown math tests.
- Countdown alert state tests.
- Adaptive refresh interval tests.
- API key validation tests.
- Google API error message parsing test.
- Route badge normalization tests.
- Alert dismissal state tests.

## Verification Commands Run

The following were run repeatedly during development:

```bash
swift build
swift test
./Scripts/build_app.sh
open -n ".build/app/Transit Minute.app"
codesign --verify --verbose=2 ".build/app/Transit Minute.app"
plutil -lint Packaging/Info.plist
```

Latest verified state:

- `swift build` passes.
- `swift test` passes with 14 tests and 0 failures.
- App bundle builds and launches locally.

## Known Follow-Up Items

- Add stable Developer ID signing when an Apple Developer certificate is available.
- Consider moving from SwiftPM bundle script to a full Xcode project if App Store distribution or notarized DMG packaging becomes the target.
- Add richer manual testing around real Google Routes responses for different cities and transit agencies.
- Consider adding a debug diagnostics panel for current route request, next refresh time, and last Google API error.
