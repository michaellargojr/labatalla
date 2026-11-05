import Foundation
import Observation

/// Single source of truth. Everything lives in memory and is written to one JSON file in
/// Documents (the same shape as an export), a moment after each change.
@Observable
final class AppStore {
    var goals: [Goal] = []
    var marks: [Mark] = []
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

    /// Which goals were marked on each day.
    var done: DoneByDay { doneByDay(marks) }
    func isDone(_ goalId: String, on day: String) -> Bool { marks.contains { $0.goalId == goalId && $0.day == day } }
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

    /// The first day there is anything to show: the oldest mark or goal, else today.
    var firstDay: String {
        let t = today()
        return min(marks.map(\.day).min() ?? t, goals.map(\.createdAt).min() ?? t)
    }

    /// The color for a new goal: one no active goal has yet.
    var nextColor: GoalColor { GoalColor.next(after: activeGoals.map(\.color)) }

    // MARK: Marks

    /// Marks or un-marks a goal on a day. Returns whether it is marked now.
    @discardableResult
    func toggle(_ goalId: String, on day: String) -> Bool {
        if let i = marks.firstIndex(where: { $0.goalId == goalId && $0.day == day }) {
            marks.remove(at: i)
            changed()
            return false
        }
        marks.append(Mark(goalId: goalId, day: day))
        changed()
        return true
    }

    func setDone(_ goalId: String, on day: String, _ value: Bool) {
        if isDone(goalId, on: day) != value { toggle(goalId, on: day) }
    }

    func setNote(_ goalId: String, on day: String, _ note: String?) {
        guard let i = marks.firstIndex(where: { $0.goalId == goalId && $0.day == day }) else { return }
        let clean = note?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        marks[i].note = clean.isEmpty ? nil : clean
        changed()
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
        changed()
    }

    /// Removes a goal and every mark it ever had.
    func delete(_ id: String) {
        goals.removeAll { $0.id == id }
        marks.removeAll { $0.goalId == id }
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

    // MARK: File

    func load() {
        defer { loaded = true }
        guard let data = try? Data(contentsOf: fileURL), let s = try? Snapshot.decode(data) else { return }
        apply(s)
    }

    func snapshot() -> Snapshot { Snapshot(goals: goals, marks: marks, settings: settings) }

    /// Replaces everything with an import.
    func restore(_ s: Snapshot) {
        apply(s)
        changed()
    }

    func reset() {
        goals = []
        marks = []
        settings = Settings()
        changed()
    }

    private func apply(_ s: Snapshot) {
        goals = s.goals
        marks = s.marks
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
