# Transit Minute

Transit Minute is a native macOS menu bar app that tells you when to leave for transit between Home and Work.

It watches the next Google Routes transit option, subtracts your walk time and preferred buffer, and keeps the answer visible in the menu bar so you can glance up and know whether you have time.

## What it does

- Shows a live menu bar countdown such as `12 min`, `1 min`, or `Leave now`.
- Plans transit between saved Home and Work locations.
- Uses Google Places Autocomplete for address setup.
- Uses your current location to decide whether you are routing home or to work.
- Falls back to a manual Home/Work origin when location is unavailable.
- Lets Google Routes choose supported transit options and displays bus, subway, rail, or generic transit icons.
- Highlights urgency in the menu bar: orange under 5 minutes and red under 2 minutes.
- Can send repeating macOS notifications when it is time to leave.
- Includes a diagnostics view for the latest route request, refresh timing, and Google API errors.
- Stores your Google API key in macOS Keychain.

## Requirements

- macOS 14 or newer.
- Xcode with the Swift 6 toolchain.
- A Google Cloud API key with these APIs enabled:
  - Places API
  - Routes API

## Local development

Clone the repo and enter the project:

```bash
git clone https://github.com/Zhenghangxu/widget-transit-minute.git
cd widget-transit-minute
```

Run the test suite:

```bash
swift test
```

Run the executable directly from Swift Package Manager:

```bash
swift run TransitMinute
```

For normal menu bar testing, build and launch a real `.app` bundle:

```bash
./Scripts/build_app.sh
open ".build/app/Transit Minute.app"
```

The app bundle is written to:

```text
.build/app/Transit Minute.app
```

## First-run setup

1. Create or select a Google Cloud project.
2. Enable Places API and Routes API.
3. Create an API key in Google Cloud Credentials.
4. Open Transit Minute settings and paste the key into the Google API key field.
5. Save Home and Work using address search or the current location button.
6. Grant macOS location permission if you want Transit Minute to choose the direction automatically.
7. Configure alerts and buffer minutes in the Alerts tab.

For local test builds, leave Google API key application restrictions unset until the bundle identifier and signing setup are finalized. You can still restrict the key to Places API and Routes API.

## Development notes

Transit Minute is a Swift Package with two main targets:

- `TransitMinute`: the macOS menu bar executable.
- `TransitMinuteCore`: route planning, countdown, transit display, diagnostics, and testable domain logic.

Tests live in `Tests/TransitMinuteCoreTests` and can be run with:

```bash
swift test
```

`Scripts/build_app.sh` builds the Swift package product, copies it into a local `.app` bundle, installs `Packaging/Info.plist`, and signs the app.

By default, local builds use ad-hoc signing. That is enough to launch the app locally, but macOS Keychain may ask for permission again after rebuilds because the code signature changes. To use a stable signing identity:

```bash
security find-identity -v -p codesigning
SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" ./Scripts/build_app.sh
```

`Packaging/Info.plist` contains the app bundle metadata and location usage strings. `Packaging/TransitMinute.entitlements` is used when signing the local app bundle.

## Distribution builds

For Developer ID distribution outside the App Store, build a signed DMG:

```bash
SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" ./Scripts/build_dmg.sh
```

To submit the DMG for notarization, provide a notarytool keychain profile:

```bash
SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" NOTARY_PROFILE="your-notarytool-profile" ./Scripts/build_dmg.sh
```

The DMG script requires a valid Developer ID Application certificate. Without `NOTARY_PROFILE`, it creates a signed but unnotarized DMG.

## Troubleshooting

### Xcode license

If Swift or Xcode reports that the license has not been accepted, run:

```bash
sudo xcodebuild -license
```

### Google API errors

Make sure the API key is valid and that both Places API and Routes API are enabled for the Google Cloud project. If the key is restricted, verify that the restrictions allow both APIs.

### Keychain prompts after rebuilds

The Google API key is stored in macOS Keychain. Repeated prompts during development usually mean the app was rebuilt with a different ad-hoc code signature, so Keychain no longer sees it as the same trusted app. A stable Developer ID or App Store signing identity should reduce those prompts for the same installed app.

### Location permission

Transit Minute can still run without current-location access by using the manual origin control. If automatic direction detection is not working, check macOS System Settings and confirm that location access is allowed for the app build you are running.
