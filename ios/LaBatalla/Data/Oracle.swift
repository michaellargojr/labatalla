import Foundation
import Security

// The Oracle: Claude, reading the battlefield brief. Nothing leaves the phone until a question
// is asked; then the brief, the talk so far and the question go to Anthropic's API with the
// person's own key, and the answer comes back. The key lives in the keychain, never in the file.

/// The models the Oracle can ask.
enum OracleModel {
    static let fallback = "claude-opus-5-5"

    struct Choice: Identifiable, Hashable {
        let id: String
        let label: String
        let detail: String
    }

    static let all: [Choice] = [
        Choice(id: "claude-opus-5-5", label: "Opus", detail: "Deep and steady. The default."),
        Choice(id: "claude-fable-5-2", label: "Fable", detail: "The most capable, and the most costly."),
        Choice(id: "claude-sonnet-5-5", label: "Sonnet", detail: "Quicker and cheaper."),
        Choice(id: "claude-haiku-5-5", label: "Haiku", detail: "The quickest and cheapest."),
    ]

    static func choice(_ id: String) -> Choice { all.first { $0.id == id } ?? all[0] }
}

/// The API key, in the phone's keychain.
enum OracleKey {
    private static let service = "labatalla.oracle"
    private static let account = "anthropic-api-key"

    private static var query: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: account]
    }

    static func read() -> String? {
        var q = query
        q[kSecReturnData as String] = true
        q[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        guard SecItemCopyMatching(q as CFDictionary, &item) == errSecSuccess, let data = item as? Data else { return nil }
        let key = String(decoding: data, as: UTF8.self)
        return key.isEmpty ? nil : key
    }

    /// Saves the key, or removes it when given an empty one. Returns whether the keychain took it.
    @discardableResult
    static func save(_ key: String) -> Bool {
        let clean = key.trimmingCharacters(in: .whitespacesAndNewlines)
        SecItemDelete(query as CFDictionary)
        guard !clean.isEmpty else { return true }
        var q = query
        q[kSecValueData as String] = Data(clean.utf8)
        q[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        return SecItemAdd(q as CFDictionary, nil) == errSecSuccess
    }

    static var isSet: Bool { read() != nil }
}

enum OracleError: Error, Equatable {
    case noKey
    case http(Int, String)
    case refused
    case empty
    case network(String)

    /// What to show, plainly.
    var words: String {
        switch self {
        case .noKey: return "The Oracle needs an API key. Add one in Settings."
        case .http(let code, let message):
            if code == 401 { return "The API key was not accepted. Check it in Settings." }
            if code == 429 { return "The API is busy or the key is out of credit. Try again in a moment." }
            return message.isEmpty ? "The API answered with an error (\(code))." : "The API answered: \(message)"
        case .refused: return "The Oracle declined to answer that one. Try asking it another way."
        case .empty: return "The answer came back empty. Try again."
        case .network(let message): return "Could not reach the Oracle. \(message)"
        }
    }
}

enum Oracle {
    static let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!
    static let apiVersion = "2026-10-21"
    static let fallbackBeta = "server-side-fallback-2026-07-01"
    static let maxTokens = 16000

    /// Who the Oracle is.
    static let system = """
    You are the Oracle inside La Batalla, a personal app whose name comes from its maker's \
    grandfather, who answers "how are you?" with "la batalla": the battle. The person talking to \
    you tracks their sleep, their goals, the hours they put in, their work and money, and the \
    reason behind every check-in. You are given a brief with all of it. You see the whole \
    battlefield at once, the way a general does, and that is why they ask you.

    How to answer:
    - Be specific. Use the names, numbers and dates in the brief. Never invent a number; if the \
    brief does not hold what you need, say what is missing and what to log or decide to get it.
    - Say what you actually see: the bottleneck, the conflict, the goal that is not clear, the \
    plan that does not fit the week. Be frank and kind. No flattery and no scolding. The person \
    has ADHD and built this app to have no guilt in it: a missed day is information, never a failing.
    - When a goal is unclear or two goals pull against each other, do what a good closer does: \
    ask the one question that makes it plain, or name the trade plainly and let them choose.
    - Prefer one or two moves the person could make this week over a long list.
    - Keep it short: a few short paragraphs unless asked for more. Plain text only, no Markdown, \
    no headings, no bullet symbols. Use a plain hyphen where a dash is needed.
    - You are not a doctor, a lawyer or a financial adviser, and you do not need to say so unless \
    the question really calls for one.
    """

    /// The questions offered before the person has typed one.
    static func starters(hasWork: Bool) -> [String] {
        var out = ["What is my biggest bottleneck right now?",
                   "Which of my goals are not clear yet?",
                   "Where do my goals pull against each other?",
                   "What am I not seeing?",
                   "What should I pause or drop?"]
        if hasWork { out.insert("How do I earn more per hour?", at: 1) }
        return out
    }

    /// One message holding everything: the brief, the talk so far, and the new question.
    static func prompt(brief: String, transcript: [OracleTurn], question: String) -> String {
        var parts = ["<brief>\n\(brief)\n</brief>"]
        let recent = transcript.suffix(12)
        if !recent.isEmpty {
            let talk = recent.map { ($0.mine ? "Person: " : "Oracle: ") + $0.text }.joined(separator: "\n\n")
            parts.append("<talk_so_far>\n\(talk)\n</talk_so_far>")
        }
        parts.append("<question>\n\(question)\n</question>")
        return parts.joined(separator: "\n\n")
    }

    static func body(model: String, prompt: String, fallbacks: Bool) -> [String: Any] {
        var body: [String: Any] = [
            "model": model,
            "max_tokens": maxTokens,
            "system": system,
            "messages": [["role": "user", "content": prompt]],
        ]
        if fallbacks { body["fallbacks"] = "default" }
        return body
    }

    /// The answer's text out of a response body.
    static func answer(from data: Data) throws -> String {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw OracleError.empty }
        if (json["stop_reason"] as? String) == "refusal" { throw OracleError.refused }
        let blocks = json["content"] as? [[String: Any]] ?? []
        let text = blocks.filter { ($0["type"] as? String) == "text" }.compactMap { $0["text"] as? String }.joined(separator: "\n")
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if clean.isEmpty { throw OracleError.empty }
        return clean
    }

    /// The API's own words for an error, when it sent any.
    static func errorMessage(from data: Data) -> String {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let error = json["error"] as? [String: Any], let message = error["message"] as? String else { return "" }
        return message
    }

    static func ask(question: String, brief: String, transcript: [OracleTurn], model: String, key: String,
                    session: URLSession = .shared) async throws -> String {
        let text = prompt(brief: brief, transcript: transcript, question: question)
        // The smallest model is not offered a fallback; the others let the API route around a decline.
        let fallbacks = !model.contains("haiku")
        do {
            return try await send(model: model, prompt: text, key: key, fallbacks: fallbacks, session: session)
        } catch OracleError.http(let code, _) where code == 400 && fallbacks {
            return try await send(model: model, prompt: text, key: key, fallbacks: false, session: session)
        }
    }

    private static func send(model: String, prompt: String, key: String, fallbacks: Bool, session: URLSession) async throws -> String {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 180
        request.setValue(key, forHTTPHeaderField: "x-api-key")
        request.setValue(apiVersion, forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        if fallbacks { request.setValue(fallbackBeta, forHTTPHeaderField: "anthropic-beta") }
        request.httpBody = try JSONSerialization.data(withJSONObject: body(model: model, prompt: prompt, fallbacks: fallbacks))

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw OracleError.network(error.localizedDescription)
        }
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard status == 200 else { throw OracleError.http(status, errorMessage(from: data)) }
        return try answer(from: data)
    }
}
