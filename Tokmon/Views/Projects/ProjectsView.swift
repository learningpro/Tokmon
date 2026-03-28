import SwiftUI
import Charts

struct ProjectsView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var l10n: L10n
    @State private var searchText = ""
    @State private var expandedProjects: Set<String> = []

    var filteredProjects: [Project] {
        let base = appState.filteredProjects
        if searchText.isEmpty { return base }
        return base.filter { $0.displayName.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                HStack {
                    Text(l10n.t("Projects")).font(.largeTitle).fontWeight(.bold).foregroundStyle(Theme.textPrimary)
                    Spacer()
                    TimeRangePicker(startDate: $appState.startDate, endDate: $appState.endDate)
                }

                if appState.filteredProjects.isEmpty {
                    ContentUnavailableView(l10n.t("No Projects"), systemImage: "folder", description: Text(l10n.t("No Claude Code project data found.")))
                } else {
                    ProjectStackedChartView(sessions: appState.filteredSessions, projects: appState.filteredProjects, days: appState.dayCount)

                    // Project table
                    VStack(alignment: .leading, spacing: 0) {
                        HStack {
                            Text(l10n.t("All Projects")).font(.headline).foregroundStyle(Theme.textPrimary)
                            Spacer()
                            TextField(l10n.t("Search projects..."), text: $searchText)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 200)
                        }
                        .padding(16)

                        // Header
                        HStack(spacing: 0) {
                            Text(l10n.t("Project Name")).frame(maxWidth: .infinity, alignment: .leading)
                            Text(l10n.t("Total Tokens Col")).frame(width: 120, alignment: .trailing)
                            Text(l10n.t("Cost (USD)")).frame(width: 100, alignment: .trailing)
                            Text(l10n.t("Sessions")).frame(width: 80, alignment: .trailing)
                            Text(l10n.t("Last Active")).frame(width: 120, alignment: .trailing)
                            Spacer().frame(width: 30)
                        }
                        .font(.caption)
                        .foregroundStyle(Theme.textTertiary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(0.03))

                        Divider().overlay(Theme.cardBorder)

                        ForEach(filteredProjects) { project in
                            VStack(spacing: 0) {
                                ProjectRow(project: project, isExpanded: expandedProjects.contains(project.id)) {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        if expandedProjects.contains(project.id) {
                                            expandedProjects.remove(project.id)
                                        } else {
                                            expandedProjects.insert(project.id)
                                        }
                                    }
                                }
                                if expandedProjects.contains(project.id) {
                                    ForEach(project.sessions.sorted(by: { $0.timestamp > $1.timestamp })) { session in
                                        SessionSubRow(session: session)
                                    }
                                }
                                Divider().overlay(Theme.cardBorder)
                            }
                        }

                        // Footer
                        HStack {
                            Text("\(l10n.t("Total Token Usage:")) \(formatTokens(appState.totalTokens))")
                                .font(.caption).foregroundStyle(Theme.textTertiary)
                            Spacer()
                            Text(l10n.t("Last Updated: Just now"))
                                .font(.caption).foregroundStyle(Theme.textTertiary)
                        }
                        .padding(12)
                    }
                    .background(Theme.cardBg)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.cardBorder, lineWidth: 1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding(24)
        }
        .background(Theme.mainBg)
    }

    private func formatTokens(_ tokens: Int64) -> String {
        if tokens >= 1_000_000_000 { return String(format: "%.2fB", Double(tokens) / 1_000_000_000) }
        if tokens >= 1_000_000 { return String(format: "%.1fM", Double(tokens) / 1_000_000) }
        return "\(tokens)"
    }
}

struct ProjectRow: View {
    let project: Project
    let isExpanded: Bool
    let onTap: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "folder.fill").foregroundStyle(Theme.accentBlue)
                Text(project.displayName).fontWeight(.medium).foregroundStyle(Theme.textPrimary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Text(formatTokens(project.totalTokens)).monospacedDigit().foregroundStyle(Theme.textPrimary).frame(width: 120, alignment: .trailing)
            Text(String(format: "$%.2f", project.totalCost)).monospacedDigit().foregroundStyle(Theme.textPrimary).frame(width: 100, alignment: .trailing)
            Text("\(project.sessionCount)").monospacedDigit().foregroundStyle(Theme.textSecondary).frame(width: 80, alignment: .trailing)
            Text(formatDate(project.lastActive)).foregroundStyle(Theme.textSecondary).frame(width: 120, alignment: .trailing)
            Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                .font(.caption).foregroundStyle(Theme.textTertiary).frame(width: 30)
        }
        .font(.subheadline)
        .padding(.horizontal, 16).padding(.vertical, 10)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
        .background(isExpanded ? Theme.accentBlue.opacity(0.08) : Color.clear)
    }

    private func formatTokens(_ tokens: Int64) -> String {
        if tokens >= 1_000_000 { return String(format: "%.0fM", Double(tokens) / 1_000_000) }
        if tokens >= 1_000 { return String(format: "%.0fK", Double(tokens) / 1_000) }
        return "\(tokens)"
    }

    private func formatDate(_ date: Date?) -> String {
        guard let date else { return "-" }
        let interval = Date().timeIntervalSince(date)
        if interval < 3600 { return "\(Int(interval / 60))m ago" }
        if interval < 86400 { return "\(Int(interval / 3600))h ago" }
        return "\(Int(interval / 86400))d ago"
    }
}

struct SessionSubRow: View {
    let session: Session

    var body: some View {
        HStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "clock").foregroundStyle(Theme.textTertiary).font(.caption)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Session: \(String(session.id.prefix(8)))").font(.caption).foregroundStyle(Theme.textSecondary)
                    if let branch = session.gitBranch {
                        Text(branch).font(.caption2).foregroundStyle(Theme.textTertiary)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Text(formatTokens(session.totalTokens)).font(.caption).monospacedDigit().foregroundStyle(Theme.textSecondary).frame(width: 120, alignment: .trailing)
            Text(String(format: "$%.2f", session.totalCost)).font(.caption).monospacedDigit().foregroundStyle(Theme.textSecondary).frame(width: 100, alignment: .trailing)
            Text(formatTimestamp(session.timestamp)).font(.caption).foregroundStyle(Theme.textTertiary).frame(width: 200, alignment: .trailing)
            Spacer().frame(width: 30)
        }
        .padding(.horizontal, 16).padding(.vertical, 6)
        .background(Color.white.opacity(0.02))
    }

    private func formatTokens(_ tokens: Int64) -> String {
        if tokens >= 1_000_000 { return String(format: "%.0fM", Double(tokens) / 1_000_000) }
        if tokens >= 1_000 { return String(format: "%.0fK", Double(tokens) / 1_000) }
        return "\(tokens)"
    }

    private func formatTimestamp(_ date: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "MMM d, HH:mm"; return f.string(from: date)
    }
}

struct ProjectStackedChartView: View {
    let sessions: [Session]
    let projects: [Project]
    var days: Int = 14
    @State private var selectedDate: Date?
    @State private var hoverLocation: CGPoint = .zero
    @State private var chartWidth: CGFloat = 600

    struct ChartEntry: Identifiable {
        let id: String; let date: Date; let project: String; let tokens: Int64
    }

    var chartData: [ChartEntry] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd"
        let topProjects = Array(projects.sorted { $0.totalTokens > $1.totalTokens }.prefix(5))
        var result: [ChartEntry] = []
        for i in (0..<days).reversed() {
            guard let date = calendar.date(byAdding: .day, value: -i, to: today) else { continue }
            let dayKey = df.string(from: date)
            for project in topProjects {
                let dayTokens = project.sessions.filter { df.string(from: $0.timestamp) == dayKey }.reduce(0 as Int64) { $0 + $1.totalTokens }
                result.append(ChartEntry(id: "\(dayKey)-\(project.displayName)", date: date, project: project.displayName, tokens: dayTokens))
            }
        }
        return result
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Token Usage by Project").font(.headline).foregroundStyle(Theme.textPrimary)
                Spacer()
                HStack(spacing: 12) {
                    ForEach(Array(projects.sorted { $0.totalTokens > $1.totalTokens }.prefix(5).enumerated()), id: \.element.id) { index, project in
                        HStack(spacing: 4) {
                            Circle().fill(Theme.projectColors[index % Theme.projectColors.count]).frame(width: 8, height: 8)
                            Text(project.displayName).font(.caption).foregroundStyle(Theme.textSecondary)
                        }
                    }
                }
            }

            ZStack(alignment: .topLeading) {
                Chart(chartData) { item in
                    AreaMark(x: .value("Date", item.date, unit: .day), y: .value("Tokens", item.tokens), stacking: .standard)
                        .foregroundStyle(by: .value("Project", item.project))
                        .interpolationMethod(.catmullRom)
                        .opacity(selectedDate == nil ? 1.0 : (Calendar.current.isDate(item.date, inSameDayAs: selectedDate!) ? 1.0 : 0.5))

                    if let selectedDate, Calendar.current.isDate(item.date, inSameDayAs: selectedDate), item.tokens > 0 {
                        RuleMark(x: .value("Selected", selectedDate, unit: .day))
                            .foregroundStyle(Color.white.opacity(0.2))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    }
                }
                .chartForegroundStyleScale(range: Theme.projectColors)
                .chartLegend(.hidden)
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: 2)) { _ in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5)).foregroundStyle(Color.white.opacity(0.1))
                        AxisValueLabel(format: .dateTime.month(.abbreviated).day()).foregroundStyle(Theme.textTertiary)
                    }
                }
                .chartYAxis {
                    AxisMarks { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5)).foregroundStyle(Color.white.opacity(0.1))
                        AxisValueLabel { if let v = value.as(Int64.self) { Text(fmtAxisTokens(v)).foregroundStyle(Theme.textTertiary) } }
                    }
                }
                .chartOverlay { proxy in
                    GeometryReader { geo in
                        Rectangle().fill(.clear).contentShape(Rectangle())
                            .onContinuousHover { phase in
                                switch phase {
                                case .active(let loc):
                                    hoverLocation = loc; chartWidth = geo.size.width
                                    if let date: Date = proxy.value(atX: loc.x) { selectedDate = Calendar.current.startOfDay(for: date) }
                                case .ended: selectedDate = nil
                                }
                            }
                    }
                }
                .frame(height: 220)

                if let selectedDate {
                    let dayEntries = chartData.filter { Calendar.current.isDate($0.date, inSameDayAs: selectedDate) && $0.tokens > 0 }
                    if !dayEntries.isEmpty {
                        let tw: CGFloat = 180
                        let xOff: CGFloat = hoverLocation.x + tw + 20 > chartWidth ? hoverLocation.x - tw - 12 : hoverLocation.x + 12
                        tooltipView(date: selectedDate, entries: dayEntries)
                            .offset(x: max(0, xOff), y: max(0, hoverLocation.y - 60))
                    }
                }
            }
        }
        .padding(16)
        .background(Theme.cardBg)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.cardBorder, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func colorForProject(_ name: String) -> Color {
        let sorted = projects.sorted { $0.totalTokens > $1.totalTokens }.prefix(5)
        if let idx = sorted.firstIndex(where: { $0.displayName == name }) { return Theme.projectColors[idx % Theme.projectColors.count] }
        return .gray
    }

    private func tooltipView(date: Date, entries: [ChartEntry]) -> some View {
        let f = DateFormatter(); f.dateFormat = "MMM d, yyyy"
        let total = entries.reduce(0 as Int64) { $0 + $1.tokens }
        return VStack(alignment: .leading, spacing: 6) {
            Text(f.string(from: date)).font(.caption).fontWeight(.bold).foregroundStyle(Theme.textPrimary)
            ForEach(entries) { entry in
                HStack(spacing: 6) {
                    Circle().fill(colorForProject(entry.project)).frame(width: 6, height: 6)
                    Text(entry.project).font(.caption2).foregroundStyle(Theme.textSecondary)
                    Spacer()
                    Text(fmtAxisTokens(entry.tokens)).font(.caption2).monospacedDigit().foregroundStyle(Theme.textPrimary)
                }
            }
            Divider().overlay(Theme.cardBorder)
            HStack {
                Text("Total").font(.caption2).fontWeight(.medium).foregroundStyle(Theme.textSecondary)
                Spacer()
                Text(fmtAxisTokens(total)).font(.caption2).fontWeight(.medium).monospacedDigit().foregroundStyle(Theme.textPrimary)
            }
        }
        .padding(10).background(Theme.sidebarBg)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.cardBorder, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .shadow(color: .black.opacity(0.4), radius: 8)
        .frame(width: 180).allowsHitTesting(false)
    }

    private func fmtAxisTokens(_ t: Int64) -> String {
        if t >= 1_000_000_000 { return String(format: "%.1fB", Double(t) / 1_000_000_000) }
        if t >= 1_000_000 { return String(format: "%.0fM", Double(t) / 1_000_000) }
        if t >= 1_000 { return String(format: "%.0fK", Double(t) / 1_000) }
        return "\(t)"
    }
}
