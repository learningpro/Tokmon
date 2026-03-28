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
        if let session = selectedSession {
            SessionDetailView(session: session) {
                selectedSession = nil
            }
        } else {
            sessionListView
        }
    }

    var sessionListView: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(l10n.t("Sessions"))
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Spacer()

                TimeRangePicker(startDate: $appState.startDate, endDate: $appState.endDate)

                Picker(l10n.t("Sort"), selection: $sortOrder) {
                    ForEach(SortOrder.allCases, id: \.self) { order in
                        Text(l10n.t(order.rawValue)).tag(order)
                    }
                }
                .frame(width: 160)

                TextField(l10n.t("Search..."), text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 200)
            }
            .padding()

            if filteredSessions.isEmpty {
                ContentUnavailableView(l10n.t("No Sessions"), systemImage: "clock", description: Text(l10n.t("No session data found.")))
                    .frame(maxHeight: .infinity)
            } else {
                // Table header
                HStack(spacing: 0) {
                    Text(l10n.t("Project"))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(l10n.t("Branch"))
                        .frame(width: 150, alignment: .leading)
                    Text(l10n.t("Models"))
                        .frame(width: 150, alignment: .leading)
                    Text(l10n.t("Tokens"))
                        .frame(width: 100, alignment: .trailing)
                    Text(l10n.t("Cost"))
                        .frame(width: 80, alignment: .trailing)
                    Text(l10n.t("Duration"))
                        .frame(width: 80, alignment: .trailing)
                    Text(l10n.t("Date"))
                        .frame(width: 120, alignment: .trailing)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(.quaternary.opacity(0.3))

                Divider()

                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(filteredSessions) { session in
                            SessionListRow(session: session)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    selectedSession = session
                                }

                            Divider()
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
                Image(systemName: "clock.fill")
                    .foregroundStyle(.blue)
                    .font(.caption)
                Text(session.projectPath)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(session.gitBranch ?? "-")
                .font(.caption)
                .lineLimit(1)
                .frame(width: 150, alignment: .leading)

            HStack(spacing: 4) {
                ForEach(Array(session.modelsUsed.keys.sorted()), id: \.self) { model in
                    Text(shortModel(model))
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(modelColor(model).opacity(0.2))
                        .foregroundStyle(modelColor(model))
                        .clipShape(Capsule())
                }
            }
            .frame(width: 150, alignment: .leading)

            Text(formatTokens(session.totalTokens))
                .monospacedDigit()
                .frame(width: 100, alignment: .trailing)

            Text(String(format: "$%.2f", session.totalCost))
                .monospacedDigit()
                .frame(width: 80, alignment: .trailing)

            Text(formatDuration(session.duration))
                .frame(width: 80, alignment: .trailing)

            Text(formatDate(session.timestamp))
                .frame(width: 120, alignment: .trailing)
        }
        .font(.subheadline)
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    private func shortModel(_ model: String) -> String {
        if model.contains("opus") { return "opus" }
        if model.contains("sonnet") { return "sonnet" }
        if model.contains("haiku") { return "haiku" }
        return String(model.prefix(8))
    }

    private func modelColor(_ model: String) -> Color {
        if model.contains("opus") { return .purple }
        if model.contains("sonnet") { return .blue }
        if model.contains("haiku") { return .teal }
        return .orange
    }

    private func formatTokens(_ tokens: Int64) -> String {
        if tokens >= 1_000_000 {
            return String(format: "%.1fM", Double(tokens) / 1_000_000)
        } else if tokens >= 1_000 {
            return String(format: "%.1fK", Double(tokens) / 1_000)
        }
        return "\(tokens)"
    }

    private func formatDuration(_ interval: TimeInterval?) -> String {
        guard let interval else { return "-" }
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        if hours > 0 { return "\(hours)h \(minutes)m" }
        return "\(minutes)m"
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, HH:mm"
        return formatter.string(from: date)
    }
}
