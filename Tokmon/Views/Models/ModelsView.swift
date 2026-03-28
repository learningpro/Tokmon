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

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                HStack {
                    Text(l10n.t("Models")).font(.largeTitle).fontWeight(.bold).foregroundStyle(Theme.textPrimary)
                    Spacer()
                    TimeRangePicker(startDate: $appState.startDate, endDate: $appState.endDate)
                }

                if modelData.isEmpty {
                    ContentUnavailableView(l10n.t("No Model Data"), systemImage: "cpu", description: Text(l10n.t("No usage data found for the selected time range.")))
                } else {
                    HStack(alignment: .top, spacing: 16) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(l10n.t("Cost by Model")).font(.headline).foregroundStyle(Theme.textPrimary)
                            ZStack(alignment: .topLeading) {
                                Chart(Array(modelData.enumerated()), id: \.element.model) { index, item in
                                    BarMark(x: .value("Model", shortModel(item.model)), y: .value("Cost", item.cost))
                                        .foregroundStyle(Theme.modelColors[index % Theme.modelColors.count])
                                        .cornerRadius(4)
                                        .opacity(hoveredBarModel == nil ? 1.0 : (hoveredBarModel == item.model ? 1.0 : 0.4))
                                }
                                .chartYAxis {
                                    AxisMarks { value in
                                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5)).foregroundStyle(Color.white.opacity(0.1))
                                        AxisValueLabel { if let v = value.as(Double.self) { Text(String(format: "$%.0f", v)).foregroundStyle(Theme.textTertiary) } }
                                    }
                                }
                                .chartXAxis { AxisMarks { _ in AxisValueLabel().foregroundStyle(Theme.textSecondary) } }
                                .chartOverlay { proxy in
                                    GeometryReader { geo in
                                        Rectangle().fill(.clear).contentShape(Rectangle())
                                            .onContinuousHover { phase in
                                                switch phase {
                                                case .active(let loc):
                                                    barHoverLocation = loc; barChartWidth = geo.size.width
                                                    if let name: String = proxy.value(atX: loc.x) { hoveredBarModel = modelData.first { shortModel($0.model) == name }?.model }
                                                case .ended: hoveredBarModel = nil
                                                }
                                            }
                                    }
                                }
                                .frame(height: 220)

                                if let hovered = hoveredBarModel, let item = modelData.first(where: { $0.model == hovered }) {
                                    let tw: CGFloat = 170
                                    let xOff: CGFloat = barHoverLocation.x + tw + 20 > barChartWidth ? barHoverLocation.x - tw - 12 : barHoverLocation.x + 16
                                    barTooltip(item: item).offset(x: max(0, xOff), y: max(0, barHoverLocation.y - 80))
                                }
                            }
                        }
                        .padding(16).background(Theme.cardBg)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.cardBorder, lineWidth: 1))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .frame(maxWidth: .infinity)

                        VStack(alignment: .leading, spacing: 12) {
                            Text(l10n.t("Token Distribution")).font(.headline).foregroundStyle(Theme.textPrimary)
                            ZStack {
                                Chart(Array(modelData.enumerated()), id: \.element.model) { index, item in
                                    SectorMark(angle: .value("Tokens", item.usage.totalTokens), innerRadius: .ratio(0.5), angularInset: 1.5)
                                        .foregroundStyle(Theme.modelColors[index % Theme.modelColors.count])
                                        .cornerRadius(4)
                                        .opacity(hoveredPieModel == nil ? 1.0 : (hoveredPieModel == item.model ? 1.0 : 0.4))
                                }
                                .frame(height: 180)

                                if let hovered = hoveredPieModel, let item = modelData.first(where: { $0.model == hovered }) {
                                    VStack(spacing: 2) {
                                        Text(shortModel(item.model)).font(.caption2).fontWeight(.bold).foregroundStyle(Theme.textPrimary)
                                        Text(fmtTokens(item.usage.totalTokens)).font(.caption2).monospacedDigit().foregroundStyle(Theme.textSecondary)
                                        Text(String(format: "$%.2f", item.cost)).font(.caption2).monospacedDigit().foregroundStyle(Theme.accentGreen)
                                    }
                                }
                            }

                            ForEach(Array(modelData.enumerated()), id: \.element.model) { index, item in
                                HStack(spacing: 6) {
                                    Circle().fill(Theme.modelColors[index % Theme.modelColors.count]).frame(width: 8, height: 8)
                                    Text(shortModel(item.model)).font(.caption).foregroundStyle(Theme.textPrimary)
                                    Spacer()
                                    Text(String(format: "$%.2f", item.cost)).font(.caption).monospacedDigit().foregroundStyle(Theme.textSecondary)
                                    Text(pct(item.usage.totalTokens)).font(.caption).foregroundStyle(Theme.textTertiary)
                                }
                                .contentShape(Rectangle())
                                .onHover { hovering in hoveredPieModel = hovering ? item.model : nil }
                            }
                        }
                        .padding(16).background(Theme.cardBg)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.cardBorder, lineWidth: 1))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .frame(width: 280)
                    }

                    ForEach(Array(modelData.enumerated()), id: \.element.model) { index, item in
                        modelCard(item: item, color: Theme.modelColors[index % Theme.modelColors.count])
                    }
                }
            }
            .padding(24)
        }
        .background(Theme.mainBg)
    }

    private func barTooltip(item: (model: String, usage: TokenUsage, cost: Double, sessionCount: Int)) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(item.model).font(.caption).fontWeight(.bold).foregroundStyle(Theme.textPrimary)
            HStack { Text("Cost:").font(.caption2).foregroundStyle(Theme.textSecondary); Spacer(); Text(String(format: "$%.2f", item.cost)).font(.caption2).monospacedDigit().foregroundStyle(Theme.accentGreen) }
            HStack { Text("Tokens:").font(.caption2).foregroundStyle(Theme.textSecondary); Spacer(); Text(fmtTokens(item.usage.totalTokens)).font(.caption2).monospacedDigit().foregroundStyle(Theme.textPrimary) }
            HStack { Text("Sessions:").font(.caption2).foregroundStyle(Theme.textSecondary); Spacer(); Text("\(item.sessionCount)").font(.caption2).monospacedDigit().foregroundStyle(Theme.textPrimary) }
        }
        .padding(8).background(Theme.sidebarBg)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.cardBorder, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .shadow(color: .black.opacity(0.4), radius: 8)
        .frame(width: 170).allowsHitTesting(false)
    }

    func modelCard(item: (model: String, usage: TokenUsage, cost: Double, sessionCount: Int), color: Color) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Circle().fill(color).frame(width: 12, height: 12)
                Text(item.model).font(.headline).foregroundStyle(Theme.textPrimary)
                Spacer()
                Text(String(format: "$%.2f", item.cost)).font(.title3).fontWeight(.bold).monospacedDigit().foregroundStyle(Theme.accentGreen)
            }
            HStack(spacing: 24) {
                statItem(label: l10n.t("Input"), value: fmtTokens(item.usage.inputTokens))
                statItem(label: l10n.t("Output"), value: fmtTokens(item.usage.outputTokens))
                statItem(label: l10n.t("Cache Write"), value: fmtTokens(item.usage.cacheCreationTokens))
                statItem(label: l10n.t("Cache Read"), value: fmtTokens(item.usage.cacheReadTokens))
                statItem(label: l10n.t("Total"), value: fmtTokens(item.usage.totalTokens))
                statItem(label: l10n.t("Sessions"), value: "\(item.sessionCount)")
            }
        }
        .padding(16).background(Theme.cardBg)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.cardBorder, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    func statItem(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption).foregroundStyle(Theme.textTertiary)
            Text(value).font(.subheadline).fontWeight(.medium).monospacedDigit().foregroundStyle(Theme.textPrimary)
        }
    }

    private func shortModel(_ m: String) -> String { m.replacingOccurrences(of: "claude-", with: "").replacingOccurrences(of: "-20251001", with: "") }
    private func pct(_ tokens: Int64) -> String {
        let total = modelData.reduce(0 as Int64) { $0 + $1.usage.totalTokens }; guard total > 0 else { return "0%" }
        return String(format: "%.1f%%", Double(tokens) / Double(total) * 100)
    }
    private func fmtTokens(_ t: Int64) -> String {
        if t >= 1_000_000_000 { return String(format: "%.2fB", Double(t) / 1_000_000_000) }
        if t >= 1_000_000 { return String(format: "%.1fM", Double(t) / 1_000_000) }
        if t >= 1_000 { return String(format: "%.1fK", Double(t) / 1_000) }
        return "\(t)"
    }
}
