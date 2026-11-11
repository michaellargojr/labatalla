import Foundation
import Testing
@testable import LaBatalla

// The file format's new parts, the brief, the Oracle's request and answer, the notifications,
// and the newer date words.

private let TODAY = "2026-11-11"

@Suite struct NewFileFormatTests {
    @Test func aBrokenNightDoesNotTakeTheOthers() throws {
        let json = """
        {"sleep": [{"day": "2026-11-10", "sleptMinutes": 450, "quality": 7}, {"quality": 3}, "nope",
                   {"day": "2026-11-11", "sleptMinutes": 9999, "quality": 40, "bedMinute": -30}],
         "plans": [{"goalId": "g", "month": "2026-11", "income": 3000}, {"month": "2026-11"}],
         "duels": [{"a": "x", "b": "y", "winner": "x"}, {"a": "x"}],
         "oracle": [{"text": "hello"}, 7]}
        """
        let s = try Snapshot.decode(Data(json.utf8))
        #expect(s.sleep.map(\.day) == ["2026-11-10", "2026-11-11"])
        #expect(s.sleep[0].sleptMinutes == 450)
        #expect(s.sleep[0].needMinutes == 480)
        #expect(s.sleep[1].sleptMinutes == 24 * 60)
        #expect(s.sleep[1].quality == 10)
        #expect(s.sleep[1].bedMinute == 23 * 60 + 30)
        #expect(s.plans.count == 1)
        #expect(s.plans[0].hoursPerDay == 8)
        #expect(s.duels.count == 1)
        #expect(s.oracle.count == 1)
        #expect(s.oracle[0].mine)
    }

    @Test func anOldFileOpensAsRulesAndYeses() throws {
        let json = """
        {"goals": [{"name": "Gym", "schedule": {"daily": {}}}],
         "marks": [{"goalId": "x", "day": "2026-11-05"}]}
        """
        let s = try Snapshot.decode(Data(json.utf8))
        #expect(s.goals[0].kind == .adherence)
        #expect(s.goals[0].importance == 0)
        #expect(s.goals[0].conflicts.isEmpty)
        #expect(s.marks[0].done)
        #expect(s.marks[0].minutes == 0)
        #expect(s.marks[0].reasons.isEmpty)
        #expect(s.sleep.isEmpty)
        #expect(!s.settings.onboarded)
    }

    @Test func newSettingsStayInRange() throws {
        let odd = try Snapshot.decode(Data(#"{"settings": {"sleepNeedMinutes": 30, "currency": "", "oracleModel": "", "targetWakeMinute": 1500}}"#.utf8))
        #expect(odd.settings.sleepNeedMinutes == 3 * 60)
        #expect(odd.settings.currency == "$")
        #expect(odd.settings.oracleModel == OracleModel.fallback)
        #expect(odd.settings.targetWakeMinute == 60)
        let long = try Snapshot.decode(Data(#"{"settings": {"sleepNeedMinutes": 5000}}"#.utf8))
        #expect(long.settings.sleepNeedMinutes == 14 * 60)
    }

    @Test func everythingRoundTrips() throws {
        var job = WorkSetup()
        job.unitName = "meeting"
        job.unitValue = 90
        let g = Goal(name: "Sales", schedule: .weekdays(Weekday.workdays), createdAt: "2026-10-01", kind: .work, importance: 9, work: job)
        let no = Mark(goalId: g.id, day: "2026-11-10", at: 5, done: false, reasons: ["Day off"])
        let yes = Mark(goalId: g.id, day: "2026-11-11", at: 6, minutes: 300, units: 2, amount: 40, reasons: ["Focused"])
        let night = SleepLog(day: "2026-11-11", bedMinute: 23 * 60, wakeMinute: 7 * 60, sleptMinutes: 465, quality: 7, reasons: ["On schedule"], at: 7)
        let plan = MonthPlan(goalId: g.id, month: "2026-11", income: 3500, hoursPerDay: 6, setOn: "2026-11-11")
        let duel = Duel(a: g.id, b: "other", winner: g.id, at: 8)
        let turn = OracleTurn(mine: false, text: "The bottleneck is sleep.", at: 9)
        var settings = Settings()
        settings.onboarded = true
        settings.sleepNeedMinutes = 510
        settings.currency = "\u{20B1}"
        let snap = Snapshot(goals: [g], marks: [no, yes], settings: settings, sleep: [night], plans: [plan], duels: [duel], oracle: [turn])
        let back = try Snapshot.decode(try snap.encoded())
        #expect(back.goals == [g])
        #expect(back.marks == [no, yes])
        #expect(back.sleep == [night])
        #expect(back.plans == [plan])
        #expect(back.duels == [duel])
        #expect(back.oracle == [turn])
        #expect(back.settings == settings)
    }
}

@Suite struct BriefTests {
    @Test func anEmptyLifeStillMakesABrief() {
        let brief = battlefieldBrief(InsightInput(goals: [], marks: [], sleep: [], today: TODAY))
        #expect(brief.hasPrefix("LA BATALLA - battlefield brief for Nov 11, 2026 (Wednesday)"))
        #expect(brief.contains("GOALS: none set yet."))
        #expect(brief.contains("No nights logged in the last 30 days."))
        #expect(brief.contains("- Sleep at the baseline: 56h"))
        #expect(!brief.contains("\u{2014}"))
    }

    @Test func theBriefNamesWhatItKnows() {
        let lift = Goal(name: "Lift", schedule: .timesPerWeek(4), createdAt: "2026-10-01", order: 0, kind: .time, importance: 9, sessionMinutes: 60)
        let read = Goal(name: "Read", schedule: .daily, createdAt: "2026-10-01", order: 1, kind: .adherence, importance: 4)
        var done = Goal(name: "Run a 10k", createdAt: "2026-09-01", order: 2, kind: .time)
        done.achievedAt = "2026-11-01"
        done.archivedAt = "2026-11-02"
        let marks = [Mark(goalId: lift.id, day: "2026-11-10", minutes: 60, reasons: ["Routine"]),
                     Mark(goalId: read.id, day: "2026-11-10", done: false, reasons: ["Tired"])]
        let duel = Duel(a: lift.id, b: read.id, winner: lift.id)
        let brief = battlefieldBrief(InsightInput(goals: [lift, read, done], marks: marks, sleep: [], duels: [duel], today: TODAY))
        #expect(brief.contains("GOALS (2 active)"))
        #expect(brief.contains("Lift"))
        #expect(brief.contains("Read"))
        #expect(brief.contains("ACHIEVED"))
        #expect(brief.contains("- Run a 10k, done Nov 1, 2026"))
        #expect(brief.contains("HEAD TO HEAD"))
        #expect(brief.contains("- Lift: won 1 of 1, rated 9/10"))
        #expect(brief.contains("- Goals that take hours: 4h"))
        #expect(brief.contains("Tired"))
    }
}

@Suite struct OracleRequestTests {
    @Test func thePromptHoldsTheBriefTheTalkAndTheQuestion() {
        let first = Oracle.prompt(brief: "B", transcript: [], question: "Q")
        #expect(first == "<brief>\nB\n</brief>\n\n<question>\nQ\n</question>")
        let talk = [OracleTurn(mine: true, text: "one"), OracleTurn(mine: false, text: "two")]
        let later = Oracle.prompt(brief: "B", transcript: talk, question: "Q")
        #expect(later.contains("<talk_so_far>\nPerson: one\n\nOracle: two\n</talk_so_far>"))
        #expect(later.hasSuffix("<question>\nQ\n</question>"))
    }

    @Test func onlyTheLastTurnsAreSent() {
        let talk = (1...20).map { OracleTurn(mine: $0 % 2 == 1, text: "turn \($0).") }
        let prompt = Oracle.prompt(brief: "B", transcript: talk, question: "Q")
        #expect(!prompt.contains("turn 8."))
        #expect(prompt.contains("turn 9."))
        #expect(prompt.contains("turn 20."))
    }

    @Test func theBodyIsOneUserMessage() throws {
        let body = Oracle.body(model: "claude-opus-5-5", prompt: "P", fallbacks: true)
        #expect(body["model"] as? String == "claude-opus-5-5")
        #expect(body["max_tokens"] as? Int == Oracle.maxTokens)
        #expect(body["fallbacks"] as? String == "default")
        #expect((body["system"] as? String)?.isEmpty == false)
        let messages = try #require(body["messages"] as? [[String: String]])
        #expect(messages.count == 1)
        #expect(messages[0]["role"] == "user")
        #expect(messages[0]["content"] == "P")
        #expect(JSONSerialization.isValidJSONObject(body))
        let plain = Oracle.body(model: "claude-haiku-5-5", prompt: "P", fallbacks: false)
        #expect(plain["fallbacks"] == nil)
    }

    @Test func theAnswerIsTheTextBlocks() throws {
        let json = #"{"stop_reason": "end_turn", "content": [{"type": "thinking", "thinking": "hm"}, {"type": "text", "text": " Sleep first. "}, {"type": "text", "text": "Then the plan."}]}"#
        #expect(try Oracle.answer(from: Data(json.utf8)) == "Sleep first. \nThen the plan.")
    }

    @Test func aDeclineAndAnEmptyAnswerAreSaid() {
        #expect(throws: OracleError.refused) {
            try Oracle.answer(from: Data(#"{"stop_reason": "refusal", "content": []}"#.utf8))
        }
        #expect(throws: OracleError.empty) {
            try Oracle.answer(from: Data(#"{"stop_reason": "end_turn", "content": [{"type": "text", "text": "  "}]}"#.utf8))
        }
        #expect(throws: OracleError.empty) {
            try Oracle.answer(from: Data("not json".utf8))
        }
    }

    @Test func errorsReadPlainly() {
        let data = Data(#"{"type": "error", "error": {"type": "invalid_request_error", "message": "max_tokens is too large"}}"#.utf8)
        #expect(Oracle.errorMessage(from: data) == "max_tokens is too large")
        #expect(Oracle.errorMessage(from: Data("oops".utf8)) == "")
        #expect(OracleError.http(401, "x").words.contains("key"))
        #expect(OracleError.http(429, "").words.contains("Try again"))
        #expect(OracleError.http(500, "").words.contains("500"))
        #expect(OracleError.http(400, "bad thing").words == "The API answered: bad thing")
        #expect(OracleError.noKey.words.contains("Settings"))
        #expect(OracleError.network("Offline.").words.hasSuffix("Offline."))
    }

    @Test func modelsAndStarters() {
        #expect(OracleModel.choice("claude-sonnet-5-5").label == "Sonnet")
        #expect(OracleModel.choice("something else").id == OracleModel.fallback)
        #expect(Set(OracleModel.all.map(\.id)).count == OracleModel.all.count)
        #expect(Oracle.starters(hasWork: true).count == Oracle.starters(hasWork: false).count + 1)
        #expect(Oracle.starters(hasWork: true).contains("How do I earn more per hour?"))
    }
}

@Suite struct ReminderPlanTests {
    @Test func nothingIsPlannedUntilTurnedOn() {
        var s = Settings()
        s.monthStartReminder = false
        #expect(Reminder.planned(s, hasWork: true).isEmpty)
        #expect(Reminder.planned(Settings(), hasWork: false).isEmpty)
    }

    @Test func eachNudgeHasItsTimeAndItsScreen() throws {
        var s = Settings()
        s.morningCheckIn = true
        s.reminderOn = true
        s.reminderMinute = 20 * 60 + 30
        s.targetWakeMinute = 6 * 60 + 50
        let planned = Reminder.planned(s, hasWork: true)
        #expect(planned.map(\.id) == [Reminder.morning, Reminder.evening, Reminder.month])
        let morning = try #require(planned.first { $0.id == Reminder.morning })
        #expect(morning.hour == 7)
        #expect(morning.minute == 5)
        #expect(morning.day == nil)
        #expect(morning.route == .sleep)
        let evening = try #require(planned.first { $0.id == Reminder.evening })
        #expect(evening.hour == 20)
        #expect(evening.minute == 30)
        #expect(evening.title == DEFAULT_MANTRA)
        #expect(evening.route == .today)
        let month = try #require(planned.first { $0.id == Reminder.month })
        #expect(month.day == 1)
        #expect(month.hour == 7)
        #expect(month.minute == 50)
    }

    @Test func theMonthNudgeNeedsAJob() {
        #expect(Reminder.planned(Settings(), hasWork: true).map(\.id) == [Reminder.month])
        #expect(Reminder.morningMinute(wake: 23 * 60 + 50) == 5)
    }
}

@Suite struct NewDateWordsTests {
    @Test func months() {
        #expect(monthKey("2026-11-11") == "2026-11")
        #expect(monthEnd("2026-11-11") == "2026-11-30")
        #expect(monthEnd("2028-02-03") == "2028-02-29")
        #expect(addMonthsKeepingDay(6, to: "2026-08-31") == "2027-02-28")
        #expect(addMonthsKeepingDay(1, to: "2026-11-11") == "2026-12-11")
    }

    @Test func runsOfDays() {
        #expect(daysFrom("2026-11-29", through: "2026-12-01") == ["2026-11-29", "2026-11-30", "2026-12-01"])
        #expect(daysFrom("2026-11-11", through: "2026-11-11") == ["2026-11-11"])
        #expect(daysFrom("2026-11-12", through: "2026-11-11").isEmpty)
    }

    @Test func words() {
        #expect(mediumDay("2027-06-21") == "Jun 21, 2027")
        #expect(briefDay("2027-06-21", today: TODAY) == "Jun 21, 2027")
        #expect(!briefDay("2026-12-25", today: TODAY).contains("2026"))
        #expect(distanceWords(TODAY, today: TODAY) == "today")
        #expect(distanceWords("2026-11-12", today: TODAY) == "in 1 day")
        #expect(distanceWords("2026-11-01", today: TODAY) == "10 days ago")
        #expect(distanceWords("2026-12-11", today: TODAY) == "in 4 weeks")
        #expect(distanceWords("2027-05-11", today: TODAY) == "in 6 months")
        #expect(Weekday.of(TODAY).full == "Wednesday")
    }
}

@Suite struct KindsOnTheCalendarTests {
    @Test func aNoNeverColorsADay() {
        let g = Goal(name: "Walk", schedule: .daily, createdAt: "2026-10-01", kind: .adherence)
        let marks = [Mark(goalId: g.id, day: "2026-11-10", done: false, reasons: ["Tired"]),
                     Mark(goalId: g.id, day: "2026-11-11")]
        let done = doneByDay(marks)
        #expect(done["2026-11-10"] == nil)
        #expect(done["2026-11-11"] == [g.id])
    }

    @Test func anOutcomeIsNeverAskedOfADay() {
        let big = Goal(name: "Best shape", schedule: .daily, createdAt: "2026-10-01", kind: .outcome)
        let small = Goal(name: "Walk", schedule: .daily, createdAt: "2026-10-01", kind: .adherence)
        #expect(!isDue(big, on: TODAY, done: [:], weekStart: .monday))
        #expect(isDue(small, on: TODAY, done: [:], weekStart: .monday))
    }

    @Test func ideasComeInBothSorts() {
        let hours = Starters.all.filter { $0.kind == .time }
        let rules = Starters.all.filter { $0.kind == .adherence }
        #expect(!hours.isEmpty)
        #expect(!rules.isEmpty)
        #expect(hours.allSatisfy { $0.minutes > 0 })
        #expect(hours.allSatisfy { $0.goal(color: .teal).sessionMinutes == $0.minutes })
        #expect(rules.allSatisfy { $0.goal(color: .teal).sessionMinutes == 0 })
    }
}
