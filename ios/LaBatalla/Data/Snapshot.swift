import Foundation
import SwiftUI
import UniformTypeIdentifiers

/// The whole store as one JSON document: the file in Documents, and what Export writes.
struct Snapshot: Codable {
    var app: String = "labatalla"
    var format: Int = 2
    var exportedAt: String
    var goals: [Goal]
    var marks: [Mark]
    var settings: Settings
    var sleep: [SleepLog]
    var plans: [MonthPlan]
    var duels: [Duel]
    var oracle: [OracleTurn]

    init(goals: [Goal], marks: [Mark], settings: Settings, sleep: [SleepLog] = [], plans: [MonthPlan] = [],
         duels: [Duel] = [], oracle: [OracleTurn] = [], exportedAt: Date = Date()) {
        self.goals = goals
        self.marks = marks
        self.settings = settings
        self.sleep = sleep
        self.plans = plans
        self.duels = duels
        self.oracle = oracle
        self.exportedAt = ISO8601DateFormatter().string(from: exportedAt)
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        app = try c.decodeIfPresent(String.self, forKey: .app) ?? "labatalla"
        format = try c.decodeIfPresent(Int.self, forKey: .format) ?? 2
        exportedAt = try c.decodeIfPresent(String.self, forKey: .exportedAt) ?? ""
        goals = try c.decodeIfPresent([Goal].self, forKey: .goals) ?? []
        marks = try c.decodeIfPresent([Mark].self, forKey: .marks) ?? []
        settings = (try? c.decode(Settings.self, forKey: .settings)) ?? Settings()
        // One unreadable entry never takes the rest of the list with it.
        sleep = (try? c.decodeIfPresent([Lossy<SleepLog>].self, forKey: .sleep))?.compactMap(\.value) ?? []
        plans = (try? c.decodeIfPresent([Lossy<MonthPlan>].self, forKey: .plans))?.compactMap(\.value) ?? []
        duels = (try? c.decodeIfPresent([Lossy<Duel>].self, forKey: .duels))?.compactMap(\.value) ?? []
        oracle = (try? c.decodeIfPresent([Lossy<OracleTurn>].self, forKey: .oracle))?.compactMap(\.value) ?? []
    }

    func encoded() throws -> Data {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try e.encode(self)
    }

    static func decode(_ data: Data) throws -> Snapshot { try JSONDecoder().decode(Snapshot.self, from: data) }

    /// "labatalla-2026-11-05.json"
    static func fileName(_ day: String = today()) -> String { "labatalla-\(day).json" }
}

/// Decodes to nil instead of throwing, so a list keeps every entry that can be read.
struct Lossy<T: Decodable>: Decodable {
    let value: T?
    init(from decoder: Decoder) throws { value = try? T(from: decoder) }
}

/// JSON for the Files sheet: Export writes one, Import reads one.
struct JSONFile: FileDocument {
    static let readableContentTypes: [UTType] = [.json]
    var data: Data
    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws { data = configuration.file.regularFileContents ?? Data() }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: data) }
}
