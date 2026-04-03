import SwiftUI
import Combine

@MainActor
class AppState: ObservableObject {
    @Published var projects: [Project] = []
    @Published var sessions: [Session] = []
    @Published var isLoading = false
    @Published var error: String?
    @Published var startDate: Date = Calendar.current.date(byAdding: .day, value: -7, to: Calendar.current.startOfDay(for: Date()))!
    @Published var endDate: Date = Date()

    @AppStorage("claudeDataPath") var claudeDataPath = "~/.claude/projects"

    private let parser = JSONLParser()

    func loadData() async {
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            let expandedPath = NSString(string: claudeDataPath).expandingTildeInPath
            let (projects, sessions) = try await parser.parseAll(at: expandedPath)
            self.projects = projects
            self.sessions = sessions
        } catch {
            self.error = error.localizedDescription
        }
    }

    var dayCount: Int {
        max(1, Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: startDate), to: Calendar.current.startOfDay(for: endDate)).day ?? 7)
    }

    var filteredSessions: [Session] {
        let start = Calendar.current.startOfDay(for: startDate)
        let end = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: endDate))!
        return sessions.filter { $0.lastTimestamp >= start && $0.timestamp < end }
    }

    var filteredProjects: [Project] {
        let start = Calendar.current.startOfDay(for: startDate)
        let end = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: endDate))!
        return projects.compactMap { project in
            let filtered = project.sessions.filter { $0.lastTimestamp >= start && $0.timestamp < end }
            guard !filtered.isEmpty else { return nil }
            var p = project
            p.sessions = filtered
            return p
        }.sorted { ($0.lastActive ?? .distantPast) > ($1.lastActive ?? .distantPast) }
    }

    var totalCost: Double {
        filteredSessions.reduce(0) { $0 + $1.totalCost }
    }

    var totalTokens: Int64 {
        filteredSessions.reduce(0) { $0 + $1.totalTokens }
    }

    var cacheHitRate: Double {
        let totalCacheRead = filteredSessions.reduce(0) { $0 + $1.usage.cacheReadTokens }
        let totalInput = filteredSessions.reduce(0) { $0 + $1.usage.inputTokens }
        let totalCacheCreate = filteredSessions.reduce(0) { $0 + $1.usage.cacheCreationTokens }
        let denominator = totalCacheRead + totalInput + totalCacheCreate
        guard denominator > 0 else { return 0 }
        return Double(totalCacheRead) / Double(denominator) * 100
    }

    var activeSessions: Int {
        filteredSessions.count
    }
}
