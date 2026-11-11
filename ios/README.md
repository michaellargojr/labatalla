# La Batalla for iOS

Native SwiftUI app. Requires iOS 17. One target plus its unit tests.

## Open and run

1. Open `ios/LaBatalla.xcodeproj` in Xcode 16 or newer.
2. Pick an iPhone simulator (or your phone) and press Run.
3. For a real phone, set your team under Signing & Capabilities once. Free signing is enough.

The project uses Xcode's folder-synchronized groups, so adding a Swift file under `LaBatalla/`
(or `LaBatallaTests/`) adds it to the target. Nothing to register in the project file.

## Layout

- `LaBatalla/Model`: the types (`Models.swift`), day and week math (`Dates.swift`), and the rules as free functions: what a day earns (`Scoring.swift`), sleep, reasons, pace against a plan, work and money, open questions and the week's hours, head to head, insights, and the Oracle's brief.
- `LaBatalla/Data`: `AppStore` (one JSON file in Documents, written a moment after each change), `Settings`, the `Snapshot` file format, the Oracle's API client and keychain key, the local notifications, `Starters` (the Ideas sheet), and the debug sample life.
- `LaBatalla/Theme`: `Palette` (dark and light, royal or tech blue) and the shapes.
- `LaBatalla/Views`: the four tabs (Calendar, Goals, Insights, Settings), the Today sheet, the sleep check-in, the first-run questions, the Oracle, the dials and reason chips, the floating tab bar, shared components.
- `LaBatallaTests`: Swift Testing suites. Run them with Cmd-U, or let GitHub Actions run them.

## Versions and release notes

- **Version** (`MARKETING_VERSION`) is major.minor.patch, as the App Store shows it. Every install on the phone gets a new one: a new minor (0.2) when it adds or changes something you'd notice, a patch (0.2.1) when it only fixes the last install, 1.0 when it goes to the App Store.
- **Build** (`CURRENT_PROJECT_VERSION`) goes up by one with every install and never resets.
- Both live on the LaBatalla target, Debug and Release.
- Settings shows both at the bottom, read from the app ("La Batalla 0.2 - Build 2").
- **`CHANGELOG.md`** is the record: newest first, a few plain lines per version written for anyone using the app. Internal details go in the HTML comment under each heading. Text style: "-" between items, never an em dash.
- **Each PR** fills in the "Release note" section of the PR template: one plain line, or "None".
- **The install step**: collect the release notes merged since the last entry, add the new version at the top of `CHANGELOG.md`, bump both numbers for Debug and Release, in one commit before building.

## App icons

`tools/make_icons.py` (Python 3 with Pillow) draws all four icon sets into `LaBatalla/Assets.xcassets`: light, dark and tinted 1024 PNGs each. Change the drawing there, run it, commit the PNGs.
