import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var l10n: L10n

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                HStack {
                    Text(l10n.t("Dashboard"))
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    Spacer()
                    TimeRangePicker(startDate: $appState.startDate, endDate: $appState.endDate)
                }

                if appState.isLoading {
                    ProgressView("Loading data...")
                        .frame(maxWidth: .infinity, minHeight: 400)
                } else if let error = appState.error {
                    ContentUnavailableView("Error Loading Data", systemImage: "exclamationmark.triangle", description: Text(error))
                } else {
                    SummaryCardsView()

                    HStack(alignment: .top, spacing: 16) {
                        DailyUsageChartView(
                            dailyData: StatsEngine.dailyUsage(from: appState.filteredSessions, days: appState.dayCount)
                        )
                        .frame(maxWidth: .infinity)

                        ModelDistributionChartView(
                            modelData: StatsEngine.modelDistribution(from: appState.filteredSessions)
                        )
                        .frame(width: 260)
                    }

                    RecentSessionsView(sessions: Array(appState.filteredSessions.sorted { $0.lastTimestamp > $1.lastTimestamp }.prefix(5)))
                }
            }
            .padding()
        }
    }
}

struct RecentSessionsView: View {
    @EnvironmentObject var l10n: L10n
    let sessions: [Session]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(l10n.t("Recent Sessions")).font(.headline)

            if sessions.isEmpty {
                Text(l10n.t("No sessions yet")).foregroundStyle(.secondary)
            } else {
                ForEach(sessions) { session in
                    HStack {
                        Image(systemName: "chevron.right.circle.fill").foregroundStyle(.blue)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(session.projectPath).font(.subheadline).fontWeight(.medium)
                            if let branch = session.gitBranch {
                                Text(branch).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        if let duration = session.duration {
                            Text(formatDuration(duration)).font(.caption).foregroundStyle(.secondary)
                        }
                        Text(formatCost(session.totalCost)).font(.subheadline).fontWeight(.medium).monospacedDigit()
                    }
                    .padding(.vertical, 4)
                    if session.id != sessions.last?.id { Divider() }
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func formatDuration(_ interval: TimeInterval) -> String {
        let h = Int(interval) / 3600; let m = (Int(interval) % 3600) / 60
        return h > 0 ? "\(h)h \(m)m" : "\(m) min"
    }

    private func formatCost(_ cost: Double) -> String { String(format: "$%.2f", cost) }
}
