import Foundation
import Testing
@testable import LaBatalla

// The store, for everything the check-ins write: answers with minutes and reasons, nights,
// month plans, head-to-heads, the talk with the Oracle. Each test gets its own file.

private func tempURL() -> URL {
    FileManager.default.temporaryDirectory.appendingPathComponent("labatalla-test-\(uid()).json")
}

private func freshStore(_ url: URL = tempURL()) -> AppStore {
    let s = AppStore(fileURL: url)
    s.load()
    return s
}

@Suite struct AnswerTests {
    @Test func yesCarriesThePlannedSession() {
        let s = freshStore()
        let g = Goal(name: "Build", kind: .time, sessionMinutes: 45)
        s.put(g)
        s.answer(g.id, on: "2026-11-05", done: true)
        #expect(s.mark(g.id, on: "2026-11-05")?.done == true)
        #expect(s.mark(g.id, on: "2026-11-05")?.minutes == 45)
        #expect(s.isDone(g.id, on: "2026-11-05"))
        #expect(s.summary("2026-11-05").colors == [g.color])
    }

    @Test func noIsKeptButNeverColorsTheDay() {
        let s = freshStore()
        let g = Goal(name: "Build", kind: .time, sessionMinutes: 45)
        s.put(g)
        s.answer(g.id, on: "2026-11-05", done: false)
        #expect(s.mark(g.id, on: "2026-11-05")?.done == false)
        #expect(s.mark(g.id, on: "2026-11-05")?.minutes == 0)
        #expect(!s.isDone(g.id, on: "2026-11-05"))
        #expect(s.summary("2026-11-05").colors.isEmpty)
        #expect(s.done["2026-11-05"] == nil)
    }

    @Test func changingTheAnswerClearsWhatBelongedToTheOldOne() {
        let s = freshStore()
        let g = Goal(name: "Build", kind: .time, sessionMinutes: 30)
        s.put(g)
        s.answer(g.id, on: "2026-11-05", done: false)
        s.toggleReason("Tired", for: g.id, on: "2026-11-05")
        s.setNote(g.id, on: "2026-11-05", "long day")
        #expect(s.mark(g.id, on: "2026-11-05")?.allReasons == ["Tired", "long day"])
        s.answer(g.id, on: "2026-11-05", done: true)
        #expect(s.marks.count == 1)
        #expect(s.mark(g.id, on: "2026-11-05")?.reasons == [])
        #expect(s.mark(g.id, on: "2026-11-05")?.note == nil)
        #expect(s.mark(g.id, on: "2026-11-05")?.minutes == 30)
        s.clearAnswer(g.id, on: "2026-11-05")
        #expect(s.marks.isEmpty)
    }

    @Test func reasonsToggleAndMinutesStayAboveZero() {
        let s = freshStore()
        let g = Goal(name: "Build", kind: .time, sessionMinutes: 30)
        s.put(g)
        s.answer(g.id, on: "2026-11-05", done: true)
        s.toggleReason("Planned it", for: g.id, on: "2026-11-05")
        s.toggleReason("Had energy", for: g.id, on: "2026-11-05")
        s.toggleReason("Planned it", for: g.id, on: "2026-11-05")
        #expect(s.mark(g.id, on: "2026-11-05")?.reasons == ["Had energy"])
        s.updateMark(g.id, on: "2026-11-05") { $0.minutes = -20 }
        #expect(s.mark(g.id, on: "2026-11-05")?.minutes == 0)
        s.updateMark(g.id, on: "2026-11-06") { $0.minutes = 60 }   // no answer that day: nothing to change
        #expect(s.marks.count == 1)
    }

    @Test func aWorkDayStartsAtTheMonthsHours() {
        let s = freshStore()
        let job = Goal(name: "Sales", schedule: .weekdays(Weekday.workdays), createdAt: "2026-10-01", kind: .work)
        s.put(job)
        #expect(s.defaultMinutes(job.id, on: "2026-11-05") == 480)   // what the job expects, until there is a plan
        #expect(s.jobsNeedingPlan(today: "2026-11-05").map(\.id) == [job.id])
        s.putPlan(MonthPlan(goalId: job.id, month: "2026-11", income: 3000, hoursPerDay: 5, setOn: "2026-11-01"))
        s.putPlan(MonthPlan(goalId: job.id, month: "2026-11", income: 3500, hoursPerDay: 6, setOn: "2026-11-01"))
        #expect(s.plans.count == 1)                                  // one number a month
        #expect(s.plan(for: job.id, month: "2026-11-20")?.income == 3500)
        #expect(s.defaultMinutes(job.id, on: "2026-11-05") == 360)
        #expect(s.jobsNeedingPlan(today: "2026-11-05").isEmpty)
        #expect(s.jobsNeedingPlan(today: "2026-12-01").count == 1)
    }

    @Test func reasonsAreRememberedBySetting() {
        let s = freshStore()
        let build = Goal(name: "Build", kind: .time)
        let rule = Goal(name: "Rule", kind: .adherence)
        s.put(build); s.put(rule)
        s.answer(build.id, on: "2026-11-05", done: false)
        s.toggleReason("Gym closed", for: build.id, on: "2026-11-05")
        s.answer(rule.id, on: "2026-11-05", done: false)
        s.toggleReason("Tempted", for: rule.id, on: "2026-11-05")
        #expect(s.reasonsUsed(.timeNo) == [["Gym closed"]])
        #expect(s.reasonsUsed(.ruleNo) == [["Tempted"]])
        #expect(s.reasonsUsed(.timeYes).isEmpty)
    }
}

@Suite struct SleepStoreTests {
    @Test func oneCheckInPerMorning() {
        let s = freshStore()
        s.update { $0.sleepNeedMinutes = 510 }
        var draft = s.sleepDraft(for: "2026-11-05")
        #expect(draft.quality == 0)                 // not rated yet
        #expect(draft.bedMinute == 22 * 60 + 30)    // the dials start on the targets
        #expect(draft.sleptMinutes == 510)
        #expect(draft.needMinutes == 510)
        draft.quality = 7
        s.putSleep(draft)
        s.putSleep(SleepLog(day: "2026-11-05", bedMinute: 0, wakeMinute: 420, sleptMinutes: 400, quality: 5))
        #expect(s.sleep.count == 1)
        #expect(s.sleepLog(on: "2026-11-05")?.quality == 5)
        #expect(s.sleepDraft(for: "2026-11-05").quality == 5)   // an existing night opens as it was
        #expect(s.sleepByDay["2026-11-05"]?.sleptMinutes == 400)
        #expect(s.firstDay <= "2026-11-05")
        s.deleteSleep(on: "2026-11-05")
        #expect(s.sleep.isEmpty)
    }

    @Test func aNightKeepsTheBaselineItWasLoggedUnder() {
        let s = freshStore()
        s.update { $0.sleepNeedMinutes = 510 }
        var draft = s.sleepDraft(for: "2026-11-05")
        draft.quality = 8
        s.putSleep(draft)
        s.update { $0.sleepNeedMinutes = 450 }
        #expect(s.sleepLog(on: "2026-11-05")?.needMinutes == 510)
        #expect(s.sleepDraft(for: "2026-11-06").needMinutes == 450)
    }
}

@Suite struct GoalLifeTests {
    @Test func achievingKeepsTheEstimates() {
        let s = freshStore()
        let g = Goal(name: "Ship", createdAt: "2026-10-01", kind: .time, reasonable: "2026-12-01")
        s.put(g)
        s.achieve(g.id, on: "2026-11-05")
        #expect(s.goal(g.id)?.achievedAt == "2026-11-05")
        #expect(s.goal(g.id)?.reasonable == "2026-12-01")
        #expect(s.summary("2026-11-05").due.map(\.id) == [g.id])   // still that day's
        #expect(s.summary("2026-11-06").due.isEmpty)
        #expect(s.activeGoals.isEmpty)
        s.unarchive(g.id)
        #expect(s.goal(g.id)?.achievedAt == nil)
        #expect(s.activeGoals.count == 1)
    }

    @Test func deletingLetsGoOfEverythingThatHungOnIt() {
        let s = freshStore()
        let parent = Goal(name: "Parent", kind: .outcome)
        var child = Goal(name: "Child", kind: .time)
        child.parentId = parent.id
        child.conflicts = [parent.id]
        let job = Goal(name: "Job", kind: .work)
        s.put(parent); s.put(child); s.put(job)
        #expect(s.children(of: parent.id).map(\.name) == ["Child"])
        #expect(s.topGoals.map(\.name) == ["Parent", "Job"])
        s.decide(parent.id, child.id, winner: child.id)
        s.decide(child.id, parent.id, winner: parent.id)   // a new answer replaces the old
        s.decide(child.id, job.id, winner: job.id)
        #expect(s.duels.count == 2)
        s.putPlan(MonthPlan(goalId: job.id, month: "2026-11", income: 1, hoursPerDay: 1))
        s.answer(job.id, on: "2026-11-05", done: true)
        s.delete(parent.id)
        #expect(s.goal(child.id)?.parentId == nil)
        #expect(s.goal(child.id)?.conflicts == [])
        #expect(s.duels.count == 1)
        s.delete(job.id)
        #expect(s.duels.isEmpty)
        #expect(s.plans.isEmpty)
        #expect(s.marks.isEmpty)
        #expect(s.topGoals.map(\.name) == ["Child"])
    }

    @Test func aResultIsNeverAskedOfADay() {
        let s = freshStore()
        s.put(Goal(name: "Result", createdAt: "2026-10-01", kind: .outcome))
        #expect(s.summary("2026-11-05").due.isEmpty)
        #expect(s.summary("2026-11-05").badges.isEmpty)
    }

    @Test func theOracleTalkKeepsItsLastSixtyLines() {
        let s = freshStore()
        for i in 0..<65 { s.say(OracleTurn(mine: i % 2 == 0, text: "\(i)")) }
        #expect(s.oracle.count == 60)
        #expect(s.oracle.first?.text == "5")
        s.clearOracle()
        #expect(s.oracle.isEmpty)
    }

    @Test func everythingComesBackFromTheFile() throws {
        let url = tempURL()
        let s = freshStore(url)
        var w = WorkSetup()
        w.unitName = "meeting"
        w.unitValue = 90
        let job = Goal(name: "Sales", schedule: .weekdays(Weekday.workdays), createdAt: "2026-10-01", kind: .work,
                       importance: 9, clarity: 5, work: w)
        let build = Goal(name: "Build", schedule: .timesPerWeek(3), createdAt: "2026-10-01", kind: .time, parentId: job.id,
                         importance: 10, finishLine: "First client", soonest: "2027-01-01", reasonable: "2027-03-01",
                         conservative: "2027-06-01", totalHours: 300, sessionMinutes: 90, clarity: 3, conflicts: [job.id])
        s.put(job); s.put(build)
        s.answer(job.id, on: "2026-11-05", done: true)
        s.updateMark(job.id, on: "2026-11-05") { $0.units = 2; $0.amount = 12.5 }
        s.toggleReason("Focused", for: job.id, on: "2026-11-05")
        s.answer(build.id, on: "2026-11-05", done: false)
        s.putSleep(SleepLog(day: "2026-11-05", bedMinute: 1380, wakeMinute: 420, sleptMinutes: 450, quality: 6, reasons: ["Late screen"], note: "show"))
        s.putPlan(MonthPlan(goalId: job.id, month: "2026-11", income: 3500, hoursPerDay: 6, setOn: "2026-11-01"))
        s.decide(job.id, build.id, winner: job.id)
        s.say(OracleTurn(mine: true, text: "What am I not seeing?"))
        s.update { $0.onboarded = true; $0.sleepNeedMinutes = 510; $0.currency = "P" }
        s.saveNow()

        let again = freshStore(url)
        #expect(again.goals == s.goals)
        #expect(again.marks == s.marks)
        #expect(again.sleep == s.sleep)
        #expect(again.plans == s.plans)
        #expect(again.duels == s.duels)
        #expect(again.oracle == s.oracle)
        #expect(again.settings == s.settings)
        try? FileManager.default.removeItem(at: url)
    }
}
