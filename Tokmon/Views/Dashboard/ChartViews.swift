import SwiftUI
import Charts

struct DailyUsageChartView: View {
    @EnvironmentObject var l10n: L10n
    let dailyData: [DailyUsage]
    @State private var hoverLocation: CGPoint = .zero
    @State private var selectedDate: Date?
    @State private var chartWidth: CGFloat = 600

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(l10n.t("Daily Token Usage"))
                .font(.headline)
                .foregroundStyle(Theme.textPrimary)

            ZStack(alignment: .topLeading) {
                Chart(dailyData) { day in
                    BarMark(
                        x: .value("Date", day.date, unit: .day),
                        y: .value("Tokens", day.usage.totalTokens)
                    )
                    .foregroundStyle(
                        LinearGradient(colors: Theme.chartGradient, startPoint: .bottom, endPoint: .top)
                    )
                    .cornerRadius(4)
                    .opacity(selectedDate == nil ? 1.0 : (Calendar.current.isDate(day.date, inSameDayAs: selectedDate!) ? 1.0 : 0.4))

                    if let selectedDate, Calendar.current.isDate(day.date, inSameDayAs: selectedDate) {
                        RuleMark(x: .value("Selected", selectedDate, unit: .day))
                            .foregroundStyle(Color.white.opacity(0.2))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: 2)) { _ in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5)).foregroundStyle(Color.white.opacity(0.1))
                        AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                            .foregroundStyle(Theme.textTertiary)
                    }
                }
                .chartYAxis {
                    AxisMarks { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5)).foregroundStyle(Color.white.opacity(0.1))
                        AxisValueLabel { if let v = value.as(Int64.self) { Text(fmtTokens(v)).foregroundStyle(Theme.textTertiary) } }
                    }
                }
                .chartOverlay { proxy in
                    GeometryReader { geo in
                        Rectangle().fill(.clear).contentShape(Rectangle())
                            .onContinuousHover { phase in
                                switch phase {
                                case .active(let loc):
                                    hoverLocation = loc; chartWidth = geo.size.width
                                    if let date: Date = proxy.value(atX: loc.x) {
                                        selectedDate = Calendar.current.startOfDay(for: date)
                                    }
                                case .ended: selectedDate = nil
                                }
                            }
                    }
                }
                .frame(height: 250)

                if let selectedDate, let dayData = dailyData.first(where: { Calendar.current.isDate($0.date, inSameDayAs: selectedDate) }) {
                    let tw: CGFloat = 170
                    let xOff: CGFloat = hoverLocation.x + tw + 20 > chartWidth ? hoverLocation.x - tw - 12 : hoverLocation.x + 16
                    barTooltip(day: dayData)
                        .offset(x: max(0, xOff), y: max(0, hoverLocation.y - 120))
                }
            }
        }
        .padding(16)
        .background(Theme.cardBg)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.cardBorder, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func barTooltip(day: DailyUsage) -> some View {
        let f = DateFormatter(); f.dateFormat = "MMM d, yyyy"
        return VStack(alignment: .leading, spacing: 4) {
            Text(f.string(from: day.date)).font(.caption).fontWeight(.bold).foregroundStyle(Theme.textPrimary)
            HStack { Text("Tokens:").font(.caption2).foregroundStyle(Theme.textSecondary); Spacer(); Text(fmtTokens(day.usage.totalTokens)).font(.caption2).monospacedDigit().foregroundStyle(Theme.textPrimary) }
            HStack { Text("Cost:").font(.caption2).foregroundStyle(Theme.textSecondary); Spacer(); Text(String(format: "$%.2f", day.cost)).font(.caption2).monospacedDigit().foregroundStyle(Theme.accentGreen) }
            if !day.modelsUsed.isEmpty {
                Divider().overlay(Theme.cardBorder)
                ForEach(Array(day.modelsUsed.sorted { $0.value.totalTokens > $1.value.totalTokens }), id: \.key) { model, usage in
                    HStack {
                        Text(shortModel(model)).font(.caption2).foregroundStyle(Theme.textTertiary)
                        Spacer()
                        Text(fmtTokens(usage.totalTokens)).font(.caption2).monospacedDigit().foregroundStyle(Theme.textTertiary)
                    }
                }
            }
        }
        .padding(10)
        .background(Theme.sidebarBg)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.cardBorder, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .shadow(color: .black.opacity(0.4), radius: 8)
        .frame(width: 170)
        .allowsHitTesting(false)
    }

    private func shortModel(_ m: String) -> String { m.replacingOccurrences(of: "claude-", with: "").replacingOccurrences(of: "-20251001", with: "") }
    private func fmtTokens(_ t: Int64) -> String {
        if t >= 1_000_000_000 { return String(format: "%.1fB", Double(t) / 1_000_000_000) }
        if t >= 1_000_000 { return String(format: "%.1fM", Double(t) / 1_000_000) }
        if t >= 1_000 { return String(format: "%.0fK", Double(t) / 1_000) }
        return "\(t)"
    }
}

struct ModelDistributionChartView: View {
    @EnvironmentObject var l10n: L10n
    let modelData: [(model: String, tokens: Int64, cost: Double)]
    @State private var hoveredModel: String?
    @State private var hoverLocation: CGPoint = .zero

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(l10n.t("Model Distribution"))
                .font(.headline)
                .foregroundStyle(Theme.textPrimary)

            if modelData.isEmpty {
                Text("No data").foregroundStyle(Theme.textSecondary).frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ZStack(alignment: .topLeading) {
                    Chart(Array(modelData.enumerated()), id: \.element.model) { index, item in
                        SectorMark(
                            angle: .value("Tokens", item.tokens),
                            innerRadius: .ratio(0.5),
                            angularInset: 1.5
                        )
                        .foregroundStyle(Theme.modelColors[index % Theme.modelColors.count])
                        .cornerRadius(4)
                        .opacity(hoveredModel == nil ? 1.0 : (hoveredModel == item.model ? 1.0 : 0.4))
                    }
                    .chartOverlay { _ in
                        GeometryReader { geo in
                            Rectangle().fill(.clear).contentShape(Rectangle())
                                .onContinuousHover { phase in
                                    switch phase {
                                    case .active(let loc):
                                        hoverLocation = loc
                                        let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
                                        let dx = loc.x - center.x; let dy = loc.y - center.y
                                        let dist = sqrt(dx * dx + dy * dy)
                                        let outerR = min(geo.size.width, geo.size.height) / 2
                                        if dist >= outerR * 0.5 && dist <= outerR {
                                            var angle = atan2(dx, -dy); if angle < 0 { angle += 2 * .pi }
                                            let totalTokens = modelData.reduce(0 as Int64) { $0 + $1.tokens }
                                            var cumAngle: Double = 0; hoveredModel = nil
                                            for item in modelData {
                                                let sliceAngle = Double(item.tokens) / Double(totalTokens) * 2 * .pi
                                                if angle >= cumAngle && angle < cumAngle + sliceAngle { hoveredModel = item.model; break }
                                                cumAngle += sliceAngle
                                            }
                                        } else { hoveredModel = nil }
                                    case .ended: hoveredModel = nil
                                    }
                                }
                        }
                    }
                    .frame(height: 160)

                    if let hovered = hoveredModel, let item = modelData.first(where: { $0.model == hovered }) {
                        pieTooltip(item: item)
                            .offset(x: max(0, min(hoverLocation.x + 12, 100)), y: max(0, hoverLocation.y + 12))
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(modelData.enumerated()), id: \.element.model) { index, item in
                        HStack(spacing: 6) {
                            Circle().fill(Theme.modelColors[index % Theme.modelColors.count]).frame(width: 8, height: 8)
                            Text(shortName(item.model)).font(.caption).foregroundStyle(Theme.textPrimary)
                            Spacer()
                            Text(String(format: "$%.2f", item.cost)).font(.caption).monospacedDigit().foregroundStyle(Theme.textSecondary)
                            Text(pct(item.tokens)).font(.caption).foregroundStyle(Theme.textTertiary)
                        }
                        .contentShape(Rectangle())
                        .onHover { hovering in hoveredModel = hovering ? item.model : nil }
                    }
                }
            }
        }
        .padding(16)
        .background(Theme.cardBg)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.cardBorder, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func pieTooltip(item: (model: String, tokens: Int64, cost: Double)) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(shortName(item.model)).font(.caption).fontWeight(.bold).foregroundStyle(Theme.textPrimary)
            HStack { Text("Tokens:").font(.caption2).foregroundStyle(Theme.textSecondary); Spacer(); Text(fmtTokens(item.tokens)).font(.caption2).monospacedDigit().foregroundStyle(Theme.textPrimary) }
            HStack { Text("Cost:").font(.caption2).foregroundStyle(Theme.textSecondary); Spacer(); Text(String(format: "$%.2f", item.cost)).font(.caption2).monospacedDigit().foregroundStyle(Theme.accentGreen) }
            Text(pct(item.tokens)).font(.caption2).foregroundStyle(Theme.textTertiary)
        }
        .padding(8).background(Theme.sidebarBg)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.cardBorder, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .shadow(color: .black.opacity(0.4), radius: 8)
        .frame(width: 150).allowsHitTesting(false)
    }

    private func shortName(_ m: String) -> String { m.replacingOccurrences(of: "claude-", with: "").replacingOccurrences(of: "-20251001", with: "") }
    private func pct(_ tokens: Int64) -> String {
        let total = modelData.reduce(0) { $0 + $1.tokens }; guard total > 0 else { return "0%" }
        return String(format: "%.0f%%", Double(tokens) / Double(total) * 100)
    }
    private func fmtTokens(_ t: Int64) -> String {
        if t >= 1_000_000_000 { return String(format: "%.2fB", Double(t) / 1_000_000_000) }
        if t >= 1_000_000 { return String(format: "%.1fM", Double(t) / 1_000_000) }
        if t >= 1_000 { return String(format: "%.0fK", Double(t) / 1_000) }
        return "\(t)"
    }
}
