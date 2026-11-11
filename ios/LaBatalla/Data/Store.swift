import Foundation
import Observation

/// Single source of truth. Everything lives in memory and is written to one JSON file in
/// Documents (the same shape as an export), a moment after each change.
@Observable
final class AppStore {
    var goals: [Goal] = []
    var marks: [Mark] = []
    var sleep: [SleepLog] = []
    var plans: [MonthPlan] = []
    var duels: [Duel] = []
    var oracle: [OracleTurn] = []
    var settings = Settings()
    /// True once the file has been read, or found missing. Nothing is saved before then, so the
    /// file can never be replaced by an empty store.
    var loaded = false

    private let fileURL: URL
    @ObservationIgnored private var saveTask: Task<Void, Never>?

    /// A store with its own file (tests) never touches the app's data.
    init(fileURL: URL? = nil) {
        self.fileURL = fileURL ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("labatalla.json")
    }

    // MARK: Reading

    /// Every goal in Goals order, retired ones included.
    var orderedGoals: [Goal] {
        goals.sorted { ($0.order, $0.createdAt, $0.name) < ($1.order, $1.createdAt, $1.name) }
    }
    var activeGoals: [Goal] { orderedGoals.filter { !$0.isArchived } }
    var archivedGoals: [Goal] { orderedGoals.filter(\.isArchived) }
    func goal(_ id: String) -> Goal? { goals.first { $0.id == id } }
    /// The active goals of one horizon, in order.
    func goals(_ h: Horizon) -> [Goal] { activeGoals.filter { $0.horizon == h } }
    /// The active goals that serve `id`, in order.
    func children(of id: String) -> [Goal] { activeGoals.filter { $0.parentId == id } }
    /// The active goals that serve nothing bigger, or whose bigger goal is gone.
    var topGoals: [Goal] {
        let ids = Set(activeGoals.map(\.id))
        return activeGoals.filter { $0.parentId == nil || !ids.contains($0.parentId ?? "") }
    }
    var workGoals: [Goal] { activeGoals.filter { $0.kind == .work } }

    /// Which goals got a yes on each day.
    var done: DoneByDay { doneByDay(marks) }
    /// Whether a goal got a yes on a day.
    func isDone(_ goalId: String, on day: String) -> Bool { marks.contains { $0.goalId == goalId && $0.day == day && $0.done } }
    /// The answer for a goal on a day, yes or no, if there is one.
    func mark(_ goalId: String, on day: String) -> Mark? { marks.first { $0.goalId == goalId && $0.day == day } }

    func summary(_ day: String) -> DaySummary {
        summarize(day, goals: orderedGoals, done: done, weekStart: settings.weekStart)
    }
    /// Summaries for many days at once: one pass over the marks.
    func summaries(_ days: [String]) -> [String: DaySummary] {
        summarize(days, goals: orderedGoals, marks: marks, weekStart: settings.weekStart)
    }
    func streakOf(_ goal: Goal, today t: String = today()) -> Streak {
        streak(goal, done: done, weekStart: settings.weekStart, today: t)
    }
    func progressOf(_ goal: Goal, today t: String = today()) -> GoalProgress {
        progress(goal, marks: marks, today: t, weekStart: settings.weekStart)
    }

    /// The first day there is anything to show: the oldest mark, night or goal, else today.
    var firstDay: String {
        let t = today()
        return min(marks.map(\.day).min() ?? t, goals.map(\.createdAt).min() ?? t, sleep.map(\.day).min() ?? t)
    }

    /// The color for a new goal: one no active goal has yet.
    var nextColor: GoalColor { GoalColor.next(after: activeGoals.map(\.color)) }

    /// The night that ended on `day`.
    func sleepLog(on day: String) -> SleepLog? { LaBatalla.sleepLog(sleep, on: day) }
    /// Nights by the day they ended, for the calendar.
    var sleepByDay: [String: SleepLog] {
        var out: [String: SleepLog] = [:]
        for l in sleep { if let old = out[l.day], old.at > l.at { continue }; out[l.day] = l }
        return out
    }

    /// The plan for a job in the month holding `day`.
    func plan(for goalId: String, month day: String = today()) -> MonthPlan? { monthPlan(plans, goalId: goalId, month: day) }
    /// Jobs with no number yet for this month.
    func jobsNeedingPlan(today t: String = today()) -> [Goal] { workGoals.filter { needsMonthPlan($0, plans: plans, today: t) } }

    /// The reasons given before in one setting, for the chips: the person's own come first.
    func reasonsUsed(_ set: ReasonSet) -> [[String]] {
        if set == .sleep { return sleep.map(\.allReasons) }
        let kinds = Dictionary(goals.map { ($0.id, $0.kind) }, uniquingKeysWith: { a, _ in a })
        return marks.filter { m in kinds[m.goalId].map { ReasonSet.of($0, done: m.done) == set } ?? false }.map(\.allReasons)
    }

    /// Everything the Insights tab reads, as of `t`.
    func insightInput(today t: String = today()) -> InsightInput {
        InsightInput(goals: goals, marks: marks, sleep: sleep, plans: plans, duels: duels, settings: settings, today: t)
    }

    // MARK: Answers

    /// Marks or un-marks a goal on a day with a plain yes. Returns whether it is a yes now.
    @discardableResult
    func toggle(_ goalId: String, on day: String) -> Bool {
        if let i = marks.firstIndex(where: { $0.goalId == goalId && $0.day == day }) {
            let was = marks[i].done
            marks.remove(at: i)
            if was { changed(); return false }
        }
        marks.append(Mark(goalId: goalId, day: day, minutes: defaultMinutes(goalId)))
        changed()
        return true
    }

    func setDone(_ goalId: String, on day: String, _ value: Bool) {
        if isDone(goalId, on: day) != value { toggle(goalId, on: day) }
    }

    /// The minutes a fresh yes starts with: the goal's planned session, or the job's hours.
    func defaultMinutes(_ goalId: String, on day: String = today()) -> Int {
        guard let g = goal(goalId) else { return 0 }
        switch g.kind {
        case .time: return g.sessionMinutes
        case .work:
            let hours = plan(for: g.id, month: day)?.hoursPerDay ?? g.workSetup.requiredHours
            return Int((hours * 60).rounded())
        case .adherence, .outcome: return 0
        }
    }

    /// Answers "did you?" for a goal on a day. Changing the answer keeps the mark but clears
    /// what belonged to the old answer: its reasons, and a no carries no minutes.
    func answer(_ goalId: String, on day: String, done: Bool) {
        if let i = marks.firstIndex(where: { $0.goalId == goalId && $0.day == day }) {
            guard marks[i].done != done else { return }
            marks[i].done = done
            marks[i].reasons = []
            marks[i].note = nil
            marks[i].minutes = done ? defaultMinutes(goalId, on: day) : 0
            marks[i].units = 0
            marks[i].amount = 0
            marks[i].at = Date().timeIntervalSince1970 * 1000
        } else {
            marks.append(Mark(goalId: goalId, day: day, done: done, minutes: done ? defaultMinutes(goalId, on: day) : 0))
        }
        changed()
    }

    /// Takes the answer back: the day is simply open again.
    func clearAnswer(_ goalId: String, on day: String) {
        let before = marks.count
        marks.removeAll { $0.goalId == goalId && $0.day == day }
        if marks.count != before { changed() }
    }

    /// Changes the answer already given for a goal on a day.
    func updateMark(_ goalId: String, on day: String, _ change: (inout Mark) -> Void) {
        guard let i = marks.firstIndex(where: { $0.goalId == goalId && $0.day == day }) else { return }
        var m = marks[i]
        change(&m)
        m.minutes = max(0, m.minutes)
        m.units = max(0, m.units)
        guard m != marks[i] else { return }
        marks[i] = m
        changed()
    }

    /// Adds or removes one reason on the answer for a goal on a day.
    func toggleReason(_ reason: String, for goalId: String, on day: String) {
        updateMark(goalId, on: day) { m in
            if let i = m.reasons.firstIndex(of: reason) { m.reasons.remove(at: i) } else { m.reasons.append(reason) }
        }
    }

    func setNote(_ goalId: String, on day: String, _ note: String?) {
        let clean = note?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        updateMark(goalId, on: day) { $0.note = clean.isEmpty ? nil : clean }
    }

    // MARK: Sleep

    /// Saves the night that ended on its day, replacing an earlier check-in for the same day.
    func putSleep(_ log: SleepLog) {
        sleep.removeAll { $0.day == log.day && $0.id != log.id }
        if let i = sleep.firstIndex(where: { $0.id == log.id }) { sleep[i] = log } else { sleep.append(log) }
        changed()
    }

    func deleteSleep(on day: String) {
        let before = sleep.count
        sleep.removeAll { $0.day == day }
        if sleep.count != before { changed() }
    }

    /// A check-in for the night ending on `day`, filled in the way the dials should start: the
    /// target bedtime, the target wake time, and the time between them as the sleep.
    func sleepDraft(for day: String) -> SleepLog {
        if let existing = sleepLog(on: day) { return existing }
        let s = settings
        return SleepLog(day: day, bedMinute: s.targetBedMinute, wakeMinute: s.targetWakeMinute,
                        sleptMinutes: sleepSpan(bed: s.targetBedMinute, wake: s.targetWakeMinute), quality: 0,
                        needMinutes: s.sleepNeedMinutes, targetBedMinute: s.targetBedMinute, targetWakeMinute: s.targetWakeMinute)
    }

    // MARK: Goals

    /// Adds a goal, or replaces the one with its id. A new goal goes last.
    func put(_ goal: Goal) {
        if let i = goals.firstIndex(where: { $0.id == goal.id }) {
            goals[i] = goal
        } else {
            var g = goal
            g.order = (goals.map(\.order).max() ?? -1) + 1
            goals.append(g)
        }
        changed()
    }

    /// Retires a goal from `day` on. Its marks stay on the calendar.
    func archive(_ id: String, on day: String = today()) {
        guard let i = goals.firstIndex(where: { $0.id == id }) else { return }
        goals[i].archivedAt = day
        changed()
    }

    func unarchive(_ id: String) {
        guard let i = goals.firstIndex(where: { $0.id == id }) else { return }
        goals[i].archivedAt = nil
        goals[i].achievedAt = nil
        changed()
    }

    /// Marks a goal achieved on `day`. It stops being asked from the next day on; its estimates
    /// stay, to be read against the day it was actually done.
    func achieve(_ id: String, on day: String = today()) {
        guard let i = goals.firstIndex(where: { $0.id == id }) else { return }
        goals[i].achievedAt = day
        goals[i].archivedAt = addDays(1, to: day)
        changed()
    }

    /// Removes a goal and everything that hangs on it: its answers, its month plans, its
    /// head-to-heads. Goals that served it or pulled against it let go of it.
    func delete(_ id: String) {
        goals.removeAll { $0.id == id }
        marks.removeAll { $0.goalId == id }
        plans.removeAll { $0.goalId == id }
        duels.removeAll { $0.a == id || $0.b == id }
        for i in goals.indices {
            if goals[i].parentId == id { goals[i].parentId = nil }
            goals[i].conflicts.removeAll { $0 == id }
        }
        changed()
    }

    /// Puts goals in this order; any not named keep following, in their old order.
    func reorder(_ ids: [String]) {
        let rest = orderedGoals.map(\.id).filter { !ids.contains($0) }
        for (n, id) in (ids + rest).enumerated() {
            if let i = goals.firstIndex(where: { $0.id == id }) { goals[i].order = n }
        }
        changed()
    }

    func update(_ change: (inout Settings) -> Void) {
        change(&settings)
        changed()
    }

    // MARK: Work, head to head, the Oracle

    /// Sets a job's number for a month, replacing the one it had.
    func putPlan(_ plan: MonthPlan) {
        plans.removeAll { $0.goalId == plan.goalId && $0.month == plan.month && $0.id != plan.id }
        if let i = plans.firstIndex(where: { $0.id == plan.id }) { plans[i] = plan } else { plans.append(plan) }
        changed()
    }

    /// Records which of two goals wins when only one can happen. A new answer replaces the old.
    func decide(_ a: String, _ b: String, winner: String) {
        duels.removeAll { $0.isBetween(a, b) }
        duels.append(Duel(a: a, b: b, winner: winner))
        changed()
    }

    func clearDuels() {
        guard !duels.isEmpty else { return }
        duels = []
        changed()
    }

    /// Keeps the talk with the Oracle, the last sixty lines of it.
    func say(_ turn: OracleTurn) {
        oracle.append(turn)
        if oracle.count > 60 { oracle.removeFirst(oracle.count - 60) }
        changed()
    }

    func clearOracle() {
        guard !oracle.isEmpty else { return }
        oracle = []
        changed()
    }

    // MARK: File

    func load() {
        defer { loaded = true }
        guard let data = try? Data(contentsOf: fileURL), let s = try? Snapshot.decode(data) else { return }
        apply(s)
    }

    func snapshot() -> Snapshot {
        Snapshot(goals: goals, marks: marks, settings: settings, sleep: sleep, plans: plans, duels: duels, oracle: oracle)
    }

    /// Replaces everything with an import.
    func restore(_ s: Snapshot) {
        apply(s)
        changed()
    }

    func reset() {
        goals = []
        marks = []
        sleep = []
        plans = []
        duels = []
        oracle = []
        settings = Settings()
        changed()
    }

    private func apply(_ s: Snapshot) {
        goals = s.goals
        marks = s.marks
        sleep = s.sleep
        plans = s.plans
        duels = s.duels
        oracle = s.oracle
        settings = s.settings
    }

    private func changed() {
        guard loaded else { return }
        saveTask?.cancel()
        saveTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 300_000_000)
            if Task.isCancelled { return }
            self?.saveNow()
        }
    }

    /// Writes straight away: on the way to the background, and in tests.
    func saveNow() {
        saveTask?.cancel()
        guard loaded, let data = try? snapshot().encoded() else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
