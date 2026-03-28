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
        return base.filter {
            $0.displayName.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                HStack {
                    Text(l10n.t("Projects"))
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    Spacer()
                    TimeRangePicker(startDate: $appState.startDate, endDate: $appState.endDate)
                }

                if appState.filteredProjects.isEmpty {
                    ContentUnavailableView(l10n.t("No Projects"), systemImage: "folder", description: Text(l10n.t("No Claude Code project data found.")))
                } else {
                    ProjectStackedChartView(sessions: appState.filteredSessions, projects: appState.filteredProjects, days: appState.dayCount)

                    VStack(alignment: .leading, spacing: 0) {
                        HStack {
                            Text(l10n.t("All Projects"))
                                .font(.headline)
                            Spacer()
                            TextField(l10n.t("Search projects..."), text: $searchText)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 200)
                        }
                        .padding()

                        HStack(spacing: 0) {
                            Text(l10n.t("Project Name")).frame(maxWidth: .infinity, alignment: .leading)
                            Text(l10n.t("Total Tokens Col")).frame(width: 120, alignment: .trailing)
                            Text(l10n.t("Cost (USD)")).frame(width: 100, alignment: .trailing)
                            Text(l10n.t("Sessions")).frame(width: 80, alignment: .trailing)
                            Text(l10n.t("Last Active")).frame(width: 120, alignment: .trailing)
                            Spacer().frame(width: 30)
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                        .background(.quaternary.opacity(0.3))

                        Divider()

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
                                Divider()
                            }
                        }
                    }
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    HStack {
                        Text("\(l10n.t("Total Token Usage:")) \(formatTokens(appState.totalTokens))")
                            .font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        Text(l10n.t("Last Updated: Just now"))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            .padding()
        }
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
                Image(systemName: "folder.fill").foregroundStyle(.blue)
                Text(project.displayName).fontWeight(.medium)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Text(formatTokens(project.totalTokens)).monospacedDigit().frame(width: 120, alignment: .trailing)
            Text(String(format: "$%.2f", project.totalCost)).monospacedDigit().frame(width: 100, alignment: .trailing)
            Text("\(project.sessionCount)").monospacedDigit().frame(width: 80, alignment: .trailing)
            Text(formatDate(project.lastActive)).frame(width: 120, alignment: .trailing)
            Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                .font(.caption).foregroundStyle(.secondary).frame(width: 30)
        }
        .font(.subheadline)
        .padding(.horizontal).padding(.vertical, 10)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
        .background(isExpanded ? Color.accentColor.opacity(0.05) : Color.clear)
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
                Image(systemName: "clock").foregroundStyle(.secondary).font(.caption)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Session: \(String(session.id.prefix(8)))").font(.caption)
                    if let branch = session.gitBranch {
                        Text(branch).font(.caption2).foregroundStyle(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Text(formatTokens(session.totalTokens)).font(.caption).monospacedDigit().frame(width: 120, alignment: .trailing)
            Text(String(format: "$%.2f", session.totalCost)).font(.caption).monospacedDigit().frame(width: 100, alignment: .trailing)
            Text(formatTimestamp(session.timestamp)).font(.caption).frame(width: 200, alignment: .trailing)
            Spacer().frame(width: 30)
        }
        .padding(.horizontal).padding(.vertical, 6)
        .background(.quaternary.opacity(0.15))
    }

    private func formatTokens(_ tokens: Int64) -> String {
        if tokens >= 1_000_000 { return String(format: "%.0fM", Double(tokens) / 1_000_000) }
        if tokens >= 1_000 { return String(format: "%.0fK", Double(tokens) / 1_000) }
        return "\(tokens)"
    }

    private func formatTimestamp(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "MMM d, HH:mm"
        return f.string(from: date)
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
        let id: String
        let date: Date
        let project: String
        let tokens: Int64
    }

    var chartData: [ChartEntry] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        let topProjects = Array(projects.sorted { $0.totalTokens > $1.totalTokens }.prefix(5))
        var result: [ChartEntry] = []

        for i in (0..<days).reversed() {
            guard let date = calendar.date(byAdding: .day, value: -i, to: today) else { continue }
            let dayKey = dateFormatter.string(from: date)
            for project in topProjects {
                let dayTokens = project.sessions
                    .filter { dateFormatter.string(from: $0.timestamp) == dayKey }
                    .reduce(0 as Int64) { $0 + $1.totalTokens }
                result.append(ChartEntry(id: "\(dayKey)-\(project.displayName)", date: date, project: project.displayName, tokens: dayTokens))
            }
        }
        return result
    }

    private let colors: [Color] = [.blue, .purple, .teal, .orange, .pink]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Token Usage by Project")
                    .font(.headline)
                Spacer()
                HStack(spacing: 12) {
                    ForEach(Array(projects.sorted { $0.totalTokens > $1.totalTokens }.prefix(5).enumerated()), id: \.element.id) { index, project in
                        HStack(spacing: 4) {
                            Circle().fill(colors[index % colors.count]).frame(width: 8, height: 8)
                            Text(project.displayName).font(.caption)
                        }
                    }
                }
            }

            ZStack(alignment: .topLeading) {
                Chart(chartData) { item in
                    AreaMark(
                        x: .value("Date", item.date, unit: .day),
                        y: .value("Tokens", item.tokens),
                        stacking: .standard
                    )
                    .foregroundStyle(by: .value("Project", item.project))
                    .interpolationMethod(.catmullRom)
                    .opacity(selectedDate == nil ? 1.0 : (Calendar.current.isDate(item.date, inSameDayAs: selectedDate!) ? 1.0 : 0.5))

                    if let selectedDate,
                       Calendar.current.isDate(item.date, inSameDayAs: selectedDate),
                       item.tokens > 0 {
                        RuleMark(x: .value("Selected", selectedDate, unit: .day))
                            .foregroundStyle(.gray.opacity(0.3))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    }
                }
                .chartForegroundStyleScale(range: colors)
                .chartLegend(.hidden)
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: 2)) { _ in
                        AxisGridLine()
                        AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                    }
                }
                .chartYAxis {
                    AxisMarks { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let v = value.as(Int64.self) {
                                Text(formatAxisTokens(v))
                            }
                        }
                    }
                }
                .chartOverlay { proxy in
                    GeometryReader { geo in
                        Rectangle()
                            .fill(.clear)
                            .contentShape(Rectangle())
                            .onContinuousHover { phase in
                                switch phase {
                                case .active(let location):
                                    hoverLocation = CGPoint(
                                        x: location.x,
                                        y: location.y
                                    )
                                    chartWidth = geo.size.width
                                    if let date: Date = proxy.value(atX: location.x) {
                                        selectedDate = Calendar.current.startOfDay(for: date)
                                    }
                                case .ended:
                                    selectedDate = nil
                                }
                            }
                    }
                }
                .frame(height: 220)

                if let selectedDate {
                    let dayEntries = chartData.filter { Calendar.current.isDate($0.date, inSameDayAs: selectedDate) && $0.tokens > 0 }
                    if !dayEntries.isEmpty {
                        let tooltipW: CGFloat = 180
                        let xOffset: CGFloat = hoverLocation.x + tooltipW + 20 > chartWidth
                            ? hoverLocation.x - tooltipW - 12
                            : hoverLocation.x + 12
                        tooltipView(date: selectedDate, entries: dayEntries)
                            .offset(x: max(0, xOffset), y: max(0, hoverLocation.y - 60))
                    }
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func colorForProject(_ name: String) -> Color {
        let sorted = projects.sorted { $0.totalTokens > $1.totalTokens }.prefix(5)
        if let idx = sorted.firstIndex(where: { $0.displayName == name }) {
            return colors[idx % colors.count]
        }
        return .gray
    }

    private func tooltipView(date: Date, entries: [ChartEntry]) -> some View {
        let f = DateFormatter()
        f.dateFormat = "MMM d, yyyy"
        let total = entries.reduce(0 as Int64) { $0 + $1.tokens }

        return VStack(alignment: .leading, spacing: 6) {
            Text(f.string(from: date))
                .font(.caption).fontWeight(.bold)
            ForEach(entries) { entry in
                HStack(spacing: 6) {
                    Circle().fill(colorForProject(entry.project)).frame(width: 6, height: 6)
                    Text(entry.project).font(.caption2)
                    Spacer()
                    Text(formatAxisTokens(entry.tokens)).font(.caption2).monospacedDigit()
                }
            }
            Divider()
            HStack {
                Text("Total").font(.caption2).fontWeight(.medium)
                Spacer()
                Text(formatAxisTokens(total)).font(.caption2).fontWeight(.medium).monospacedDigit()
            }
        }
        .padding(8)
        .background(.ultraThickMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .shadow(radius: 4)
        .frame(width: 180)
        .allowsHitTesting(false)
    }

    private func formatAxisTokens(_ tokens: Int64) -> String {
        if tokens >= 1_000_000_000 { return String(format: "%.1fB", Double(tokens) / 1_000_000_000) }
        if tokens >= 1_000_000 { return String(format: "%.0fM", Double(tokens) / 1_000_000) }
        if tokens >= 1_000 { return String(format: "%.0fK", Double(tokens) / 1_000) }
        return "\(tokens)"
    }
}
