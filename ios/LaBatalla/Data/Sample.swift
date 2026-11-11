#if DEBUG
import Foundation

/// A sample life, eight weeks deep, so a fresh install or a simulator shows every screen with
/// something on it: seven goals of every sort, a job with its month's number, nightly sleep,
/// answers with minutes and reasons, a few head-to-heads. Debug builds only: Settings > Data >
/// Sample data, or the "-sample" launch argument. Everything comes from a fixed seed, so every
/// run draws the same life (handy for screenshots). The patterns in it are put there on purpose,
/// so Insights has something to find: short nights after late screens, a goal rated 10 that gets
/// less of its plan than one rated 4, a job whose hour is worth less than the month needs.
extension AppStore {
    func loadSample(today t: String = today()) {
        var seed: UInt64 = 0x5EED
        func roll() -> Double {
            seed = seed &* 6364136223846793005 &+ 1442695040888963407
            return Double(seed >> 33) / Double(1 << 31)
        }
        func chance(_ p: Double) -> Bool { roll() < p }
        func between(_ lo: Int, _ hi: Int) -> Int { lo + min(hi - lo, Int(roll() * Double(hi - lo + 1))) }
        func pick(_ list: [String]) -> String { list[min(list.count - 1, Int(roll() * Double(list.count)))] }
        func stamp(_ day: String, hour: Int) -> Double { dayDate(day).timeIntervalSince1970 * 1000 + Double(hour) * 3_600_000 }

        let start = addDays(-7 * 8, to: weekStart(t, settings.weekStart))

        var s = settings
        s.onboarded = true
        s.sleepNeedMinutes = 8 * 60 + 30
        s.targetBedMinute = 22 * 60 + 30
        s.targetWakeMinute = 7 * 60

        // The goals.
        let shape = Goal(name: "Best shape of my life", color: .gold, symbol: "flag.checkered", schedule: .daily,
                         why: "To look and feel the way I know I can.", createdAt: start, order: 0,
                         kind: .outcome, importance: 9, finishLine: "Lean and strong, and it shows in the mirror and on the scale.",
                         soonest: addMonthsKeepingDay(5, to: t), reasonable: addMonthsKeepingDay(7, to: t),
                         conservative: addMonthsKeepingDay(10, to: t), clarity: 6)
        let lift = Goal(name: "Lift", color: .royal, symbol: "dumbbell.fill", schedule: .timesPerWeek(4),
                        why: "Strength is the one thing that keeps paying.", createdAt: start, order: 1,
                        kind: .time, parentId: shape.id, importance: 9, sessionMinutes: 60, clarity: 8)
        let eat = Goal(name: "Stop eating when full", color: .coral, symbol: "fork.knife", schedule: .daily,
                       why: "Enough is a decision.", createdAt: start, order: 2,
                       kind: .adherence, parentId: shape.id, importance: 8)
        let steps = Goal(name: "10,000 steps", color: .mint, symbol: "shoeprints.fill", schedule: .daily,
                         why: "The phone counts them; I only answer yes or no.", createdAt: start, order: 3,
                         kind: .adherence, parentId: shape.id, importance: 6)
        var job = WorkSetup()
        job.unitName = "meeting"
        job.unitValue = 90
        job.requiredHours = 6
        job.targetIncome = 7000
        job.targetHours = 4
        let sales = Goal(name: "Sales", color: .sky, symbol: "briefcase.fill", schedule: .weekdays(Weekday.workdays),
                         why: "Earn more, work less.", createdAt: start, order: 4,
                         kind: .work, importance: 9, clarity: 5, work: job)
        let business = Goal(name: "My own business", color: .violet, symbol: "laptopcomputer", schedule: .timesPerWeek(3),
                            why: "Income that does not depend on one employer.", createdAt: start, order: 5,
                            kind: .time, importance: 10, finishLine: "The first paying client.",
                            soonest: addMonthsKeepingDay(3, to: t), reasonable: addMonthsKeepingDay(6, to: t),
                            conservative: addMonthsKeepingDay(12, to: t), totalHours: 300, sessionMinutes: 90,
                            clarity: 3, conflicts: [sales.id])
        let language = Goal(name: "Learn a language", color: .orange, symbol: "character.bubble.fill", schedule: .timesPerWeek(3),
                            why: "A little, often, for a long time.", createdAt: start, order: 6,
                            kind: .time, importance: 4, finishLine: "A ten-minute talk with no English.",
                            soonest: addMonthsKeepingDay(8, to: t), reasonable: addMonthsKeepingDay(14, to: t),
                            conservative: addMonthsKeepingDay(24, to: t), totalHours: 150, sessionMinutes: 30, clarity: 6)
        var all = [shape, lift, eat, steps, sales, business, language]
        for i in all.indices {
            if let r = all[i].reasonable { all[i].horizon = LaBatalla.horizon(for: r, today: t) }
        }

        // The nights. A late one is short, rated lower, and has a reason.
        var nights: [SleepLog] = []
        var short: Set<String> = []
        var d = start
        while d < t {
            if chance(0.92) {
                let weekend = Weekday.weekend.contains(Weekday.of(d))
                let late = chance(weekend ? 0.55 : 0.22)
                let bed = clampMinute(s.targetBedMinute + (late ? between(4, 9) : between(-2, 1)) * 15)
                let wake = clampMinute(s.targetWakeMinute + (late ? between(0, 3) : between(0, 1)) * 15)
                let slept = max(4 * 60, sleepSpan(bed: bed, wake: wake) - between(0, 1) * 15)
                var reasons: [String] = []
                if late { reasons = [pick(["Late screen", "Late screen", "Went to bed late", "Stress"])] }
                else if chance(0.6) { reasons = ["On schedule"] }
                nights.append(SleepLog(day: d, bedMinute: bed, wakeMinute: wake, sleptMinutes: slept,
                                       quality: late ? between(4, 6) : between(7, 9), reasons: reasons, at: stamp(d, hour: 7),
                                       needMinutes: s.sleepNeedMinutes, targetBedMinute: s.targetBedMinute, targetWakeMinute: s.targetWakeMinute))
                if s.sleepNeedMinutes - slept >= SHORT_NIGHT_MINUTES { short.insert(d) }
            }
            d = addDays(1, to: d)
        }

        // The answers. `rate` is how often the answer is yes; `tired` scales it after a short night.
        struct Line {
            let goal: Goal
            let rate: Double
            let tired: Double
            let no: [String]
            let yes: [String]
        }
        let lines = [
            Line(goal: lift, rate: 0.82, tired: 0.7, no: ["Tired", "No time", "Rest day"], yes: ["Routine", "Had energy", "Planned it"]),
            Line(goal: eat, rate: 0.66, tired: 0.75, no: ["Tempted", "Served too much", "Social"], yes: ["Planned it", "Not tempted"]),
            Line(goal: steps, rate: 0.56, tired: 0.8, no: ["Tired", "Forgot", "Not prepared"], yes: ["Routine", "Stayed busy"]),
            Line(goal: sales, rate: 0.93, tired: 1, no: ["Day off", "Sick"], yes: ["Normal day", "Focused", "Slow day"]),
            Line(goal: business, rate: 0.42, tired: 0.35, no: ["Tired", NEXT_STEP_REASON, NEXT_STEP_REASON, "Work ran long", "No time"],
                 yes: ["Made time", "Pushed through"]),
            Line(goal: language, rate: 0.72, tired: 0.8, no: ["Forgot", "No time", "Not in the mood"], yes: ["Routine", "Felt like it"]),
        ]
        var answers: [Mark] = []
        d = start
        while d < t {
            for line in lines {
                let g = line.goal
                var asked = true
                switch g.schedule {
                case .daily: asked = true
                case .weekdays(let days): asked = days.contains(Weekday.of(d))
                case .timesPerWeek(let n): asked = chance(Double(n) / 7 * 1.25)
                }
                // Some days simply go unanswered.
                guard asked, chance(0.88) else { continue }
                let tired = short.contains(d)
                if chance(line.rate * (tired ? line.tired : 1)) {
                    var m = Mark(goalId: g.id, day: d, at: stamp(d, hour: 20))
                    if g.kind == .time {
                        m.minutes = chance(0.1) ? 10 : roundMinutes(g.sessionMinutes * between(60, 120) / 100)
                    } else if g.kind == .work {
                        m.minutes = between(18, 26) * 15
                        m.units = between(0, 3)
                    }
                    if chance(0.55) { m.reasons = [pick(line.yes)] }
                    answers.append(m)
                } else {
                    let reason = tired && chance(0.7) && line.no.contains("Tired") ? "Tired" : pick(line.no)
                    answers.append(Mark(goalId: g.id, day: d, at: stamp(d, hour: 20), done: false, reasons: [reason]))
                }
            }
            d = addDays(1, to: d)
        }

        // The job's numbers: last month's and this month's.
        let lastMonth = addMonths(-1, to: t)
        let numbers = [
            MonthPlan(goalId: sales.id, month: monthKey(lastMonth), income: 3000, hoursPerDay: 6, setOn: lastMonth),
            MonthPlan(goalId: sales.id, month: monthKey(t), income: 3500, hoursPerDay: 6, setOn: monthStart(t)),
        ]

        // A few head-to-heads already decided.
        let decided = [
            Duel(a: business.id, b: sales.id, winner: sales.id, at: stamp(start, hour: 9)),
            Duel(a: business.id, b: language.id, winner: business.id, at: stamp(start, hour: 9)),
            Duel(a: lift.id, b: language.id, winner: lift.id, at: stamp(start, hour: 9)),
            Duel(a: lift.id, b: business.id, winner: lift.id, at: stamp(start, hour: 9)),
        ]

        goals = all
        marks = answers
        sleep = nights
        plans = numbers
        duels = decided
        oracle = []
        settings = s
        saveNow()
    }

    /// Launch arguments, for screenshots and for looking at one screen in a simulator:
    /// "-fresh" starts empty at the first-run questions, "-sample" fills the sample life.
    func applyLaunchArguments() {
        guard !DebugLaunch.applied else { return }
        DebugLaunch.applied = true
        if DebugLaunch.has("-fresh") { reset() }
        if DebugLaunch.has("-sample") { loadSample() }
    }
}

/// What the launch arguments ask for. "-tab goals", "-screen sleep", "-anchor work".
enum DebugLaunch {
    static var applied = false

    static func has(_ flag: String) -> Bool { ProcessInfo.processInfo.arguments.contains(flag) }

    static func value(_ flag: String) -> String? {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: flag), i + 1 < args.count else { return nil }
        return args[i + 1]
    }

    /// The tab to open on.
    static var tab: AppTab? {
        switch value("-tab") {
        case "calendar": return .calendar
        case "goals": return .goals
        case "insights": return .insights
        case "settings": return .settings
        default: return nil
        }
    }

    /// The sheet or page to open on top of it.
    static var screen: String? { value("-screen") }
    /// The block to scroll to.
    static var anchor: String? { value("-anchor") }
}
#endif
