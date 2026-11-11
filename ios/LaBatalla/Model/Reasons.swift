import Foundation

// Reasons. Every answer is followed by "Reason", neutrally: never "excuse". One tap picks one
// from the row; anything typed once comes back as a chip next time, most used first. What the
// reasons add up to is read later, in Insights.

enum ReasonSet: String, CaseIterable {
    case sleep, timeYes, timeNo, ruleYes, ruleNo, workYes, workNo

    static func of(_ kind: GoalKind, done: Bool) -> ReasonSet {
        switch kind {
        case .time, .outcome: return done ? .timeYes : .timeNo
        case .adherence: return done ? .ruleYes : .ruleNo
        case .work: return done ? .workYes : .workNo
        }
    }

    /// The reasons offered before the person has any of their own.
    var defaults: [String] {
        switch self {
        case .sleep:
            return ["On schedule", "Went to bed late", "Late screen", "Stress", "Woke in the night", "Noise", "Too hot",
                    "Caffeine", "Late meal", "Up early", "Family", "Felt sick", "Alcohol", "Worked out"]
        case .timeYes:
            return ["Planned it", "Had energy", "Made time", "Routine", "Pushed through", "Felt like it", "Deadline"]
        case .timeNo:
            return ["No time", "Tired", "Forgot", "Low energy", "Not in the mood", "Work ran long", "Family",
                    "Something came up", NEXT_STEP_REASON, "Rest day", "Sick"]
        case .ruleYes:
            return ["Planned it", "Prepared ahead", "Not tempted", "Stayed busy", "Pushed through", "Routine"]
        case .ruleNo:
            return ["Tempted", "Served too much", "Social", "Stress", "Tired", "Not prepared", "Forgot", "Did not care today"]
        case .workYes:
            return ["Normal day", "Focused", "Good leads", "Deadline", "Pushed through", "Short day by choice", "Slow day"]
        case .workNo:
            return ["Day off", "Holiday", "Sick", "Tired", "Family", "Nothing scheduled", "Not in the mood"]
        }
    }
}

/// The reason that says the goal itself is the problem, not the day.
let NEXT_STEP_REASON = "Did not know the next step"

struct ReasonCount: Equatable, Identifiable {
    let reason: String
    let count: Int
    var id: String { reason }
}

/// How often each reason was given, most used first; ties in A to Z order.
func reasonCounts(_ lists: [[String]]) -> [ReasonCount] {
    var counts: [String: Int] = [:]
    for list in lists {
        for r in Set(list.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }) where !r.isEmpty {
            counts[r, default: 0] += 1
        }
    }
    return counts.map { ReasonCount(reason: $0.key, count: $0.value) }
        .sorted { ($1.count, $0.reason) < ($0.count, $1.reason) }
}

/// The chips to offer: the person's own reasons first, most used first (short ones only, so a
/// typed sentence does not become a chip), then the defaults they have not used.
func reasonChoices(_ set: ReasonSet, used: [[String]], limit: Int = 14) -> [String] {
    let own = reasonCounts(used).map(\.reason).filter { $0.count <= 28 }
    var out: [String] = []
    for r in own + set.defaults where !out.contains(r) { out.append(r) }
    return Array(out.prefix(limit))
}
