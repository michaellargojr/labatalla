# La Batalla: working notes for changes

Read this before touching the app. It is short on purpose so a change costs few tokens.

## The idea, in one breath

Life is a battle (my grandfather's answer to "how are you?": *la batalla*). The app collects a
little data every day (sleep, a yes or no per goal, minutes, money, and the **reason**) and gives
accountability back: the **calendar** colors every day a goal got anything at all, and
**Insights** says, unasked, where the bottleneck is (too little sleep, too few hours, a plan that
does not fit the week, goals that pull against each other). The **Oracle** is Claude reading all
of it at once, like a general over the battlefield.

The user has ADHD. **No guilt, ever**: no red for misses, no "you broke your streak". A no is
kept as data with its reason, and it never shows on the calendar. Insights state a pattern in
plain numbers and never judge it. The word is always "reason", never "excuse". Daily check-ins
take seconds: taps and dials in 15-minute steps, typing optional. Setting a goal up can be long.

## Where things are

```
ios/LaBatalla/Model/Models.swift    Goal (+ GoalKind, WorkSetup), Mark, SleepLog, MonthPlan, Duel, OracleTurn, Weekday, Schedule, Badge, GoalColor
ios/LaBatalla/Model/Dates.swift     "yyyy-MM-dd" day strings, weeks and months, titles, words ("in 4 weeks")
ios/LaBatalla/Model/Scoring.swift   isDue, summarize -> DaySummary (colors, due, badges), streak, monthStats. Only a yes counts
ios/LaBatalla/Model/Sleep.swift     clockLabel, durationLabel, sleepSpan, sleepStats (averages, debt, short nights)
ios/LaBatalla/Model/Reasons.swift   ReasonSet (the chips offered per kind and answer), reasonCounts, reasonChoices
ios/LaBatalla/Model/Pace.swift      TimePlan (sessions, hours by a date, finish day), progress (week/month/total), planShare, projectedFinish
ios/LaBatalla/Model/Work.swift      money, workTotals (earned, hours, per hour), monthPace, needsMonthPlan, planTitle ("The rest of November")
ios/LaBatalla/Model/Clarity.swift   openQuestions (what a goal's setup left unclear), timeBudget (the 168h week), horizon(for:)
ios/LaBatalla/Model/FaceOff.swift   Head to head: duelable, nextDuel, standings (Said / Chose / Did)
ios/LaBatalla/Model/Insights.swift  InsightInput, insights(_:) -> [Insight] sorted by weight. Every rule the Insights tab shows
ios/LaBatalla/Model/Brief.swift     battlefieldBrief: everything the app knows as plain text, for the Oracle
ios/LaBatalla/Data/Store.swift      AppStore (@Observable): goals, marks, sleep, plans, duels, oracle, settings; every mutation; the JSON file
ios/LaBatalla/Data/Settings.swift   Appearance, BlueScheme, AppIconChoice, WeekStart, Settings (sleep baseline, targets, reminders, currency, model)
ios/LaBatalla/Data/Snapshot.swift   The file format (format 2, lenient decoding, Lossy lists) + JSONFile for the Files sheet
ios/LaBatalla/Data/Oracle.swift     OracleModel, OracleKey (keychain), OracleError, Oracle (prompt, request body, answer parsing, ask)
ios/LaBatalla/Data/Reminder.swift   Three local notifications (morning sleep, evening check-in, the 1st for a job) + NotificationRouter
ios/LaBatalla/Data/Starters.swift   The Ideas sheet's ready-made goals: ones that take hours, and rules that take none
ios/LaBatalla/Data/Sample.swift     DEBUG only: loadSample() (a seeded eight-week life) and the launch arguments
ios/LaBatalla/PrivacyInfo.xcprivacy App Store privacy manifest (UserDefaults reason CA92.1; no tracking, no collection)
ios/LaBatalla/Theme/Theme.swift     Palette (p.bg/card/elevated/text/secondary/muted/line/border/accent/accentSoft/onAccent/onBand), Radius
ios/LaBatalla/Theme/Shapes.swift    StarShape, BattleMark
ios/LaBatalla/Views/Components.swift  Card, FieldBox, SectionLabel, ScreenTitle, PillButton, Chip, RectCheck, GoalIcon, HorizonTag, BadgeChip, StatTile, EmptyNote, .screen()
ios/LaBatalla/Views/Inputs/           Dial (RulerDial, DialRow, DialValues: 15-minute steps), Score (ScoreRow 1 to 10, CountRow, MeterBar, MeterRow), Reason (FlowLayout, ReasonPicker)
ios/LaBatalla/Views/TabBar.swift      AppTab, BattleTabBar, TodayTile, CalendarModeSwitch
ios/LaBatalla/Views/TabBarRoom.swift  Keeps every page's bottom clear of the floating bar
ios/LaBatalla/LaBatallaApp.swift      App + RootView (tabs kept alive in a ZStack, first-run cover, notification routes)
ios/LaBatalla/Views/Onboarding/       OnboardingView: sleep baseline, target bedtime and wake time
ios/LaBatalla/Views/Sleep/            SleepCheckInView: bed, wake, slept, quality, reason
ios/LaBatalla/Views/Calendar/         CalendarView (month + week, prompts, hours against the plan), DayTile (the bands), DaySheet (the check-in)
ios/LaBatalla/Views/Goals/            GoalsView (list, reorder), GoalEditorView (the setup questions), StartersSheet
ios/LaBatalla/Views/Work/             MonthPlanSheet: the month's number and hours a day
ios/LaBatalla/Views/Insights/         InsightsView (+ InsightCard, ImportanceTag), GoalMeters (+ WeekStrip, StandingsTable, SleepChart), FaceOffView
ios/LaBatalla/Views/Oracle/           OracleView: the chat, the key card, Copy my brief
ios/LaBatalla/Views/Settings/         SettingsView, AppIcon (alternate icons), IconPreview
ios/LaBatallaTests/                   Swift Testing, one file per Model file plus Store, Snapshot, Brief and Oracle
tools/make_icons.py                   Draws the icon sets (python3 tools/make_icons.py)
```

Xcode 16 folder-synchronized groups: a new `.swift` file under `ios/LaBatalla/` is in the target
with no project edit. Same for tests under `ios/LaBatallaTests/`. Anything else left in those
folders is pulled into the target too, so keep stray files out.

## The model, briefly

- A goal has a **kind**: `.time` (built in sessions, hours counted), `.adherence` (a rule kept or
  not, no hours), `.work` (a job: hours and money), `.outcome` (a result; never checked in, its
  sub-goals carry it through `parentId`).
- A **Mark** is one answer for one goal on one day: `done` yes or no, minutes, units and amount
  for work, and reasons. `doneByDay` keeps only the yeses, so only they color a day.
- Setup asks importance (1 to 10), three dates (soonest, reasonable, conservative), times a week,
  total hours, session length, how clear the path is, and which goals it pulls against. The six
  months / six years horizon is derived from the reasonable date.
- Work: money per hour is the number that matters. A `MonthPlan` (income + hours a day) is asked
  for at the start of each month, or for "the rest of" it when set mid-month.
- The Oracle sends the brief, the talk so far and the question to Anthropic's Messages API with
  the person's own key. The key lives in the keychain and is never in the export file.

## Conventions

- Days are `"yyyy-MM-dd"` strings everywhere. Make a `Date` only to draw. Helpers live in `Dates.swift`;
  week math always takes the `WeekStart` from `store.settings.weekStart`. Times of day are minutes
  since midnight; durations are minutes.
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
- This repository is public. Sample data and docs stay generic: nobody's real goals or numbers.

## Build and check

No Swift toolchain in the cloud session. Push to a `claude/**` branch and GitHub Actions
(`.github/workflows/ios.yml`, macOS runner) builds the app and runs the tests on a simulator.
Read the log with the Actions tools when it fails. Locally: open `ios/LaBatalla.xcodeproj`, Cmd-U.

To look at the screens without a Mac: put `[screens]` in a commit message. `screens.yml` then
opens the debug app on a simulator with the sample life, takes a picture of each screen, and
commits them to the same branch under `docs/screens/`. Pull, look, fix.

Debug launch arguments (see `DebugLaunch` in `Sample.swift`): `-fresh` (empty, first run),
`-sample` (the sample life), `-tab calendar|goals|insights|settings`, `-screen today|sleep`
(root), `oracle|faceoff|plan` (Insights), `newgoal|ideas|goal|job` (Goals), `-anchor <block id>`
to scroll a page, `-answer` to answer two goals on the Today sheet, `-all` to show every
pattern, `-quiet` to skip the notification permission.

## Adding things, cheaply

- **A setting**: field in `Settings` (+ decode line), a row in `SettingsView` using `Chip`s or a `Toggle`.
- **An insight**: a rule in `insights(_:)` with a stable id, an area and a weight (higher shows
  first), a test in `InsightsTests`. Word it as what happened, with the numbers.
- **A reason chip**: the list for that kind and answer in `ReasonSet`.
- **A new goal field**: property on `Goal` with a default and a decode line, a block in `GoalEditorView`,
  a line in `Brief.swift` so the Oracle sees it, and an `openQuestions` rule if leaving it empty matters.
- **A new badge**: a case in `Badge` (symbol, title, detail), its rule in `summarize`, a line in `monthStats`
  and `monthTotals`, a test in `ScoringTests`.
- **A new tab**: a case in `AppTab`, an `item(...)` in `BattleTabBar`, a `page(...)` in `RootView`.
- **Icons**: change the drawing in `tools/make_icons.py`, run it, commit the PNGs. A new icon set also
  needs a case in `AppIconChoice`, a preview in `IconPreview`, and its name in
  `ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES` in `project.pbxproj`.

## Versions

`MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` in `project.pbxproj` (Debug and Release of the
LaBatalla target), with a matching entry at the top of `ios/CHANGELOG.md`. Rules: `ios/README.md`.
