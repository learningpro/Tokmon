import SwiftUI
import Charts

struct SessionDetailView: View {
    let session: Session
    let onBack: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Back button + title
                HStack {
                    Button(action: onBack) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text("Back")
                        }
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.blue)

                    Spacer()
                }

                // Session metadata header
                sessionHeader

                // Charts row
                HStack(alignment: .top, spacing: 16) {
                    // Token timeline
                    tokenTimelineChart
                        .frame(maxWidth: .infinity)

                    // Right panel
                    VStack(spacing: 16) {
                        tokenBreakdown
                        modelsUsedView
                    }
                    .frame(width: 260)
                }

                // Activity log
                activityLog
            }
            .padding()
        }
    }

    // MARK: - Session Header

    var sessionHeader: some View {
        VStack(spacing: 12) {
            HStack {
                Text(String(session.id.prefix(18)))
                    .font(.title2)
                    .fontWeight(.bold)
                    .monospaced()

                Spacer()

                Text("Completed")
                    .font(.caption)
                    .fontWeight(.medium)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(.green.opacity(0.2))
                    .foregroundStyle(.green)
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
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    func metadataItem(icon: String, label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
    }

    // MARK: - Token Timeline

    var tokenTimelineChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Token Consumption Over Time")
                .font(.headline)

            let assistantEntries = session.entries.filter { $0.type == .assistant && $0.usage != nil }

            if assistantEntries.isEmpty {
                Text("No timeline data available")
                    .foregroundStyle(.secondary)
                    .frame(height: 200)
            } else {
                Chart {
                    ForEach(assistantEntries) { entry in
                        if let usage = entry.usage {
                            BarMark(
                                x: .value("Time", entry.timestamp),
                                y: .value("Input", usage.inputTokens)
                            )
                            .foregroundStyle(.blue)

                            BarMark(
                                x: .value("Time", entry.timestamp),
                                y: .value("Output", usage.outputTokens)
                            )
                            .foregroundStyle(.purple)

                            BarMark(
                                x: .value("Time", entry.timestamp),
                                y: .value("Cache Read", usage.cacheReadTokens)
                            )
                            .foregroundStyle(.teal)
                        }
                    }
                }
                .chartForegroundStyleScale([
                    "Input": Color.blue,
                    "Output": Color.purple,
                    "Cache Read": Color.teal
                ])
                .frame(height: 220)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Token Breakdown

    var tokenBreakdown: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Token Breakdown")
                .font(.headline)

            tokenBar(label: "Input", value: session.usage.inputTokens, color: .blue)
            tokenBar(label: "Output", value: session.usage.outputTokens, color: .purple)
            tokenBar(label: "Cache Created", value: session.usage.cacheCreationTokens, color: .orange)
            tokenBar(label: "Cache Read", value: session.usage.cacheReadTokens, color: .teal)

            Divider()

            HStack {
                Text("Total")
                    .fontWeight(.medium)
                Spacer()
                Text(formatTokens(session.totalTokens))
                    .fontWeight(.bold)
                    .monospacedDigit()
            }
            .font(.subheadline)
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    func tokenBar(label: String, value: Int64, color: Color) -> some View {
        let maxVal = max(session.usage.inputTokens, session.usage.outputTokens, session.usage.cacheCreationTokens, session.usage.cacheReadTokens, 1)
        let ratio = Double(value) / Double(maxVal)

        return VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.caption)
                Spacer()
                Text(formatTokens(value))
                    .font(.caption)
                    .monospacedDigit()
            }
            GeometryReader { geo in
                RoundedRectangle(cornerRadius: 3)
                    .fill(color)
                    .frame(width: max(geo.size.width * ratio, 2))
            }
            .frame(height: 6)
        }
    }

    // MARK: - Models Used

    var modelsUsedView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Models Used")
                .font(.headline)

            let totalTokens = session.totalTokens
            ForEach(Array(session.modelsUsed.sorted { $0.value.totalTokens > $1.value.totalTokens }), id: \.key) { model, usage in
                HStack {
                    Circle()
                        .fill(modelColor(model))
                        .frame(width: 8, height: 8)
                    Text(shortModel(model))
                        .font(.subheadline)
                    Spacer()
                    let pct = totalTokens > 0 ? Double(usage.totalTokens) / Double(totalTokens) * 100 : 0
                    Text(String(format: "%.0f%%", pct))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Activity Log

    var activityLog: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Activity Log")
                .font(.headline)

            let logEntries = session.entries.prefix(50)
            if logEntries.isEmpty {
                Text("No activity recorded")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(logEntries)) { entry in
                    HStack(spacing: 8) {
                        Text(formatTime(entry.timestamp))
                            .font(.caption)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                            .frame(width: 60, alignment: .leading)

                        Image(systemName: entryIcon(entry))
                            .font(.caption)
                            .foregroundStyle(entryColor(entry))
                            .frame(width: 16)

                        Text(entryDescription(entry))
                            .font(.caption)
                            .lineLimit(1)

                        Spacer()

                        if let usage = entry.usage {
                            Text(formatTokens(usage.totalTokens))
                                .font(.caption2)
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Helpers

    private func shortModel(_ model: String) -> String {
        model.replacingOccurrences(of: "claude-", with: "").replacingOccurrences(of: "-20251001", with: "")
    }

    private func modelColor(_ model: String) -> Color {
        if model.contains("opus") { return .purple }
        if model.contains("sonnet") { return .blue }
        if model.contains("haiku") { return .teal }
        return .orange
    }

    private func formatTokens(_ tokens: Int64) -> String {
        if tokens >= 1_000_000_000 { return String(format: "%.2fB", Double(tokens) / 1_000_000_000) }
        if tokens >= 1_000_000 { return String(format: "%.1fM", Double(tokens) / 1_000_000) }
        if tokens >= 1_000 { return String(format: "%.1fK", Double(tokens) / 1_000) }
        return "\(tokens)"
    }

    private func formatFullDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f.string(from: date)
    }

    private func formatDuration(_ interval: TimeInterval) -> String {
        let h = Int(interval) / 3600
        let m = (Int(interval) % 3600) / 60
        if h > 0 { return "\(h)h \(m)m" }
        return "\(m)m"
    }

    private func formatTime(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: date)
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
        case .assistant: return .purple
        case .toolUse: return .blue
        case .user: return .green
        default: return .secondary
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
