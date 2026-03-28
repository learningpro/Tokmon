import Foundation

struct StatsEngine: Sendable {
    static func dailyUsage(from sessions: [Session], days: Int = 14) -> [DailyUsage] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        var dailyMap: [String: DailyUsage] = [:]
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        for session in sessions {
            let dayKey = dateFormatter.string(from: session.timestamp)
            let dayStart = calendar.startOfDay(for: session.timestamp)

            var daily = dailyMap[dayKey] ?? DailyUsage(id: dayKey, date: dayStart)
            daily.usage.add(session.usage)
            daily.cost += session.totalCost

            for (model, modelUsage) in session.modelsUsed {
                var existing = daily.modelsUsed[model] ?? TokenUsage()
                existing.add(modelUsage)
                daily.modelsUsed[model] = existing
            }

            let projectName = session.projectPath
            var projUsage = daily.projectUsage[projectName] ?? TokenUsage()
            projUsage.add(session.usage)
            daily.projectUsage[projectName] = projUsage

            dailyMap[dayKey] = daily
        }

        // Generate entries for last N days
        var result: [DailyUsage] = []
        for i in (0..<days).reversed() {
            guard let date = calendar.date(byAdding: .day, value: -i, to: today) else { continue }
            let key = dateFormatter.string(from: date)
            let daily = dailyMap[key] ?? DailyUsage(id: key, date: date)
            result.append(daily)
        }

        return result
    }

    static func modelDistribution(from sessions: [Session]) -> [(model: String, tokens: Int64, cost: Double)] {
        var modelMap: [String: TokenUsage] = [:]
        for session in sessions {
            for (model, modelUsage) in session.modelsUsed {
                var existing = modelMap[model] ?? TokenUsage()
                existing.add(modelUsage)
                modelMap[model] = existing
            }
        }

        return modelMap.map { (model: $0.key, tokens: $0.value.totalTokens, cost: ModelPricing.cost(for: $0.key, usage: $0.value)) }
            .sorted { $0.tokens > $1.tokens }
    }
}
