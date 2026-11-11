import Foundation
import Testing
@testable import LaBatalla

// Head to head: which pair is next, who has won what, and said against chose against did.

@Suite struct FaceOffTests {
    let a = Goal(name: "A", createdAt: "2026-10-01", order: 0, kind: .adherence, importance: 9)
    let b = Goal(name: "B", createdAt: "2026-10-01", order: 1, kind: .adherence, importance: 7)
    let c = Goal(name: "C", createdAt: "2026-10-01", order: 2, kind: .adherence)

    @Test func pairsComeInOrderUntilNoneAreLeft() {
        let goals = [a, b, c]
        var duels: [Duel] = []
        var pair = nextDuel(goals, duels: duels)
        #expect(pair?.0.id == a.id && pair?.1.id == b.id)
        #expect(duelCount(goals, duels: duels).done == 0)
        #expect(duelCount(goals, duels: duels).of == 3)
        duels.append(Duel(a: a.id, b: b.id, winner: a.id, at: 1))
        pair = nextDuel(goals, duels: duels)
        #expect(pair?.0.id == a.id && pair?.1.id == c.id)
        duels.append(Duel(a: c.id, b: a.id, winner: a.id, at: 2))
        duels.append(Duel(a: b.id, b: c.id, winner: b.id, at: 3))
        let noneLeft = nextDuel(goals, duels: duels) == nil
        #expect(noneLeft)
        #expect(duelCount(goals, duels: duels).done == 3)
        #expect(duelWins(goals, duels: duels) == [a.id: 2, b.id: 1])
    }

    @Test func theLatestAnswerForAPairCounts() {
        let duels = [Duel(a: a.id, b: b.id, winner: a.id, at: 1), Duel(a: b.id, b: a.id, winner: b.id, at: 2)]
        #expect(duelWins([a, b], duels: duels) == [b.id: 1])
        #expect(duelCount([a, b], duels: duels).done == 1)
        // A duel with a goal that is gone is ignored.
        #expect(duelWins([a, b], duels: [Duel(a: a.id, b: "gone", winner: a.id)]).isEmpty)
    }

    @Test func saidChoseDid() {
        let duels = [Duel(a: a.id, b: b.id, winner: a.id, at: 1), Duel(a: a.id, b: c.id, winner: a.id, at: 2),
                     Duel(a: b.id, b: c.id, winner: b.id, at: 3)]
        // B was kept every day of the last four weeks; A and C never.
        let marks = daysFrom("2026-10-15", through: "2026-11-11").map { Mark(goalId: b.id, day: $0) }
        let rows = standings(goals: [a, b, c], duels: duels, marks: marks, today: "2026-11-11")
        #expect(rows.map(\.name) == ["A", "B", "C"])
        #expect(rows.map(\.said) == [9, 7, 0])
        #expect(rows.map(\.wins) == [2, 1, 0])
        #expect(rows.map(\.played) == [2, 2, 2])
        #expect(rows.map(\.choseRank) == [1, 2, 3])
        #expect(rows.map(\.did) == [0, 1, 0])
    }

    @Test func aGoalThatNeverPlayedHasNoRank() {
        let rows = standings(goals: [a, b], duels: [], marks: [], today: "2026-11-11")
        #expect(rows.map(\.choseRank) == [nil, nil])
        var done = c
        done.achievedAt = "2026-11-01"
        #expect(duelable([a, done], today: "2026-11-11").map(\.name) == ["A"])
    }
}
