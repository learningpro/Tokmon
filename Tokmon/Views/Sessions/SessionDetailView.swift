import SwiftUI
import Charts

struct SessionDetailView: View {
    let session: Session
    let onBack: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                HStack {
                    Button(action: onBack) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text("Back")
                        }
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Theme.accentBlue)

                    Text("Session Detail")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundStyle(Theme.textPrimary)

                    Spacer()
                }

                sessionHeader
                HStack(alignment: .top, spacing: 16) {
                    tokenTimelineChart.frame(maxWidth: .infinity)
                    VStack(spacing: 16) {
                        tokenBreakdown
                        modelsUsedView
                    }
                    .frame(width: 260)
                }
                activityLog
            }
            .padding(24)
        }
        .background(Theme.mainBg)
    }

    // MARK: - Session Header

    var sessionHeader: some View {
        VStack(spacing: 12) {
            HStack {
                Text(String(session.id.prefix(18)))
                    .font(.title2).fontWeight(.bold).monospaced()
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                Text("Completed")
                    .font(.caption).fontWeight(.medium)
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(Theme.accentGreen.opacity(0.2))
                    .foregroundStyle(Theme.accentGreen)
                    .clipShape(Capsule())
            }

            HStack(spacing: 24) {
                metadataItem(icon: "folder.fill", label: "Project", value: session.projectPath)
                if let branch = session.gitBranch {
                    metadataItem(icon: "arrow.triangle.branch", label: "Git Branch", value: branch)
                }
                metadataItem(icon: "clock.fill", label: "Start Time", value: formatFullDate(session.timestamp))
                if let duration = session.duration {
                    metadataItem(icon: "timer", label: "Duration", value: formatDuration(duration))
                }
                metadataItem(icon: "dollarsign.circle.fill", label: "Total Cost", value: String(format: "$%.2f", session.totalCost))
                Spacer()
            }
        }
        .padding(16)
        .background(Theme.cardBg)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.cardBorder, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    func metadataItem(icon: String, label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon).font(.caption).foregroundStyle(Theme.textTertiary)
                Text(label).font(.caption).foregroundStyle(Theme.textTertiary)
            }
            Text(value).font(.subheadline).fontWeight(.medium).foregroundStyle(Theme.textPrimary)
        }
    }

    // MARK: - Token Timeline

    var tokenTimelineChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Token Consumption Over Time").font(.headline).foregroundStyle(Theme.textPrimary)
                Spacer()
                HStack(spacing: 12) {
                    legendDot(color: Theme.accentBlue, label: "Input Tokens")
                    legendDot(color: Theme.accentPurple, label: "Output Tokens")
                    legendDot(color: Theme.accentTeal, label: "Cache Read")
                }
            }

            let assistantEntries = session.entries.filter { $0.type == .assistant && $0.usage != nil }

            if assistantEntries.isEmpty {
                Text("No timeline data available")
                    .foregroundStyle(Theme.textSecondary)
                    .frame(height: 200)
            } else {
                Chart {
                    ForEach(assistantEntries) { entry in
                        if let usage = entry.usage {
                            AreaMark(x: .value("Time", entry.timestamp), y: .value("Cache Read", usage.cacheReadTokens))
                                .foregroundStyle(Theme.accentTeal.opacity(0.4))
                                .interpolationMethod(.catmullRom)
                            AreaMark(x: .value("Time", entry.timestamp), y: .value("Input", usage.inputTokens))
                                .foregroundStyle(Theme.accentBlue.opacity(0.4))
                                .interpolationMethod(.catmullRom)
                            LineMark(x: .value("Time", entry.timestamp), y: .value("Output", usage.outputTokens))
                                .foregroundStyle(Theme.accentPurple)
                                .interpolationMethod(.catmullRom)
                                .lineStyle(StrokeStyle(lineWidth: 2))
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks { _ in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5)).foregroundStyle(Color.white.opacity(0.1))
                        AxisValueLabel(format: .dateTime.hour().minute()).foregroundStyle(Theme.textTertiary)
                    }
                }
                .chartYAxis {
                    AxisMarks { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5)).foregroundStyle(Color.white.opacity(0.1))
                        AxisValueLabel { if let v = value.as(Int64.self) { Text(fmtTokens(v)).foregroundStyle(Theme.textTertiary) } }
                    }
                }
                .frame(height: 220)
            }
        }
        .padding(16)
        .background(Theme.cardBg)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.cardBorder, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    func legendDot(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(label).font(.caption2).foregroundStyle(Theme.textTertiary)
        }
    }

    // MARK: - Token Breakdown

    var tokenBreakdown: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Token Breakdown").font(.headline).foregroundStyle(Theme.textPrimary)

            tokenBar(label: "Input", value: session.usage.inputTokens, color: Theme.accentBlue)
            tokenBar(label: "Output", value: session.usage.outputTokens, color: Theme.accentPurple)
            tokenBar(label: "Cache Created", value: session.usage.cacheCreationTokens, color: Theme.accentOrange)
            tokenBar(label: "Cache Read", value: session.usage.cacheReadTokens, color: Theme.accentTeal)

            Divider().overlay(Theme.cardBorder)

            HStack {
                Text("Total").fontWeight(.medium).foregroundStyle(Theme.textSecondary)
                Spacer()
                Text(fmtTokens(session.totalTokens)).fontWeight(.bold).monospacedDigit().foregroundStyle(Theme.textPrimary)
            }
            .font(.subheadline)
        }
        .padding(16)
        .background(Theme.cardBg)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.cardBorder, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    func tokenBar(label: String, value: Int64, color: Color) -> some View {
        let maxVal = max(session.usage.inputTokens, session.usage.outputTokens, session.usage.cacheCreationTokens, session.usage.cacheReadTokens, 1)
        let ratio = Double(value) / Double(maxVal)

        return VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label).font(.caption).foregroundStyle(Theme.textSecondary)
                Spacer()
                Text(fmtTokens(value)).font(.caption).monospacedDigit().foregroundStyle(Theme.textPrimary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3).fill(Color.white.opacity(0.05)).frame(height: 6)
                    RoundedRectangle(cornerRadius: 3).fill(color).frame(width: max(geo.size.width * ratio, 2), height: 6)
                }
            }
            .frame(height: 6)
        }
    }

    // MARK: - Models Used

    var modelsUsedView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Models Used").font(.headline).foregroundStyle(Theme.textPrimary)

            let totalTokens = session.totalTokens
            ForEach(Array(session.modelsUsed.sorted { $0.value.totalTokens > $1.value.totalTokens }), id: \.key) { model, usage in
                HStack {
                    Circle().fill(modelColor(model)).frame(width: 8, height: 8)
                    Text(shortModel(model)).font(.subheadline).foregroundStyle(Theme.textPrimary)
                    Spacer()
                    let pct = totalTokens > 0 ? Double(usage.totalTokens) / Double(totalTokens) * 100 : 0
                    Text(String(format: "%.0f%%", pct)).font(.caption).foregroundStyle(Theme.textSecondary).monospacedDigit()
                }
            }
        }
        .padding(16)
        .background(Theme.cardBg)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.cardBorder, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Activity Log

    var activityLog: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Activity Log").font(.headline).foregroundStyle(Theme.textPrimary)

            let logEntries = session.entries.prefix(50)
            if logEntries.isEmpty {
                Text("No activity recorded").foregroundStyle(Theme.textSecondary)
            } else {
                ForEach(Array(logEntries)) { entry in
                    HStack(spacing: 8) {
                        Text(formatTime(entry.timestamp))
                            .font(.caption).monospacedDigit().foregroundStyle(Theme.textTertiary)
                            .frame(width: 60, alignment: .leading)

                        Image(systemName: entryIcon(entry))
                            .font(.caption).foregroundStyle(entryColor(entry)).frame(width: 16)

                        Text(entryDescription(entry))
                            .font(.caption).lineLimit(1).foregroundStyle(Theme.textSecondary)

                        Spacer()

                        if let usage = entry.usage {
                            Text(fmtTokens(usage.totalTokens))
                                .font(.caption2).monospacedDigit().foregroundStyle(Theme.textTertiary)
                        }
                    }
                    .padding(.vertical, 3)
                }
            }
        }
        .padding(16)
        .background(Theme.cardBg)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.cardBorder, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Helpers

    private func shortModel(_ m: String) -> String { m.replacingOccurrences(of: "claude-", with: "").replacingOccurrences(of: "-20251001", with: "") }

    private func modelColor(_ m: String) -> Color {
        if m.contains("opus") { return Theme.accentPurple }
        if m.contains("sonnet") { return Theme.accentBlue }
        if m.contains("haiku") { return Theme.accentTeal }
        return Theme.accentOrange
    }

    private func fmtTokens(_ t: Int64) -> String {
        if t >= 1_000_000_000 { return String(format: "%.2fB", Double(t) / 1_000_000_000) }
        if t >= 1_000_000 { return String(format: "%.1fM", Double(t) / 1_000_000) }
        if t >= 1_000 { return String(format: "%.1fK", Double(t) / 1_000) }
        return "\(t)"
    }

    private func formatFullDate(_ date: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd HH:mm"; return f.string(from: date)
    }

    private func formatDuration(_ interval: TimeInterval) -> String {
        let h = Int(interval) / 3600; let m = (Int(interval) % 3600) / 60
        return h > 0 ? "\(h)h \(m)m" : "\(m)m"
    }

    private func formatTime(_ date: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "HH:mm"; return f.string(from: date)
    }

    private func entryIcon(_ entry: SessionEntry) -> String {
        switch entry.type {
        case .assistant: return "bubble.left.fill"
        case .toolUse: return "wrench.fill"
        case .user: return "person.fill"
        default: return "circle.fill"
        }
    }

    private func entryColor(_ entry: SessionEntry) -> Color {
        switch entry.type {
        case .assistant: return Theme.accentPurple
        case .toolUse: return Theme.accentBlue
        case .user: return Theme.accentGreen
        default: return Theme.textTertiary
        }
    }

    private func entryDescription(_ entry: SessionEntry) -> String {
        switch entry.type {
        case .assistant:
            let model = entry.model.map { "(\(shortModel($0)))" } ?? ""
            return "Assistant response \(model)"
        case .toolUse:
            return "Tool: \(entry.toolName ?? "unknown")"
        case .user:
            return "User message"
        default:
            return entry.type.rawValue
        }
    }
}
