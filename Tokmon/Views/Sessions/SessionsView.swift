import SwiftUI

struct SessionsView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var l10n: L10n
    @State private var searchText = ""
    @State private var selectedSession: Session?
    @State private var sortOrder: SortOrder = .dateDesc

    enum SortOrder: String, CaseIterable {
        case dateDesc = "Newest First"
        case dateAsc = "Oldest First"
        case costDesc = "Highest Cost"
        case tokensDesc = "Most Tokens"
    }

    var filteredSessions: [Session] {
        var result = appState.filteredSessions
        if !searchText.isEmpty {
            result = result.filter {
                $0.projectPath.localizedCaseInsensitiveContains(searchText) ||
                ($0.gitBranch?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                $0.id.localizedCaseInsensitiveContains(searchText)
            }
        }
        switch sortOrder {
        case .dateDesc: result.sort { $0.timestamp > $1.timestamp }
        case .dateAsc: result.sort { $0.timestamp < $1.timestamp }
        case .costDesc: result.sort { $0.totalCost > $1.totalCost }
        case .tokensDesc: result.sort { $0.totalTokens > $1.totalTokens }
        }
        return result
    }

    var body: some View {
        Group {
            if let session = selectedSession {
                SessionDetailView(session: session) { selectedSession = nil }
            } else {
                sessionListView
            }
        }
        .background(Theme.mainBg)
    }

    var sessionListView: some View {
        VStack(spacing: 0) {
            HStack {
                Text(l10n.t("Sessions")).font(.largeTitle).fontWeight(.bold).foregroundStyle(Theme.textPrimary)
                Spacer()
                TimeRangePicker(startDate: $appState.startDate, endDate: $appState.endDate)
                Picker(l10n.t("Sort"), selection: $sortOrder) {
                    ForEach(SortOrder.allCases, id: \.self) { order in Text(l10n.t(order.rawValue)).tag(order) }
                }
                .frame(width: 160)
                TextField(l10n.t("Search..."), text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 200)
            }
            .padding(24)

            if filteredSessions.isEmpty {
                ContentUnavailableView(l10n.t("No Sessions"), systemImage: "clock", description: Text(l10n.t("No session data found.")))
                    .frame(maxHeight: .infinity)
            } else {
                // Table header
                HStack(spacing: 0) {
                    Text(l10n.t("Project")).frame(maxWidth: .infinity, alignment: .leading)
                    Text(l10n.t("Branch")).frame(width: 150, alignment: .leading)
                    Text(l10n.t("Models")).frame(width: 150, alignment: .leading)
                    Text(l10n.t("Tokens")).frame(width: 100, alignment: .trailing)
                    Text(l10n.t("Cost")).frame(width: 80, alignment: .trailing)
                    Text(l10n.t("Duration")).frame(width: 80, alignment: .trailing)
                    Text(l10n.t("Date")).frame(width: 120, alignment: .trailing)
                }
                .font(.caption)
                .foregroundStyle(Theme.textTertiary)
                .padding(.horizontal, 24)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.03))

                Divider().overlay(Theme.cardBorder)

                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(filteredSessions) { session in
                            SessionListRow(session: session)
                                .contentShape(Rectangle())
                                .onTapGesture { selectedSession = session }
                            Divider().overlay(Theme.cardBorder)
                        }
                    }
                }
            }
        }
    }
}

struct SessionListRow: View {
    let session: Session

    var body: some View {
        HStack(spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: "circle.fill").foregroundStyle(Theme.accentBlue).font(.system(size: 6))
                Text(session.projectPath).lineLimit(1).foregroundStyle(Theme.textPrimary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(session.gitBranch ?? "-").font(.caption).lineLimit(1).foregroundStyle(Theme.textSecondary).frame(width: 150, alignment: .leading)

            HStack(spacing: 4) {
                ForEach(Array(session.modelsUsed.keys.sorted()), id: \.self) { model in
                    Text(shortModel(model))
                        .font(.caption2)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(modelColor(model).opacity(0.2))
                        .foregroundStyle(modelColor(model))
                        .clipShape(Capsule())
                }
            }
            .frame(width: 150, alignment: .leading)

            Text(formatTokens(session.totalTokens)).monospacedDigit().foregroundStyle(Theme.textPrimary).frame(width: 100, alignment: .trailing)
            Text(String(format: "$%.2f", session.totalCost)).monospacedDigit().foregroundStyle(Theme.textPrimary).frame(width: 80, alignment: .trailing)
            Text(formatDuration(session.duration)).foregroundStyle(Theme.textSecondary).frame(width: 80, alignment: .trailing)
            Text(formatDate(session.timestamp)).foregroundStyle(Theme.textSecondary).frame(width: 120, alignment: .trailing)
        }
        .font(.subheadline)
        .padding(.horizontal, 24).padding(.vertical, 8)
        .background(Theme.mainBg)
    }

    private func shortModel(_ m: String) -> String {
        if m.contains("opus") { return "opus" }
        if m.contains("sonnet") { return "sonnet" }
        if m.contains("haiku") { return "haiku" }
        return String(m.prefix(8))
    }

    private func modelColor(_ m: String) -> Color {
        if m.contains("opus") { return Theme.accentPurple }
        if m.contains("sonnet") { return Theme.accentBlue }
        if m.contains("haiku") { return Theme.accentTeal }
        return Theme.accentOrange
    }

    private func formatTokens(_ t: Int64) -> String {
        if t >= 1_000_000 { return String(format: "%.1fM", Double(t) / 1_000_000) }
        if t >= 1_000 { return String(format: "%.1fK", Double(t) / 1_000) }
        return "\(t)"
    }

    private func formatDuration(_ interval: TimeInterval?) -> String {
        guard let interval else { return "-" }
        let h = Int(interval) / 3600; let m = (Int(interval) % 3600) / 60
        return h > 0 ? "\(h)h \(m)m" : "\(m)m"
    }

    private func formatDate(_ date: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "MMM d, HH:mm"; return f.string(from: date)
    }
}
