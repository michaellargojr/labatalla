import Foundation
import Testing
@testable import LaBatalla

// When a goal is asked of a day, and how schedules read.

private func goal(_ name: String = "G", _ schedule: Schedule = .daily, horizon: Horizon = .sixYears,
                  created: String = "2026-10-01", archived: String? = nil) -> Goal {
    Goal(name: name, horizon: horizon, schedule: schedule, createdAt: created, archivedAt: archived)
}

@Suite struct ScheduleLabelTests {
    @Test func labels() {
        #expect(Schedule.daily.label == "Every day")
        #expect(Schedule.weekdays(Weekday.workdays).label == "Weekdays")
        #expect(Schedule.weekdays(Weekday.weekend).label == "Weekends")
        #expect(Schedule.weekdays([.monday, .wednesday]).label == "Mon Wed")
        #expect(Schedule.weekdays(Set(Weekday.allCases)).label == "Every day")
        #expect(Schedule.weekdays([]).label == "No days")
        #expect(Schedule.timesPerWeek(1).label == "Once a week")
        #expect(Schedule.timesPerWeek(3).label == "3 times a week")
    }

    @Test func includes() {
        #expect(Schedule.daily.includes("2026-11-07"))
        #expect(Schedule.weekdays(Weekday.workdays).includes("2026-11-05"))
        #expect(!Schedule.weekdays(Weekday.workdays).includes("2026-11-07"))
        #expect(Schedule.timesPerWeek(2).includes("2026-11-07"))
        #expect(Schedule.daily.daysPerWeek == 7)
        #expect(Schedule.weekdays(Weekday.weekend).daysPerWeek == 2)
        #expect(Schedule.timesPerWeek(4).daysPerWeek == 4)
    }

    @Test func roundTrip() throws {
        let g = goal("Lift", .weekdays([.monday, .friday]))
        let data = try JSONEncoder().encode(g)
        let back = try JSONDecoder().decode(Goal.self, from: data)
        #expect(back.schedule == .weekdays([.monday, .friday]))
        let h = goal("Save", .timesPerWeek(2))
        let back2 = try JSONDecoder().decode(Goal.self, from: try JSONEncoder().encode(h))
        #expect(back2.schedule == .timesPerWeek(2))
    }
}

@Suite struct DueTests {
    @Test func dailyAndWeekdays() {
        let d = goal("Daily")
        let w = goal("Weekdays", .weekdays(Weekday.workdays))
        #expect(isDue(d, on: "2026-11-07", done: [:], weekStart: .monday))
        #expect(isDue(w, on: "2026-11-05", done: [:], weekStart: .monday))
        #expect(!isDue(w, on: "2026-11-07", done: [:], weekStart: .monday))
    }

    @Test func activeWindow() {
        let g = goal("Later", created: "2026-11-10")
        #expect(!isDue(g, on: "2026-11-05", done: [:], weekStart: .monday))
        #expect(isDue(g, on: "2026-11-10", done: [:], weekStart: .monday))
        let r = goal("Retired", created: "2026-10-01", archived: "2026-11-03")
        #expect(isDue(r, on: "2026-11-02", done: [:], weekStart: .monday))
        #expect(!isDue(r, on: "2026-11-03", done: [:], weekStart: .monday))
        #expect(!r.isActive(on: "2026-11-04"))
    }

    @Test func timesPerWeekWaitsUntilItMust() {
        // Three times a week, the week of Mon Oct 26 to Sun Nov 1.
        let g = goal("Lift", .timesPerWeek(3))
        #expect(!isDue(g, on: "2026-10-26", done: [:], weekStart: .monday))   // Monday: 7 days left
        #expect(!isDue(g, on: "2026-10-29", done: [:], weekStart: .monday))   // Thursday: 4 days left, 3 needed
        #expect(isDue(g, on: "2026-10-30", done: [:], weekStart: .monday))    // Friday: 3 left, 3 needed
        #expect(isDue(g, on: "2026-11-01", done: [:], weekStart: .monday))    // Sunday
        // One done on Monday: Friday is fine, Saturday is asked.
        let one: DoneByDay = ["2026-10-26": [g.id]]
        #expect(!isDue(g, on: "2026-10-30", done: one, weekStart: .monday))
        #expect(isDue(g, on: "2026-10-31", done: one, weekStart: .monday))
        // Marked that day: asked of it, whatever the count.
        #expect(isDue(g, on: "2026-10-26", done: one, weekStart: .monday))
        // Three done already: nothing more is asked this week.
        let three: DoneByDay = ["2026-10-26": [g.id], "2026-10-27": [g.id], "2026-10-28": [g.id]]
        #expect(!isDue(g, on: "2026-10-31", done: three, weekStart: .monday))
        #expect(!isDue(g, on: "2026-11-01", done: three, weekStart: .monday))
    }

    @Test func timesPerWeekFollowsTheWeekStart() {
        // Twice a week with Sunday weeks: the week of Sun Nov 1 to Sat Nov 7.
        let g = goal("Call", .timesPerWeek(2))
        #expect(!isDue(g, on: "2026-11-05", done: [:], weekStart: .sunday))   // Thursday: 3 left, 2 needed
        #expect(isDue(g, on: "2026-11-06", done: [:], weekStart: .sunday))    // Friday: 2 left
        // With Monday weeks that Friday has 3 days left, so it is not asked yet.
        #expect(!isDue(g, on: "2026-11-06", done: [:], weekStart: .monday))
    }
}
