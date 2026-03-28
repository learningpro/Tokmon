import SwiftUI

struct SummaryCardsView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var l10n: L10n

    var body: some View {
        HStack(spacing: 16) {
            SummaryCard(
                title: l10n.t("Total Cost"),
                value: formatCost(appState.totalCost),
                subtitle: l10n.t("this month"),
                icon: "dollarsign.circle.fill",
                color: .green
            )
            SummaryCard(
                title: l10n.t("Total Tokens"),
                value: formatTokens(appState.totalTokens),
                subtitle: l10n.t("lifetime total"),
                icon: "number.circle.fill",
                color: .blue
            )
            SummaryCard(
                title: l10n.t("Cache Hit Rate"),
                value: String(format: "%.1f%%", appState.cacheHitRate),
                subtitle: l10n.t("read / total"),
                icon: "bolt.circle.fill",
                color: .teal
            )
            SummaryCard(
                title: l10n.t("Sessions"),
                value: "\(appState.activeSessions)",
                subtitle: "\(appState.filteredProjects.count) \(l10n.t("projects"))",
                icon: "clock.circle.fill",
                color: .purple
            )
        }
    }

    private func formatCost(_ cost: Double) -> String {
        cost >= 1000 ? String(format: "$%.0f", cost) : String(format: "$%.2f", cost)
    }

    private func formatTokens(_ tokens: Int64) -> String {
        if tokens >= 1_000_000_000 { return String(format: "%.2fB", Double(tokens) / 1_000_000_000) }
        if tokens >= 1_000_000 { return String(format: "%.1fM", Double(tokens) / 1_000_000) }
        if tokens >= 1_000 { return String(format: "%.1fK", Double(tokens) / 1_000) }
        return "\(tokens)"
    }
}

struct SummaryCard: View {
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon).font(.title3).foregroundStyle(color)
                Spacer()
            }
            Text(value).font(.system(size: 28, weight: .bold, design: .rounded)).foregroundStyle(.primary)
            Text(title).font(.subheadline).foregroundStyle(.secondary)
            Text(subtitle).font(.caption).foregroundStyle(.tertiary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
