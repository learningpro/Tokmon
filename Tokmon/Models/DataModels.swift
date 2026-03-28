import Foundation

struct TokenUsage: Codable, Sendable {
    var inputTokens: Int64 = 0
    var outputTokens: Int64 = 0
    var cacheCreationTokens: Int64 = 0
    var cacheReadTokens: Int64 = 0

    var totalTokens: Int64 {
        inputTokens + outputTokens + cacheCreationTokens + cacheReadTokens
    }

    mutating func add(_ other: TokenUsage) {
        inputTokens += other.inputTokens
        outputTokens += other.outputTokens
        cacheCreationTokens += other.cacheCreationTokens
        cacheReadTokens += other.cacheReadTokens
    }
}

struct Session: Identifiable, Sendable {
    let id: String // sessionId (UUID)
    let projectDirName: String
    let projectPath: String
    let timestamp: Date
    let gitBranch: String?
    let version: String?
    var usage: TokenUsage = TokenUsage()
    var modelsUsed: [String: TokenUsage] = [:]
    var entries: [SessionEntry] = []

    var totalTokens: Int64 { usage.totalTokens }
    var totalCost: Double {
        modelsUsed.reduce(0.0) { sum, pair in
            sum + ModelPricing.cost(for: pair.key, usage: pair.value)
        }
    }

    var duration: TimeInterval? {
        guard let first = entries.first?.timestamp,
              let last = entries.last?.timestamp else { return nil }
        return last.timeIntervalSince(first)
    }
}

struct SessionEntry: Identifiable, Sendable {
    let id = UUID()
    let timestamp: Date
    let type: EntryType
    let model: String?
    let usage: TokenUsage?
    let toolName: String?
    let content: String?

    enum EntryType: String, Sendable {
        case assistant
        case user
        case toolUse
        case toolResult
        case progress
        case other
    }
}

struct Project: Identifiable, Sendable {
    let id: String // directory name
    let dirName: String
    let displayName: String
    let path: String
    var sessions: [Session] = []

    var totalTokens: Int64 { sessions.reduce(0) { $0 + $1.totalTokens } }
    var totalCost: Double { sessions.reduce(0) { $0 + $1.totalCost } }
    var sessionCount: Int { sessions.count }
    var lastActive: Date? { sessions.map(\.timestamp).max() }

    var usage: TokenUsage {
        var total = TokenUsage()
        for session in sessions { total.add(session.usage) }
        return total
    }
}

struct DailyUsage: Identifiable, Sendable {
    let id: String // date string
    let date: Date
    var usage: TokenUsage = TokenUsage()
    var cost: Double = 0
    var modelsUsed: [String: TokenUsage] = [:]
    var projectUsage: [String: TokenUsage] = [:]
}

struct ModelPricing {
    struct Price: Codable {
        var inputPerMillion: Double
        var outputPerMillion: Double
        var cacheWritePerMillion: Double
        var cacheReadPerMillion: Double
    }

    static let defaultPrices: [String: Price] = [
        // Current models (Claude 4.6)
        "claude-opus-4-6": Price(inputPerMillion: 5, outputPerMillion: 25, cacheWritePerMillion: 6.25, cacheReadPerMillion: 0.50),
        "claude-sonnet-4-6": Price(inputPerMillion: 3, outputPerMillion: 15, cacheWritePerMillion: 3.75, cacheReadPerMillion: 0.30),
        // Haiku 4.5
        "claude-haiku-4-5": Price(inputPerMillion: 1, outputPerMillion: 5, cacheWritePerMillion: 1.25, cacheReadPerMillion: 0.10),
        "claude-haiku-4-5-20251001": Price(inputPerMillion: 1, outputPerMillion: 5, cacheWritePerMillion: 1.25, cacheReadPerMillion: 0.10),
        // Legacy models
        "claude-opus-4-5": Price(inputPerMillion: 5, outputPerMillion: 25, cacheWritePerMillion: 6.25, cacheReadPerMillion: 0.50),
        "claude-opus-4-1": Price(inputPerMillion: 15, outputPerMillion: 75, cacheWritePerMillion: 18.75, cacheReadPerMillion: 1.50),
        "claude-opus-4": Price(inputPerMillion: 15, outputPerMillion: 75, cacheWritePerMillion: 18.75, cacheReadPerMillion: 1.50),
        "claude-sonnet-4-5": Price(inputPerMillion: 3, outputPerMillion: 15, cacheWritePerMillion: 3.75, cacheReadPerMillion: 0.30),
        "claude-sonnet-4": Price(inputPerMillion: 3, outputPerMillion: 15, cacheWritePerMillion: 3.75, cacheReadPerMillion: 0.30),
        "claude-haiku-3-5": Price(inputPerMillion: 0.80, outputPerMillion: 4, cacheWritePerMillion: 1.00, cacheReadPerMillion: 0.08),
    ]

    static let defaultPrice = Price(inputPerMillion: 3, outputPerMillion: 15, cacheWritePerMillion: 3.75, cacheReadPerMillion: 0.30)

    static var userPrices: [String: Price] {
        get {
            guard let data = UserDefaults.standard.data(forKey: "customModelPrices"),
                  let decoded = try? JSONDecoder().decode([String: Price].self, from: data) else {
                return [:]
            }
            return decoded
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                UserDefaults.standard.set(data, forKey: "customModelPrices")
            }
        }
    }

    static var prices: [String: Price] {
        var merged = defaultPrices
        for (key, value) in userPrices {
            merged[key] = value
        }
        return merged
    }

    static func cost(for model: String, usage: TokenUsage) -> Double {
        let price = priceFor(model)
        let input = Double(usage.inputTokens) / 1_000_000 * price.inputPerMillion
        let output = Double(usage.outputTokens) / 1_000_000 * price.outputPerMillion
        let cacheWrite = Double(usage.cacheCreationTokens) / 1_000_000 * price.cacheWritePerMillion
        let cacheRead = Double(usage.cacheReadTokens) / 1_000_000 * price.cacheReadPerMillion
        return input + output + cacheWrite + cacheRead
    }

    static func priceFor(_ model: String) -> Price {
        let allPrices = prices
        if let exact = allPrices[model] { return exact }
        for (key, price) in allPrices {
            if model.contains(key) { return price }
        }
        if model.contains("opus") { return allPrices["claude-opus-4-6"] ?? defaultPrice }
        if model.contains("sonnet") { return allPrices["claude-sonnet-4-6"] ?? defaultPrice }
        if model.contains("haiku") { return allPrices["claude-haiku-4-5"] ?? defaultPrice }
        return defaultPrice
    }

    static func savePrice(for model: String, price: Price) {
        var current = userPrices
        current[model] = price
        userPrices = current
    }

    static func resetToDefaults() {
        UserDefaults.standard.removeObject(forKey: "customModelPrices")
    }
}
