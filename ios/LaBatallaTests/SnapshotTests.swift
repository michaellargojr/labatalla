import Foundation
import Testing
@testable import LaBatalla

// The JSON file: round trips, and opening files from older or newer builds without losing them.

@Suite struct SnapshotRoundTripTests {
    @Test func roundTrip() throws {
        let g = Goal(name: "Read", color: .gold, horizon: .sixYears, symbol: "book.fill", schedule: .weekdays([.monday, .thursday]), why: "ten pages", createdAt: "2026-10-01")
        let m = Mark(goalId: g.id, day: "2026-11-05", at: 1_000, note: "ch. 2")
        var settings = Settings()
        settings.appearance = .light
        settings.icon = .paper
        settings.showBadges = false
        let snap = Snapshot(goals: [g], marks: [m], settings: settings)
        let back = try Snapshot.decode(try snap.encoded())
        #expect(back.app == "labatalla")
        #expect(back.format == 1)
        #expect(back.goals == [g])
        #expect(back.marks == [m])
        #expect(back.settings == settings)
        #expect(!back.exportedAt.isEmpty)
    }

    @Test func fileName() {
        #expect(Snapshot.fileName("2026-11-05") == "labatalla-2026-11-05.json")
    }
}

@Suite struct LenientDecodingTests {
    @Test func emptyObjectIsAnEmptyStore() throws {
        let s = try Snapshot.decode(Data("{}".utf8))
        #expect(s.goals.isEmpty)
        #expect(s.marks.isEmpty)
        #expect(s.settings == Settings())
    }

    @Test func goalsFillInWhatIsMissing() throws {
        let json = """
        {"goals": [{"name": "Gym", "color": "plaid", "horizon": "decade", "schedule": {"daily": {}}, "future": 1}],
         "marks": [{"goalId": "x", "day": "2026-11-05", "at": 5}],
         "settings": {"appearance": "light", "weekStart": "friday", "newThing": true}}
        """
        let s = try Snapshot.decode(Data(json.utf8))
        #expect(s.goals.count == 1)
        let g = s.goals[0]
        #expect(g.name == "Gym")
        #expect(g.color == .royal)
        #expect(g.horizon == .sixYears)
        #expect(g.schedule == .daily)
        #expect(g.symbol == "checkmark")
        #expect(!g.id.isEmpty)
        #expect(s.marks.count == 1)
        #expect(s.marks[0].note == nil)
        #expect(s.settings.appearance == .light)
        #expect(s.settings.weekStart == .monday)
        #expect(s.settings.showBadges)
    }

    @Test func brokenSettingsFallBackWhole() throws {
        let s = try Snapshot.decode(Data(#"{"settings": "nope"}"#.utf8))
        #expect(s.settings == Settings())
    }

    @Test func reminderSettingsStayInRange() throws {
        let late = try Snapshot.decode(Data(#"{"settings": {"reminderOn": true, "reminderMinute": 5000}}"#.utf8))
        #expect(late.settings.reminderOn)
        #expect(late.settings.reminderMinute == 24 * 60 - 1)
        let early = try Snapshot.decode(Data(#"{"settings": {"reminderMinute": -5}}"#.utf8))
        #expect(!early.settings.reminderOn)
        #expect(early.settings.reminderMinute == 0)
        #expect(Settings().reminderMinute == 20 * 60)
        #expect(Reminder.timeText(0).contains("12") || Reminder.timeText(0).contains("0"))
    }

    @Test func schedulesEncodeAsTheirCase() throws {
        let data = try JSONEncoder().encode(Goal(name: "G", schedule: .timesPerWeek(2)))
        let text = String(decoding: data, as: UTF8.self)
        #expect(text.contains("timesPerWeek"))
    }
}

@Suite struct VersionLabelTests {
    @Test func labels() {
        #expect(AppVersion.label(version: "0.1", build: "1") == "La Batalla 0.1 - Build 1")
        #expect(AppVersion.label(version: "0.1", build: nil) == "La Batalla 0.1")
        #expect(AppVersion.label(version: nil, build: nil) == "La Batalla")
    }
}

@Suite struct StarterTests {
    @Test func startersMakeGoals() {
        let s = Starters.all[0]
        let g = s.goal(color: .teal)
        #expect(g.name == s.name)
        #expect(g.color == .teal)
        #expect(g.horizon == s.horizon)
        #expect(g.schedule == s.schedule)
        #expect(Set(Starters.all.map(\.name)).count == Starters.all.count)   // names are the ids
        #expect(Starters.all.contains { $0.horizon == .sixMonths })
        #expect(Starters.all.contains { $0.horizon == .sixYears })
    }
}
