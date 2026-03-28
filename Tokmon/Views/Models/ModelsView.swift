import SwiftUI
import Charts

struct ModelsView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var l10n: L10n
    @State private var hoveredBarModel: String?
    @State private var barHoverLocation: CGPoint = .zero
    @State private var barChartWidth: CGFloat = 600
    @State private var hoveredPieModel: String?

    var modelData: [(model: String, usage: TokenUsage, cost: Double, sessionCount: Int)] {
        var map: [String: (usage: TokenUsage, cost: Double, sessions: Set<String>)] = [:]
        for session in appState.filteredSessions {
            for (model, modelUsage) in session.modelsUsed {
                var entry = map[model] ?? (usage: TokenUsage(), cost: 0, sessions: Set<String>())
                entry.usage.add(modelUsage)
                entry.cost += ModelPricing.cost(for: model, usage: modelUsage)
                entry.sessions.insert(session.id)
                map[model] = entry
            }
        }
        return map.map { (model: $0.key, usage: $0.value.usage, cost: $0.value.cost, sessionCount: $0.value.sessions.count) }
            .sorted { $0.usage.totalTokens > $1.usage.totalTokens }
    }

    private let colors: [Color] = [.purple, .blue, .teal, .orange, .pink, .green]

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                HStack {
                    Text(l10n.t("Models"))
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    Spacer()
                    TimeRangePicker(startDate: $appState.startDate, endDate: $appState.endDate)
                }

                if modelData.isEmpty {
                    ContentUnavailableView(l10n.t("No Model Data"), systemImage: "cpu", description: Text(l10n.t("No usage data found for the selected time range.")))
                } else {
                    HStack(alignment: .top, spacing: 16) {
                        // Cost by Model bar chart with tooltip
                        VStack(alignment: .leading, spacing: 12) {
                            Text(l10n.t("Cost by Model")).font(.headline)

                            ZStack(alignment: .topLeading) {
                                Chart(Array(modelData.enumerated()), id: \.element.model) { index, item in
                                    BarMark(
                                        x: .value("Model", shortModel(item.model)),
                                        y: .value("Cost", item.cost)
                                    )
                                    .foregroundStyle(colors[index % colors.count])
                                    .cornerRadius(4)
                                    .opacity(hoveredBarModel == nil ? 1.0 : (hoveredBarModel == item.model ? 1.0 : 0.4))
                                }
                                .chartYAxis {
                                    AxisMarks { value in
                                        AxisGridLine()
                                        AxisValueLabel {
                                            if let v = value.as(Double.self) { Text(String(format: "$%.0f", v)) }
                                        }
                                    }
                                }
                                .chartOverlay { proxy in
                                    GeometryReader { geo in
                                        Rectangle().fill(.clear).contentShape(Rectangle())
                                            .onContinuousHover { phase in
                                                switch phase {
                                                case .active(let loc):
                                                    barHoverLocation = loc
                                                    barChartWidth = geo.size.width
                                                    if let name: String = proxy.value(atX: loc.x) {
                                                        hoveredBarModel = modelData.first { shortModel($0.model) == name }?.model
                                                    }
                                                case .ended:
                                                    hoveredBarModel = nil
                                                }
                                            }
                                    }
                                }
                                .frame(height: 220)

                                if let hovered = hoveredBarModel,
                                   let item = modelData.first(where: { $0.model == hovered }) {
                                    let tw: CGFloat = 170
                                    let xOff: CGFloat = barHoverLocation.x + tw + 20 > barChartWidth
                                        ? barHoverLocation.x - tw - 12
                                        : barHoverLocation.x + 16
                                    barTooltip(item: item)
                                        .offset(x: max(0, xOff), y: max(0, barHoverLocation.y - 80))
                                }
                            }
                        }
                        .padding()
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .frame(maxWidth: .infinity)

                        // Token Distribution pie chart with center tooltip
                        VStack(alignment: .leading, spacing: 12) {
                            Text(l10n.t("Token Distribution")).font(.headline)

                            ZStack {
                                Chart(Array(modelData.enumerated()), id: \.element.model) { index, item in
                                    SectorMark(
                                        angle: .value("Tokens", item.usage.totalTokens),
                                        innerRadius: .ratio(0.5),
                                        angularInset: 1.5
                                    )
                                    .foregroundStyle(colors[index % colors.count])
                                    .cornerRadius(4)
                                    .opacity(hoveredPieModel == nil ? 1.0 : (hoveredPieModel == item.model ? 1.0 : 0.4))
                                }
                                .frame(height: 180)

                                if let hovered = hoveredPieModel,
                                   let item = modelData.first(where: { $0.model == hovered }) {
                                    VStack(spacing: 2) {
                                        Text(shortModel(item.model)).font(.caption2).fontWeight(.bold)
                                        Text(fmtTokens(item.usage.totalTokens)).font(.caption2).monospacedDigit()
                                        Text(String(format: "$%.2f", item.cost)).font(.caption2).monospacedDigit().foregroundStyle(.secondary)
                                        Text(pct(item.usage.totalTokens)).font(.caption2).foregroundStyle(.secondary)
                                    }
                                }
                            }

                            ForEach(Array(modelData.enumerated()), id: \.element.model) { index, item in
                                HStack(spacing: 6) {
                                    Circle().fill(colors[index % colors.count]).frame(width: 8, height: 8)
                                    Text(shortModel(item.model)).font(.caption)
                                    Spacer()
                                    Text(pct(item.usage.totalTokens)).font(.caption).foregroundStyle(.secondary)
                                }
                                .contentShape(Rectangle())
                                .onHover { hovering in
                                    hoveredPieModel = hovering ? item.model : nil
                                }
                            }
                        }
                        .padding()
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .frame(width: 260)
                    }

                    ForEach(Array(modelData.enumerated()), id: \.element.model) { index, item in
                        modelCard(item: item, color: colors[index % colors.count])
                    }
                }
            }
            .padding()
        }
    }

    private func barTooltip(item: (model: String, usage: TokenUsage, cost: Double, sessionCount: Int)) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(item.model).font(.caption).fontWeight(.bold)
            HStack { Text("Cost:").font(.caption2); Spacer(); Text(String(format: "$%.2f", item.cost)).font(.caption2).monospacedDigit() }
            HStack { Text("Tokens:").font(.caption2); Spacer(); Text(fmtTokens(item.usage.totalTokens)).font(.caption2).monospacedDigit() }
            HStack { Text("Sessions:").font(.caption2); Spacer(); Text("\(item.sessionCount)").font(.caption2).monospacedDigit() }
            Divider()
            HStack { Text("Input:").font(.caption2).foregroundStyle(.secondary); Spacer(); Text(fmtTokens(item.usage.inputTokens)).font(.caption2).monospacedDigit().foregroundStyle(.secondary) }
            HStack { Text("Output:").font(.caption2).foregroundStyle(.secondary); Spacer(); Text(fmtTokens(item.usage.outputTokens)).font(.caption2).monospacedDigit().foregroundStyle(.secondary) }
        }
        .padding(8)
        .background(.ultraThickMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .shadow(radius: 4)
        .frame(width: 170)
        .allowsHitTesting(false)
    }

    func modelCard(item: (model: String, usage: TokenUsage, cost: Double, sessionCount: Int), color: Color) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Circle().fill(color).frame(width: 12, height: 12)
                Text(item.model).font(.headline)
                Spacer()
                Text(String(format: "$%.2f", item.cost)).font(.title3).fontWeight(.bold).monospacedDigit()
            }
            HStack(spacing: 24) {
                statItem(label: "Input", value: fmtTokens(item.usage.inputTokens))
                statItem(label: "Output", value: fmtTokens(item.usage.outputTokens))
                statItem(label: "Cache Write", value: fmtTokens(item.usage.cacheCreationTokens))
                statItem(label: "Cache Read", value: fmtTokens(item.usage.cacheReadTokens))
                statItem(label: "Total", value: fmtTokens(item.usage.totalTokens))
                statItem(label: "Sessions", value: "\(item.sessionCount)")
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    func statItem(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.subheadline).fontWeight(.medium).monospacedDigit()
        }
    }

    private func shortModel(_ m: String) -> String {
        m.replacingOccurrences(of: "claude-", with: "").replacingOccurrences(of: "-20251001", with: "")
    }

    private func pct(_ tokens: Int64) -> String {
        let total = modelData.reduce(0 as Int64) { $0 + $1.usage.totalTokens }
        guard total > 0 else { return "0%" }
        return String(format: "%.1f%%", Double(tokens) / Double(total) * 100)
    }

    private func fmtTokens(_ t: Int64) -> String {
        if t >= 1_000_000_000 { return String(format: "%.2fB", Double(t) / 1_000_000_000) }
        if t >= 1_000_000 { return String(format: "%.1fM", Double(t) / 1_000_000) }
        if t >= 1_000 { return String(format: "%.1fK", Double(t) / 1_000) }
        return "\(t)"
    }
}
