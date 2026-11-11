# La Batalla

An app for the long fight: it collects a little data every day, shows it back as a calendar that fills with color, and says where the bottleneck is without being asked.

The name is my grandfather's. Ask him how he is doing and he always says the same thing: *la batalla*. The battle.

Native iPhone app, SwiftUI, iOS 17 and up. Everything lives on the phone.

## What it does

- **Sleep first.** The first run asks how much sleep you need (everyone's number is different) and your target bedtime and wake time. Each morning the sleep check-in takes a few seconds: when you slept, when you woke, how long, how good from 1 to 10, and the reason. Dials move in 15-minute steps and start near your targets.
- **Goals of four kinds.** Ones that take hours (a project, a skill), rules that take none (eating, drinking, bedtime), work (hours and money), and results that other goals serve. Setting one up asks how important it is from 1 to 10, the soonest, reasonable and conservative dates, how many times a week, how many hours in all, and how clear the path is. The app does the sums: hours per session, hours by each date, the day the plan finishes.
- **The daily check-in** is the tile in the middle of the bar. Did you work on it? Yes or no, how long, and the reason. One tap each; typing is optional.
- **Calendar.** Month and Week views. Each goal has a color; any day it got any time at all gets a band of that color. Under the grid, each goal's hours for the week, the month and in all, against its plan.
- **Work.** A job is tied to dollars and hours. It can pay by the hour, by the result (a commission, a booked meeting), by salary, or a mix. At the start of each month the app asks for the month's number and the hours a day you want to give it, and from then on shows what an hour has been worth against what an hour needs to be worth.
- **Insights** finds the patterns: the sleep you owe, what the short nights cost, the goal rated 10 that gets less of its plan than the one rated 4, a plan that asks for more hours than a week has, goals whose setup left questions open.
- **Head to head** asks one question about two goals at a time: if only one of these could happen, which? It ranks what you chose next to what you said and what you did.
- **The Oracle** is Claude, reading the whole map at once. Ask it what you cannot see from inside the day. It needs your own Anthropic API key, kept in the phone's keychain; without one, Copy my brief puts everything it would read on the clipboard.
- **Settings**: sleep baseline and targets, three optional reminders, currency, the Oracle's key and model, dark or light, royal or tech blue, four app icons, export and import as one JSON file.

## What it never does

No streak-shaming, no red, no "you missed". A no is an answer with a reason, kept as data and never shown on the calendar. A day with nothing marked is just a day without color. Insights say what happened in plain numbers and leave the judging out.

## Run

Open `ios/LaBatalla.xcodeproj` in Xcode 16 or newer, pick an iPhone simulator or your phone, press Run. Details, versions and release notes: `ios/README.md` and `ios/CHANGELOG.md`.

GitHub Actions compiles the app and runs the unit tests on every push that touches `ios/` (`.github/workflows/ios.yml`).

## Layout

```
ios/LaBatalla/Model     The types, the day math, and every rule: scoring, sleep, pace, work, insights, the brief
ios/LaBatalla/Data      AppStore (one JSON file in Documents), Settings, Snapshot, the Oracle's API client, reminders
ios/LaBatalla/Theme     Palette (dark and light, two blues), shapes
ios/LaBatalla/Views     Calendar, Goals, Insights, Settings, the check-ins, the Oracle, shared components
ios/LaBatallaTests      Swift Testing suites for the model, store and file format
tools/make_icons.py     Draws the four app icons into the asset catalog
```

`CLAUDE.md` holds the conventions for anyone (or any assistant) changing the app.

## Trying it

A debug build has **Settings > Data > Sample data**, which replaces what is there with a made-up life: seven goals of every kind, a job with its month's number, eight weeks of nights and answers from a fixed seed. Every screen then has something on it, and Insights has patterns to find. Erase it with **Start over**.

## What leaves the phone

Nothing, until you ask the Oracle a question. Then the brief (your sleep, goals, hours, money and reasons as plain text), the talk so far and the question go to Anthropic's API with your own key, and the answer comes back. The key is stored in the keychain and is never written to the export file.

## Roadmap

1. Install on the phone, live with it for a week, and fix what the week finds.
2. A home-screen widget with the month grid, so the colors are visible without opening the app.
3. Sleep and steps read from Apple Health, so those check-ins fill themselves.
4. A weekly review: one screen on Sunday with the week against the plan and one question from the Oracle.
5. Yearly view: twelve small months on one screen.
6. iCloud backup of the JSON file.
