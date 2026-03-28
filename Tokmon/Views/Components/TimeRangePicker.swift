import SwiftUI

enum TimeRangePreset: String, CaseIterable, Identifiable {
    case days7 = "7D"
    case days14 = "14D"
    case days30 = "30D"
    case all = "All"

    var id: String { rawValue }
}

struct TimeRangePicker: View {
    @Binding var startDate: Date
    @Binding var endDate: Date

    @State private var showingPopover = false

    var body: some View {
        HStack(spacing: 6) {
            ForEach(TimeRangePreset.allCases) { preset in
                Button(preset.rawValue) {
                    applyPreset(preset)
                }
                .buttonStyle(.plain)
                .font(.caption).fontWeight(.medium)
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(isPresetActive(preset) ? Theme.accentBlue.opacity(0.25) : Color.white.opacity(0.05))
                .foregroundStyle(isPresetActive(preset) ? Theme.accentBlue : Theme.textSecondary)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }

            Divider().frame(height: 20).overlay(Theme.cardBorder)

            Button {
                showingPopover.toggle()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "calendar")
                    Text(dateRangeText).font(.caption)
                }
            }
            .buttonStyle(.plain)
            .foregroundStyle(Theme.textSecondary)
            .popover(isPresented: $showingPopover) {
                VStack(spacing: 12) {
                    Text("Select Date Range")
                        .font(.headline).foregroundStyle(Theme.textPrimary)

                    DatePicker("From", selection: $startDate, in: ...endDate, displayedComponents: .date)
                    DatePicker("To", selection: $endDate, in: startDate...Date(), displayedComponents: .date)

                    HStack {
                        Button("Today") {
                            startDate = Calendar.current.startOfDay(for: Date())
                            endDate = Date()
                        }
                        .buttonStyle(.bordered)

                        Button("This Month") {
                            let cal = Calendar.current
                            startDate = cal.date(from: cal.dateComponents([.year, .month], from: Date()))!
                            endDate = Date()
                        }
                        .buttonStyle(.bordered)

                        Spacer()

                        Button("Done") { showingPopover = false }
                            .buttonStyle(.borderedProminent)
                    }
                }
                .padding()
                .frame(width: 300)
                .background(Theme.cardBg)
            }
        }
    }

    private var dateRangeText: String {
        let f = DateFormatter(); f.dateFormat = "MMM d"
        return "\(f.string(from: startDate)) - \(f.string(from: endDate))"
    }

    private func applyPreset(_ preset: TimeRangePreset) {
        let cal = Calendar.current; endDate = Date()
        switch preset {
        case .days7: startDate = cal.date(byAdding: .day, value: -7, to: cal.startOfDay(for: Date()))!
        case .days14: startDate = cal.date(byAdding: .day, value: -14, to: cal.startOfDay(for: Date()))!
        case .days30: startDate = cal.date(byAdding: .day, value: -30, to: cal.startOfDay(for: Date()))!
        case .all: startDate = Date(timeIntervalSince1970: 0)
        }
    }

    private func isPresetActive(_ preset: TimeRangePreset) -> Bool {
        let cal = Calendar.current; let today = cal.startOfDay(for: Date()); let start = cal.startOfDay(for: startDate)
        switch preset {
        case .days7: return start == cal.date(byAdding: .day, value: -7, to: today)
        case .days14: return start == cal.date(byAdding: .day, value: -14, to: today)
        case .days30: return start == cal.date(byAdding: .day, value: -30, to: today)
        case .all: return start <= cal.date(byAdding: .year, value: -5, to: today)!
        }
    }
}
