import Foundation
import Testing
@testable import LaBatalla

// What a goal's setup leaves open, the week's budget, and which horizon a date falls in.

@Suite struct OpenQuestionTests {
    private let today = "2026-11-11"

    private func keys(_ g: Goal, goals: [Goal] = [], duels: [Duel] = []) -> [String] {
        openQuestions(g, goals: goals, duels: duels, today: today).map { $0.id.replacingOccurrences(of: g.id + ".", with: "") }
    }

    private func complete() -> Goal {
        Goal(name: "Ship it", schedule: .timesPerWeek(3), createdAt: "2026-10-01", kind: .time, importance: 8,
             finishLine: "It is in the store.", soonest: "2027-01-01", reasonable: "2027-03-01", conservative: "2027-06-01",
             totalHours: 40, sessionMinutes: 60, clarity: 8)
    }

    @Test func aBlankGoalLeavesEverythingOpen() {
        #expect(keys(Goal(name: "X", kind: .time)) == ["finish", "importance", "dates", "session", "path"])
    }

    @Test func aCompleteGoalLeavesNothing() {
        #expect(keys(complete()).isEmpty)
    }

    @Test func aRuleIsAskedLess() {
        #expect(keys(Goal(name: "No sugar", kind: .adherence, importance: 7)).isEmpty)
        #expect(keys(Goal(name: "No sugar", kind: .adherence)) == ["importance"])
    }

    @Test func datesThatDoNotAddUp() {
        var g = complete()
        g.soonest = "2027-04-01"
        #expect(keys(g) == ["order"])
        g.soonest = "2027-03-01"; g.conservative = "2027-03-01"
        #expect(keys(g) == ["same"])
        g = complete()
        g.conservative = nil
        #expect(keys(g) == ["dates"])
        g = complete()
        g.soonest = "2026-08-01"; g.reasonable = "2026-10-01"
        #expect(keys(g).contains("passed"))
    }

    @Test func aPlanThatDoesNotReach() {
        var g = complete()
        g.totalHours = 500   // three hours a week reaches about 47 by March
        #expect(keys(g) == ["reach", "long"])
        g.importance = 3
        #expect(keys(g).contains("low"))
        g.clarity = 2
        #expect(keys(g).contains("unclear"))
    }

    @Test func aJobNeedsItsNumbers() {
        let bare = Goal(name: "Sales", kind: .work, importance: 8, clarity: 7)
        #expect(keys(bare) == ["income", "pay"])
        var w = WorkSetup()
        w.targetIncome = 7000
        w.hourlyRate = 30
        let set = Goal(name: "Sales", kind: .work, importance: 8, clarity: 7, work: w)
        #expect(keys(set).isEmpty)
    }

    @Test func conflictsAskWhoWins() {
        let other = Goal(name: "Sun", kind: .adherence, importance: 5)
        var g = Goal(name: "Steps", kind: .adherence, importance: 6)
        g.conflicts = [other.id]
        let open = openQuestions(g, goals: [other], today: today)
        #expect(open.count == 1)
        #expect(open[0].id == "\(g.id).conflict.\(other.id)")
        #expect(open[0].detail.contains("Which one wins"))
        let decided = openQuestions(g, goals: [other], duels: [Duel(a: g.id, b: other.id, winner: other.id)], today: today)
        #expect(decided[0].detail.contains("you chose Sun"))
    }

    @Test func finishedGoalsAskNothing() {
        var g = Goal(name: "X", kind: .time)
        g.archivedAt = "2026-11-01"
        #expect(keys(g).isEmpty)
    }
}

@Suite struct BudgetTests {
    @Test func theWeekIn168Hours() {
        var w = WorkSetup()
        w.requiredHours = 8
        let job = Goal(name: "Job", schedule: .weekdays(Weekday.workdays), createdAt: "2026-10-01", kind: .work, work: w)
        let build = Goal(name: "Build", schedule: .timesPerWeek(3), createdAt: "2026-10-01", kind: .time, sessionMinutes: 60)
        let rule = Goal(name: "Rule", createdAt: "2026-10-01", kind: .adherence)
        let b = timeBudget(goals: [job, build, rule], sleepNeed: 510, today: "2026-11-11")
        #expect(b.sleep == 3570)
        #expect(b.work == 2400)
        #expect(b.goals == 180)
        #expect(b.left == 10080 - 6150)
        #expect(b.leftPerDay == 561)
    }

    @Test func retiredGoalsTakeNoHours() {
        var old = Goal(name: "Old", schedule: .daily, createdAt: "2026-10-01", kind: .time, sessionMinutes: 120)
        old.archivedAt = "2026-11-01"
        #expect(timeBudget(goals: [old], sleepNeed: 480, today: "2026-11-11").goals == 0)
    }

    @Test func horizonFromTheReasonableDate() {
        #expect(horizon(for: "2027-03-01", today: "2026-11-11") == .sixMonths)
        #expect(horizon(for: "2027-05-11", today: "2026-11-11") == .sixMonths)
        #expect(horizon(for: "2027-06-21", today: "2026-11-11") == .sixYears)
    }
}
