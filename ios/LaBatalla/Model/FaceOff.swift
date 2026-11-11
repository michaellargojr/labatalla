import Foundation

// Three readings of how much a goal matters. Said: the 1 to 10 given at setup. Chose: what won
// when two goals were put head to head and only one could happen. Did: the share of its plan it
// actually got. Where the three disagree is where there is something to learn.

/// The goals that can be weighed against each other: everything still being fought for.
func duelable(_ goals: [Goal], today t: String = today()) -> [Goal] {
    goals.filter { $0.isActive(on: t) && !$0.isAchieved }
}

/// The latest answer for each pair.
private func latestDuels(_ goals: [Goal], _ duels: [Duel]) -> [Duel] {
    let ids = Set(goals.map(\.id))
    var latest: [String: Duel] = [:]
    for d in duels where ids.contains(d.a) && ids.contains(d.b) && (d.winner == d.a || d.winner == d.b) {
        let key = d.a < d.b ? "\(d.a)|\(d.b)" : "\(d.b)|\(d.a)"
        if let old = latest[key], old.at > d.at { continue }
        latest[key] = d
    }
    return Array(latest.values)
}

/// The next pair nobody has decided yet, in Goals order. Nil when every pair has an answer.
func nextDuel(_ goals: [Goal], duels: [Duel]) -> (Goal, Goal)? {
    let done = latestDuels(goals, duels)
    for (i, a) in goals.enumerated() {
        for b in goals.dropFirst(i + 1) where !done.contains(where: { $0.isBetween(a.id, b.id) }) {
            return (a, b)
        }
    }
    return nil
}

/// How many pairs there are, and how many have an answer.
func duelCount(_ goals: [Goal], duels: [Duel]) -> (done: Int, of: Int) {
    (latestDuels(goals, duels).count, goals.count * (goals.count - 1) / 2)
}

/// Head-to-heads won by each goal.
func duelWins(_ goals: [Goal], duels: [Duel]) -> [String: Int] {
    var wins: [String: Int] = [:]
    for d in latestDuels(goals, duels) { wins[d.winner, default: 0] += 1 }
    return wins
}

struct Standing: Identifiable, Equatable {
    var id: String
    var name: String
    var color: GoalColor
    /// The importance given at setup, 0 when not rated.
    var said: Int
    /// Head-to-heads won and played. Played 0 means it was never put up against anything.
    var wins: Int
    var played: Int
    /// 1 is the goal that won the most. Nil until it has played.
    var choseRank: Int?
    /// The share of its plan it got in the last four weeks. Nil when too new to say.
    var did: Double?
}

/// One row per goal, in Goals order.
func standings(goals: [Goal], duels: [Duel], marks: [Mark], today t: String = today()) -> [Standing] {
    let pool = duelable(goals, today: t)
    let latest = latestDuels(pool, duels)
    let wins = duelWins(pool, duels: duels)
    func played(_ id: String) -> Int { latest.filter { $0.a == id || $0.b == id }.count }
    return pool.map { g in
        let w = wins[g.id] ?? 0
        let n = played(g.id)
        let better = pool.filter { played($0.id) > 0 && (wins[$0.id] ?? 0) > w }.count
        return Standing(id: g.id, name: g.name, color: g.color, said: g.importance, wins: w, played: n,
                        choseRank: n > 0 ? better + 1 : nil, did: planShare(g, marks: marks, today: t))
    }
}
