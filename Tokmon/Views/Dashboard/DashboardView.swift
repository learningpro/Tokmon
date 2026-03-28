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
                        .foregroundStyle(Theme.textPrimary)
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
                        .frame(width: 280)
                    }

                    RecentSessionsView(sessions: Array(appState.filteredSessions.sorted { $0.timestamp > $1.timestamp }.prefix(5)))
                }
            }
            .padding(24)
        }
        .background(Theme.mainBg)
    }
}

struct RecentSessionsView: View {
    @EnvironmentObject var l10n: L10n
    let sessions: [Session]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(l10n.t("Recent Sessions"))
                .font(.headline)
                .foregroundStyle(Theme.textPrimary)

            if sessions.isEmpty {
                Text(l10n.t("No sessions yet"))
                    .foregroundStyle(Theme.textSecondary)
            } else {
                ForEach(sessions) { session in
                    HStack {
                        Image(systemName: "play.circle.fill")
                            .foregroundStyle(Theme.accentBlue)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(session.projectPath)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundStyle(Theme.textPrimary)
                            if let branch = session.gitBranch {
                                Text(branch)
                                    .font(.caption)
                                    .foregroundStyle(Theme.textTertiary)
                            }
                        }

                        Spacer()

                        if let duration = session.duration {
                            Text(formatDuration(duration))
                                .font(.caption)
                                .foregroundStyle(Theme.textSecondary)
                        }

                        Text(formatCost(session.totalCost))
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .monospacedDigit()
                            .foregroundStyle(Theme.textPrimary)
                    }
                    .padding(.vertical, 6)

                    if session.id != sessions.last?.id {
                        Divider().overlay(Theme.cardBorder)
                    }
                }
            }
        }
        .padding(16)
        .background(Theme.cardBg)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.cardBorder, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func formatDuration(_ interval: TimeInterval) -> String {
        let h = Int(interval) / 3600; let m = (Int(interval) % 3600) / 60
        return h > 0 ? "\(h)h \(m)m" : "\(m) min"
    }

    private func formatCost(_ cost: Double) -> String { String(format: "$%.2f", cost) }
}
