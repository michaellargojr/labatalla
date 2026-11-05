# La Batalla: working notes for changes

Read this before touching the app. It is short on purpose so a change costs few tokens.

## The idea, in one breath

Life is a battle (my grandfather's answer to "how are you?": *la batalla*). Every goal matters in
**six months** (short term) or **six years** (long term). Each goal has a **color**. Each day you
do it, the day on the **calendar** gets a **band** of that color. Days earn **badges**: bolt (all
6-month goals asked of the day done), star (all 6-year goals), crown (everything: the battle won).
The user has ADHD. **No guilt, ever**: no red for misses, no "you broke your streak", no counts of
what was not done. A day with nothing is just uncolored. Show what happened, never what did not.

## Where things are

```
ios/LaBatalla/Model/Models.swift    Goal, Mark, Horizon, Weekday, Schedule, Badge, GoalColor, GoalSymbols
ios/LaBatalla/Model/Dates.swift     "yyyy-MM-dd" day strings, weekStart/weekDays/monthGrid, titles, words
ios/LaBatalla/Model/Scoring.swift   isDue, summarize -> DaySummary (colors, due, badges), streak, monthStats
ios/LaBatalla/Data/Store.swift      AppStore (@Observable): goals, marks, settings; toggle/put/archive/reorder; JSON file
ios/LaBatalla/Data/Settings.swift   Appearance, BlueScheme, AppIconChoice, WeekStart, Settings
ios/LaBatalla/Data/Snapshot.swift   The file format (lenient decoding) + JSONFile for the Files sheet
ios/LaBatalla/Data/Starters.swift   The Ideas sheet's ready-made goals
ios/LaBatalla/Data/Reminder.swift   The one daily local notification (UNUserNotificationCenter), synced from Settings
ios/LaBatalla/Data/Sample.swift     DEBUG only: loadSample(), five goals and eight weeks of seeded marks
ios/LaBatalla/PrivacyInfo.xcprivacy App Store privacy manifest (UserDefaults reason CA92.1; no tracking, no collection)
ios/LaBatalla/Theme/Theme.swift     Palette (p.bg/card/elevated/text/secondary/muted/line/border/accent/onAccent/onBand), Radius
ios/LaBatalla/Theme/Shapes.swift    StarShape, BattleMark
ios/LaBatalla/Views/Components.swift  Card, FieldBox, SectionLabel, ScreenTitle, PillButton, Chip, RectCheck, GoalIcon, HorizonTag, BadgeChip, StatTile, EmptyNote, .screen()
ios/LaBatalla/Views/TabBar.swift      AppTab, BattleTabBar, TodayTile, CalendarModeSwitch
ios/LaBatalla/Views/TabBarRoom.swift  Keeps every page's bottom clear of the floating bar
ios/LaBatalla/LaBatallaApp.swift      App + RootView (tabs kept alive in a ZStack, palette into the environment)
ios/LaBatalla/Views/Calendar/         CalendarView (month + week), DayTile (the bands), DaySheet (mark a day)
ios/LaBatalla/Views/Goals/            GoalsView (list, reorder), GoalEditorView, StartersSheet
ios/LaBatalla/Views/Stats/            StatsView (month totals, per-goal runs and 12-week strips)
ios/LaBatalla/Views/Settings/         SettingsView, AppIcon (alternate icons), IconPreview
ios/LaBatallaTests/                   Swift Testing: Dates, Schedule, Scoring, Store, Snapshot
tools/make_icons.py                   Draws the icon sets (python3 tools/make_icons.py)
```

Xcode 16 folder-synchronized groups: a new `.swift` file under `ios/LaBatalla/` is in the target
with no project edit. Same for tests under `ios/LaBatallaTests/`.

## Conventions

- Days are `"yyyy-MM-dd"` strings everywhere. Make a `Date` only to draw. Helpers live in `Dates.swift`;
  week math always takes the `WeekStart` from `store.settings.weekStart`.
- Views read colors from `@Environment(\.palette) private var p`, never raw `Color`s. Goal colors go
  through `p.color(goal.color)`; text over a band is `p.onBand`.
- Everything is a rounded rectangle (`Radius.*`), no circles. Blue means the app; every other color
  means a goal.
- All mutations go through `AppStore` methods, which schedule the save. Never write `store.marks`
  from a view.
- Every Codable type has a lenient `init(from:)` with a default per field, so old and new files
  always open. Keep that when adding a field: add the property, add one `decodeIfPresent` line.
- Copy style: plain, short, matter of fact. Use "-" between items, never an em dash. No scolding.
- Logic goes in `Model/` as free functions with tests; views stay thin.

## Build and check

No Swift toolchain in the cloud session. Push to a `claude/**` branch and GitHub Actions
(`.github/workflows/ios.yml`, macOS runner) builds the app and runs the tests on a simulator.
Read the log with the Actions tools when it fails. Locally: open `ios/LaBatalla.xcodeproj`, Cmd-U.

## Adding things, cheaply

- **A setting**: field in `Settings` (+ decode line), a row in `SettingsView` using `Chip`s or a `Toggle`.
- **A new badge**: a case in `Badge` (symbol, title, detail), its rule in `summarize`, a line in `monthStats`
  and `monthTotals`, a test in `ScoringTests`.
- **A new goal field**: property on `Goal` with a default and a decode line, a block in `GoalEditorView`.
- **A new tab**: a case in `AppTab`, an `item(...)` in `BattleTabBar`, a `page(...)` in `RootView`.
- **Icons**: change the drawing in `tools/make_icons.py`, run it, commit the PNGs. A new icon set also
  needs a case in `AppIconChoice`, a preview in `IconPreview`, and its name in
  `ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES` in `project.pbxproj`.

## Versions

`MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` in `project.pbxproj` (Debug and Release of the
LaBatalla target), with a matching entry at the top of `ios/CHANGELOG.md`. Rules: `ios/README.md`.
