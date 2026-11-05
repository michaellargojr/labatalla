# La Batalla

A habit tracker built around one idea: life is a battle fought one day at a time, and the way to win it is to keep showing up for the things that matter in the long run.

The name is my grandfather's. Ask him how he is doing and he always says the same thing: *la batalla*. The battle.

Native iPhone app, SwiftUI, iOS 17 and up. Everything lives on the phone.

## What it does

- **Calendar** is the app. Month and Week views. Each goal has a color; each day you do it, that day gets a band of that color. Do three goals, the day shows three bands. Tap any day to see it and mark it, past days included. Today has an outline.
- **The Six.** Every goal answers one question: does it matter in six months, or in six years? Six months is the short term. Six years is the long term, and the long term is the point.
- **Badges.** A day where every 6-year goal asked of it was done earns the star (long-term day). Every 6-month goal, the bolt. Everything, the crown: the battle won. They show in the corner of the day's tile and in the month's totals.
- **Goals** is where you set them: name, horizon, color, symbol, when (every day, some days, or N times a week) and why. Retire a goal and its history stays on the calendar.
- **Today** is the tile in the middle of the bar: today's list, one tap per goal.
- **Progress** shows each goal's run, best run, total days and its last twelve weeks as a strip.
- **Settings**: dark, light or system; royal or tech blue; four app icons; week starting Monday or Sunday; export and import as one JSON file.

## What it never does

No streak-shaming, no red, no "you missed". A day with nothing marked is just a day without color. The calendar filling in is the whole motivation, the same way a gym log fills in.

## Run

Open `ios/LaBatalla.xcodeproj` in Xcode 16 or newer, pick an iPhone simulator or your phone, press Run. Details, versions and release notes: `ios/README.md` and `ios/CHANGELOG.md`.

GitHub Actions compiles the app and runs the unit tests on every push that touches `ios/` (`.github/workflows/ios.yml`).

## Layout

```
ios/LaBatalla/Model     Goal, Mark, Schedule, Badge, GoalColor, the day math, scoring
ios/LaBatalla/Data      AppStore (one JSON file in Documents), Settings, Snapshot, Starters
ios/LaBatalla/Theme     Palette (dark and light, two blues), shapes
ios/LaBatalla/Views     Calendar, Goals, Stats, Settings, tab bar, shared components
ios/LaBatallaTests      Swift Testing suites for the model, store and file format
tools/make_icons.py     Draws the four app icons into the asset catalog
```

`CLAUDE.md` holds the conventions for anyone (or any assistant) changing the app.
