import Foundation
import Testing
@testable import LaBatalla

// Which colors a day shows, which badges it earns, and how runs count.

private let gym = Goal(id: "gym", name: "Gym", color: .royal, horizon: .sixYears, schedule: .daily, createdAt: "2026-10-01", order: 0)
private let read = Goal(id: "read", name: "Read", color: .gold, horizon: .sixYears, schedule: .daily, createdAt: "2026-10-01", order: 1)
private let inbox = Goal(id: "inbox", name: "Inbox", color: .mint, horizon: .sixMonths, schedule: .weekdays(Weekday.workdays), createdAt: "2026-10-01", order: 2)
private let goals = [gym, read, inbox]

private func marks(_ pairs: [(String, String)]) -> [Mark] {
    pairs.map { Mark(goalId: $0.0, day: $0.1, at: 0) }
}

@Suite struct DaySummaryTests {
    @Test func colorsFollowGoalOrder() {
        let s = summarize("2026-11-05", goals: goals, done: ["2026-11-05": ["inbox", "gym"]], weekStart: .monday)
        #expect(s.colors == [.royal, .mint])
        #expect(s.isColored)
        #expect(s.open.map(\.id) == ["read"])
        #expect(s.due.map(\.id) == ["gym", "read", "inbox"])
    }

    @Test func nothingMarkedIsJustUncolored() {
        let s = summarize("2026-11-05", goals: goals, done: [:], weekStart: .monday)
        #expect(!s.isColored)
        #expect(s.badges.isEmpty)
        #expect(s.topBadge == nil)
        #expect(s.open.count == 3)
    }

    @Test func badgesByHorizon() {
        // Thursday: gym and read are long term, inbox short term.
        let long = summarize("2026-11-05", goals: goals, done: ["2026-11-05": ["gym", "read"]], weekStart: .monday)
        #expect(long.badges == [.longTerm])
        #expect(long.topBadge == .longTerm)
        let short = summarize("2026-11-05", goals: goals, done: ["2026-11-05": ["inbox"]], weekStart: .monday)
        #expect(short.badges == [.shortTerm])
        let half = summarize("2026-11-05", goals: goals, done: ["2026-11-05": ["gym"]], weekStart: .monday)
        #expect(half.badges.isEmpty)
        let all = summarize("2026-11-05", goals: goals, done: ["2026-11-05": ["gym", "read", "inbox"]], weekStart: .monday)
        #expect(all.badges == [.shortTerm, .longTerm, .victory])
        #expect(all.topBadge == .victory)
    }

    @Test func weekendAsksLess() {
        // Saturday: inbox is not asked, so gym and read alone win the day.
        let s = summarize("2026-11-07", goals: goals, done: ["2026-11-07": ["gym", "read"]], weekStart: .monday)
        #expect(s.due.map(\.id) == ["gym", "read"])
        #expect(s.badges == [.longTerm, .victory])
        // Doing inbox anyway still colors the day, and is not asked.
        let extra = summarize("2026-11-07", goals: goals, done: ["2026-11-07": ["inbox"]], weekStart: .monday)
        #expect(extra.colors == [.mint])
        #expect(extra.badges.isEmpty)
    }

    @Test func retiredGoalsKeepTheirColor() {
        var old = read
        old.archivedAt = "2026-11-03"
        let before = summarize("2026-11-02", goals: [gym, old], done: ["2026-11-02": ["gym", "read"]], weekStart: .monday)
        #expect(before.colors == [.royal, .gold])
        #expect(before.badges == [.longTerm, .victory])
        let after = summarize("2026-11-04", goals: [gym, old], done: ["2026-11-04": ["gym"]], weekStart: .monday)
        #expect(after.due.map(\.id) == ["gym"])
        #expect(after.badges == [.longTerm, .victory])
    }

    @Test func manyDaysAtOnce() {
        let ms = marks([("gym", "2026-11-01"), ("gym", "2026-11-02"), ("inbox", "2026-11-02")])
        let sums = summarize(["2026-11-01", "2026-11-02", "2026-11-03"], goals: goals, marks: ms, weekStart: .monday)
        #expect(sums["2026-11-01"]?.colors == [.royal])
        #expect(sums["2026-11-02"]?.colors == [.royal, .mint])
        #expect(sums["2026-11-03"]?.isColored == false)
        #expect(doneByDay(ms)["2026-11-02"] == ["gym", "inbox"])
    }
}

@Suite struct StreakTests {
    @Test func dailyRunCountsBackFromToday() {
        let g = Goal(id: "g", name: "G", schedule: .daily, createdAt: "2026-11-01")
        let broken: DoneByDay = ["2026-11-01": ["g"], "2026-11-02": ["g"], "2026-11-03": ["g"]]
        let s = streak(g, done: broken, weekStart: .monday, today: "2026-11-05")
        #expect(s.current == 0)
        #expect(s.best == 3)
        #expect(s.unit == "day")
        let live: DoneByDay = ["2026-11-01": ["g"], "2026-11-02": ["g"], "2026-11-03": ["g"], "2026-11-04": ["g"]]
        let t = streak(g, done: live, weekStart: .monday, today: "2026-11-05")
        #expect(t.current == 4)   // today is not over, so it does not break the run
        #expect(t.best == 4)
        let withToday = streak(g, done: live.merging(["2026-11-05": ["g"]]) { a, _ in a }, weekStart: .monday, today: "2026-11-05")
        #expect(withToday.current == 5)
        #expect(withToday.currentText == "5 days")
        #expect(Streak(current: 1, best: 1, unit: "day").currentText == "1 day")
    }

    @Test func weekendsDoNotBreakAWeekdayRun() {
        let g = Goal(id: "g", name: "G", schedule: .weekdays(Weekday.workdays), createdAt: "2026-10-26")
        let done: DoneByDay = ["2026-10-30": ["g"], "2026-11-02": ["g"], "2026-11-03": ["g"], "2026-11-04": ["g"]]
        let s = streak(g, done: done, weekStart: .monday, today: "2026-11-05")
        #expect(s.current == 4)
        #expect(s.best == 4)
    }

    @Test func timesPerWeekCountsWeeks() {
        let g = Goal(id: "g", name: "G", schedule: .timesPerWeek(2), createdAt: "2026-10-19")
        let done: DoneByDay = ["2026-10-20": ["g"], "2026-10-22": ["g"], "2026-10-27": ["g"], "2026-10-29": ["g"], "2026-11-03": ["g"]]
        let s = streak(g, done: done, weekStart: .monday, today: "2026-11-05")
        #expect(s.current == 2)   // this week is still open
        #expect(s.best == 2)
        #expect(s.unit == "week")
        let gap: DoneByDay = ["2026-10-20": ["g"], "2026-10-22": ["g"], "2026-11-03": ["g"], "2026-11-04": ["g"]]
        let t = streak(g, done: gap, weekStart: .monday, today: "2026-11-05")
        #expect(t.current == 1)   // last week missed, this week already made
        #expect(t.best == 1)
    }

    @Test func retiredGoalsStopCounting() {
        let g = Goal(id: "g", name: "G", schedule: .daily, createdAt: "2026-11-01", archivedAt: "2026-11-04")
        let done: DoneByDay = ["2026-11-01": ["g"], "2026-11-02": ["g"], "2026-11-03": ["g"]]
        let s = streak(g, done: done, weekStart: .monday, today: "2026-11-10")
        #expect(s.current == 3)
        #expect(s.best == 3)
    }

    @Test func totals() {
        let g = Goal(id: "g", name: "G", createdAt: "2026-10-01")
        let done: DoneByDay = ["2026-10-30": ["g"], "2026-11-02": ["g", "x"], "2026-11-03": ["x"]]
        #expect(totalMarks(g, done: done) == 2)
        #expect(marksInMonth(g, month: "2026-11-15", done: done) == 1)
        #expect(marksInMonth(g, month: "2026-10-15", done: done) == 1)
    }
}

@Suite struct MonthStatsTests {
    @Test func countsOnlyWhatHappened() {
        let ms = marks([("gym", "2026-11-02"), ("read", "2026-11-02"), ("inbox", "2026-11-02"), ("gym", "2026-11-03"), ("read", "2026-11-03")])
        let days = ["2026-11-01", "2026-11-02", "2026-11-03", "2026-11-04"]
        let sums = summarize(days, goals: goals, marks: ms, weekStart: .monday)
        let st = monthStats(days.compactMap { sums[$0] })
        #expect(st.colored == 2)
        #expect(st.victories == 1)
        #expect(st.longTerm == 2)
        #expect(st.shortTerm == 1)
        #expect(st.marks == 5)
        #expect(!st.isEmpty)
        #expect(monthStats([]).isEmpty)
    }

    @Test func words() {
        #expect(coloredText(1) == "1 day colored")
        #expect(coloredText(12) == "12 days colored")
        #expect(victoriesText(1) == "1 battle won")
        #expect(victoriesText(3) == "3 battles won")
        #expect(longTermText(1) == "1 long-term day")
        #expect(shortTermText(4) == "4 short-term days")
    }
}

@Suite struct ColorTests {
    @Test func nextFreeColor() {
        #expect(GoalColor.next(after: []) == .royal)
        #expect(GoalColor.next(after: [.royal]) == .sky)
        #expect(GoalColor.next(after: [.royal, .teal]) == .sky)
        #expect(GoalColor.next(after: GoalColor.allCases) == .royal)
        #expect(GoalColor.next(after: GoalColor.allCases + [.royal]) == .sky)
        #expect(GoalColor.gold.label == "Gold")
        #expect(GoalColor.royal.hex(dark: true) != GoalColor.royal.hex(dark: false))
    }
}
