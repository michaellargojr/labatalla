import Foundation
import Testing
@testable import LaBatalla

// Insights: each rule finds its pattern in data built to hold it, and stays quiet without it.

private let TODAY = "2026-11-11"

private func night(_ day: String, slept: Int, bed: Int = 22 * 60 + 30, quality: Int = 7, reasons: [String] = []) -> SleepLog {
    SleepLog(day: day, bedMinute: bed, wakeMinute: 7 * 60, sleptMinutes: slept, quality: quality, reasons: reasons, at: 1,
             needMinutes: 510, targetBedMinute: 22 * 60 + 30, targetWakeMinute: 7 * 60)
}

private func ids(_ x: InsightInput) -> [String] { insights(x).map(\.id) }

@Suite struct SleepInsightTests {
    @Test func anEmptyAppOnlySaysWhatItIsWaitingFor() {
        #expect(ids(InsightInput(goals: [], marks: [], sleep: [], today: TODAY)) == ["cover.sleep"])
    }

    @Test func shortNightsAndLateBedtimes() throws {
        let nights = daysFrom("2026-11-07", through: TODAY).map { night($0, slept: 420, bed: 23 * 60 + 30) }
        let found = insights(InsightInput(goals: [], marks: [], sleep: nights, today: TODAY))
        let debt = try #require(found.first { $0.id == "sleep.debt" })
        #expect(debt.title == "Sleep is running 1h 30m short a night")
        #expect(debt.area == .sleep)
        #expect(found.contains { $0.id == "sleep.bedtime" })
        #expect(found.first?.id == "sleep.debt")   // the heaviest comes first
        #expect(!found.contains { $0.id == "sleep.ok" })
    }

    @Test func sleepAtTheBaselineSaysSo() {
        let nights = daysFrom("2026-11-05", through: TODAY).map { night($0, slept: 510) }
        let found = ids(InsightInput(goals: [], marks: [], sleep: nights, today: TODAY))
        #expect(found.contains("sleep.ok"))
        #expect(!found.contains("sleep.debt"))
        #expect(!found.contains("cover.sleep"))   // seven nights are in
    }

    @Test func shortNightsCostTheDayAfter() throws {
        let rule = Goal(name: "Walk", schedule: .daily, createdAt: "2026-10-01", kind: .adherence)
        let full = ["2026-11-01", "2026-11-02", "2026-11-03", "2026-11-04"]
        let short = ["2026-11-05", "2026-11-06", "2026-11-07", "2026-11-08"]
        let nights = full.map { night($0, slept: 510) } + short.map { night($0, slept: 400, quality: 4, reasons: ["Late screen"]) }
        let marks = full.map { Mark(goalId: rule.id, day: $0) }
        let found = insights(InsightInput(goals: [rule], marks: marks, sleep: nights, today: TODAY))
        let cost = try #require(found.first { $0.id == "sleep.goals" })
        #expect(cost.title == "Short nights cost the day after")
        #expect(cost.detail.contains("100%"))
        #expect(cost.detail.contains("0%"))
        // Rough nights share a reason, and quality follows hours.
        #expect(found.contains { $0.id == "sleep.reason" && $0.title.contains("Late screen") })
        #expect(found.contains { $0.id == "sleep.quality" })
    }
}

@Suite struct GoalInsightTests {
    @Test func theReasonThatKeepsComingBack() throws {
        let gym = Goal(name: "Gym", schedule: .daily, createdAt: "2026-10-01", kind: .time, sessionMinutes: 60)
        let marks = [Mark(goalId: gym.id, day: "2026-11-05", done: false, reasons: ["Tired"]),
                     Mark(goalId: gym.id, day: "2026-11-06", done: false, reasons: ["Tired"]),
                     Mark(goalId: gym.id, day: "2026-11-07", done: false, reasons: ["Tired"]),
                     Mark(goalId: gym.id, day: "2026-11-08", done: false, reasons: ["No time"])]
        let found = insights(InsightInput(goals: [gym], marks: marks, sleep: [], today: TODAY))
        let reason = try #require(found.first { $0.id == "reason.goal.\(gym.id)" })
        #expect(reason.title == "\"Tired\" is the usual reason for no on Gym")
        #expect(reason.goalId == gym.id)
        #expect(!found.contains { $0.id == "reason.step.\(gym.id)" })
    }

    @Test func notKnowingTheNextStepIsAboutTheGoal() {
        let biz = Goal(name: "Business", schedule: .daily, createdAt: "2026-10-01", kind: .time, sessionMinutes: 60)
        let marks = ["2026-11-05", "2026-11-06"].map { Mark(goalId: biz.id, day: $0, done: false, reasons: [NEXT_STEP_REASON]) }
        #expect(ids(InsightInput(goals: [biz], marks: marks, sleep: [], today: TODAY)).contains("reason.step.\(biz.id)"))
    }

    @Test func aPlanThatIsNotGettingItsHours() {
        let biz = Goal(name: "Business", schedule: .timesPerWeek(3), createdAt: "2026-10-01", kind: .time, importance: 9,
                       reasonable: "2027-03-01", totalHours: 100, sessionMinutes: 60)
        let found = ids(InsightInput(goals: [biz], marks: [], sleep: [], today: TODAY))
        #expect(found.contains("pace.under.\(biz.id)"))
        #expect(found.contains("finish.\(biz.id)"))      // no pace to project yet
        let fresh = Goal(name: "New", schedule: .timesPerWeek(3), createdAt: "2026-11-09", kind: .time, sessionMinutes: 60)
        #expect(!ids(InsightInput(goals: [fresh], marks: [], sleep: [], today: TODAY)).contains("pace.under.\(fresh.id)"))
    }

    @Test func saidOneThingDidAnother() throws {
        let big = Goal(name: "Business", schedule: .daily, createdAt: "2026-10-01", order: 0, kind: .adherence, importance: 10)
        let small = Goal(name: "Language", schedule: .daily, createdAt: "2026-10-01", order: 1, kind: .adherence, importance: 4)
        let marks = daysFrom("2026-10-15", through: TODAY).map { Mark(goalId: small.id, day: $0) }
        let found = insights(InsightInput(goals: [big, small], marks: marks, sleep: [], today: TODAY))
        let gap = try #require(found.first { $0.id == "importance.did" })
        #expect(gap.title.contains("Business 10"))
        #expect(gap.title.contains("Language 4"))
        #expect(gap.goalId == big.id)
    }

    @Test func theLowerNumberWonHeadToHead() {
        let big = Goal(name: "Business", createdAt: "2026-10-01", order: 0, kind: .adherence, importance: 10)
        let small = Goal(name: "Language", createdAt: "2026-10-01", order: 1, kind: .adherence, importance: 6)
        let duel = Duel(a: big.id, b: small.id, winner: small.id)
        #expect(ids(InsightInput(goals: [big, small], marks: [], sleep: [], duels: [duel], today: TODAY)).contains("importance.chose"))
        let other = Duel(a: big.id, b: small.id, winner: big.id)
        #expect(!ids(InsightInput(goals: [big, small], marks: [], sleep: [], duels: [other], today: TODAY)).contains("importance.chose"))
    }

    @Test func aWeekWithMoreHoursThanItHas() {
        var w = WorkSetup()
        w.requiredHours = 18
        let job = Goal(name: "Job", schedule: .daily, createdAt: "2026-10-01", kind: .work, work: w)
        let found = insights(InsightInput(goals: [job], marks: [], sleep: [], today: TODAY))
        #expect(found.first?.id == "time.over")
        #expect(found.contains { $0.id == "work.plan.\(job.id)" })   // and the month has no number yet
    }

    @Test func conflictsWaitForAnAnswer() {
        let steps = Goal(name: "Steps", createdAt: "2026-10-01", order: 0, kind: .adherence, importance: 6)
        var sun = Goal(name: "Sun", createdAt: "2026-10-01", order: 1, kind: .adherence, importance: 5)
        sun.conflicts = [steps.id]
        let key = steps.id < sun.id ? "\(steps.id)|\(sun.id)" : "\(sun.id)|\(steps.id)"
        #expect(ids(InsightInput(goals: [steps, sun], marks: [], sleep: [], today: TODAY)).contains("conflict.\(key)"))
        let duel = Duel(a: steps.id, b: sun.id, winner: sun.id)
        #expect(!ids(InsightInput(goals: [steps, sun], marks: [], sleep: [], duels: [duel], today: TODAY)).contains("conflict.\(key)"))
    }
}

@Suite struct WorkInsightTests {
    @Test func whatAnHourIsWorthAgainstWhatItHasToBe() throws {
        var w = WorkSetup()
        w.unitName = "meeting"
        w.unitValue = 100
        w.targetIncome = 7000
        w.targetHours = 4
        let job = Goal(name: "Sales", schedule: .weekdays(Weekday.workdays), createdAt: "2026-10-01", kind: .work, work: w)
        let plan = MonthPlan(goalId: job.id, month: "2026-11", income: 4200, hoursPerDay: 5, setOn: "2026-11-01")
        let marks = ["2026-11-02", "2026-11-03", "2026-11-04", "2026-11-05", "2026-11-06"].map {
            Mark(goalId: job.id, day: $0, minutes: 300, units: 1)
        }
        let found = insights(InsightInput(goals: [job], marks: marks, sleep: [], plans: [plan], today: "2026-11-09"))
        let rate = try #require(found.first { $0.id == "work.rate.\(job.id)" })
        #expect(rate.title == "Sales is paying $20 an hour. This month's number needs $40.")
        let six = try #require(found.first { $0.id == "work.six.\(job.id)" })
        #expect(six.title.contains("$7,000 a month at 4h a day"))
        #expect(found.contains { $0.id == "work.hours.\(job.id)" })
        #expect(!found.contains { $0.id == "work.plan.\(job.id)" })
    }
}
