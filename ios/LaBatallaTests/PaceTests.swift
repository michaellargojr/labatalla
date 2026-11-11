import Foundation
import Testing
@testable import LaBatalla

// Hours: what a plan adds up to before it starts, and what the marks add up to once it runs.

@Suite struct TimePlanTests {
    let plan = TimePlan(sessionsPerWeek: 3, totalHours: 120, sessionMinutes: 60)

    @Test func thePlanInNumbers() {
        #expect(plan.weeklyMinutes == 180)
        // Nov 1 to Jan 10 is 70 days: ten weeks, thirty sessions.
        #expect(plan.sessions(from: "2026-11-01", to: "2027-01-10") == 30)
        #expect(plan.sessionMinutesNeeded(from: "2026-11-01", by: "2027-01-10") == 240)
        #expect(plan.hoursBy("2027-01-10", from: "2026-11-01") == 30)
        // 120h at 3h a week is 40 weeks.
        #expect(plan.finishDay(from: "2026-11-01") == "2027-08-08")
    }

    @Test func noRoomNoAnswer() {
        #expect(plan.sessionMinutesNeeded(from: "2026-11-01", by: "2026-11-03") == nil)   // less than one session
        #expect(plan.sessionMinutesNeeded(from: "2026-11-01", by: "2026-10-01") == nil)
        let open = TimePlan(sessionsPerWeek: 3, totalHours: 0, sessionMinutes: 60)
        #expect(open.sessionMinutesNeeded(from: "2026-11-01", by: "2027-01-10") == nil)
        #expect(open.finishDay(from: "2026-11-01") == nil)
    }

    @Test func plannedDaysBySchedule() {
        #expect(plannedDays(.daily, from: "2026-11-01", to: "2026-11-30") == 30)
        #expect(plannedDays(.weekdays(Weekday.workdays), from: "2026-11-01", to: "2026-11-30") == 21)
        #expect(plannedDays(.timesPerWeek(3), from: "2026-11-01", to: "2026-11-30") == 13)
        #expect(plannedDays(.daily, from: "2026-11-30", to: "2026-11-01") == 0)
    }

    @Test func words() {
        #expect(hoursLabel(12) == "12h")
        #expect(hoursLabel(1.5) == "1.5h")
        #expect(hoursLabel(0) == "0h")
        #expect(hoursLabel(2.04) == "2h")
        #expect(percentLabel(0.62) == "62%")
    }
}

@Suite struct ProgressTests {
    let goal = Goal(name: "Build", schedule: .timesPerWeek(3), createdAt: "2026-10-01", kind: .time, totalHours: 100, sessionMinutes: 60)

    private var marks: [Mark] {
        [Mark(goalId: goal.id, day: "2026-11-09", minutes: 60),
         Mark(goalId: goal.id, day: "2026-11-10", minutes: 45),
         Mark(goalId: goal.id, day: "2026-11-03", minutes: 30),
         Mark(goalId: goal.id, day: "2026-10-20", minutes: 120),
         Mark(goalId: goal.id, day: "2026-11-11", done: false, reasons: ["Tired"]),
         Mark(goalId: "other", day: "2026-11-09", minutes: 500)]
    }

    @Test func minutesAndDays() {
        #expect(minutesWorked(goal.id, marks, from: "2026-11-09", to: "2026-11-11") == 105)
        #expect(daysDone(goal.id, marks, from: "2026-11-01", to: "2026-11-30") == 3)   // the no is not a day done
    }

    @Test func weekMonthAndTotal() {
        // 2026-11-11 is a Wednesday; its week is Nov 9 to 15.
        let p = progress(goal, marks: marks, today: "2026-11-11", weekStart: .monday)
        #expect(p.weekMinutes == 105)
        #expect(p.weekTarget == 180)
        #expect(p.monthMinutes == 135)
        #expect(p.monthTarget == 13 * 60)
        #expect(p.totalMinutes == 255)
        #expect(p.totalTarget == 6000)
        #expect(p.weekDays == 2)
        #expect(p.weekDaysTarget == 3)
        #expect(p.monthDays == 3)
        #expect(p.monthDaysTarget == 13)
        #expect(p.totalDays == 4)
    }

    @Test func paceOfTheLastFourWeeks() throws {
        let pace = try #require(recentWeeklyMinutes(goal, marks: marks, today: "2026-11-11"))
        #expect(abs(pace - 63.75) < 0.001)   // 255 minutes over 28 days
        let share = try #require(planShare(goal, marks: marks, today: "2026-11-11"))
        #expect(abs(share - 255.0 / 720.0) < 0.001)   // 12 sessions of an hour were planned
        let finish = try #require(projectedFinish(goal, marks: marks, today: "2026-11-11"))
        #expect(finish > "2028-07-01" && finish < "2028-09-01")
    }

    @Test func tooNewToSay() {
        let fresh = Goal(name: "New", createdAt: "2026-11-09", kind: .time, sessionMinutes: 30)
        #expect(recentWeeklyMinutes(fresh, marks: [], today: "2026-11-11") == nil)
        #expect(planShare(fresh, marks: [], today: "2026-11-11") == nil)
        #expect(projectedFinish(goal, marks: [], today: "2026-11-11") == nil)   // no hours, no pace
    }

    @Test func rulesAreCountedInDays() throws {
        let rule = Goal(name: "No sugar", schedule: .daily, createdAt: "2026-10-01", kind: .adherence)
        let yes = daysFrom("2026-10-29", through: "2026-11-11").map { Mark(goalId: rule.id, day: $0) }
        let share = try #require(planShare(rule, marks: yes, today: "2026-11-11"))
        #expect(share == 0.5)   // 14 of the last 28 days
        let result = Goal(name: "Result", createdAt: "2026-10-01", kind: .outcome)
        #expect(planShare(result, marks: [], today: "2026-11-11") == nil)
    }
}
