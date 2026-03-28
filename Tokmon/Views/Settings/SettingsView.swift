import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var l10n: L10n
    @AppStorage("claudeDataPath") private var claudeDataPath = "~/.claude/projects"
    @AppStorage("appearanceMode") private var appearanceMode: AppearanceMode = .system

    @State private var editingPrices: [String: ModelPricing.Price] = [:]
    @State private var newModelName = ""
    @State private var showingAddModel = false
    @State private var selectedLang: String = ""

    var body: some View {
        Form {
            Section(l10n.t("Data Source")) {
                TextField(l10n.t("Claude Data Path"), text: $claudeDataPath)
                    .textFieldStyle(.roundedBorder)
                HStack {
                    Text(NSString(string: claudeDataPath).expandingTildeInPath)
                        .font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Button(l10n.t("Reload Data")) {
                        appState.claudeDataPath = claudeDataPath
                        Task { await appState.loadData() }
                    }
                }
            }

            Section(l10n.t("Appearance")) {
                Picker(l10n.t("Theme"), selection: $appearanceMode) {
                    Text(l10n.t("System")).tag(AppearanceMode.system)
                    Text(l10n.t("Light")).tag(AppearanceMode.light)
                    Text(l10n.t("Dark")).tag(AppearanceMode.dark)
                }
                .pickerStyle(.segmented)
            }

            Section(l10n.t("Language")) {
                HStack {
                    Picker(l10n.t("Language"), selection: $selectedLang) {
                        ForEach(AppLanguage.allCases) { lang in
                            Text(lang.rawValue).tag(lang.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)

                    Button(l10n.t("Save & Apply")) {
                        l10n.lang = selectedLang
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(selectedLang == l10n.lang)
                }
            }

            Section {
                ForEach(Array(editingPrices.keys.sorted()), id: \.self) { model in
                    EditablePricingRow(model: model, price: binding(for: model), l10n: l10n)
                }

                if showingAddModel {
                    HStack {
                        TextField("Model name (e.g. gpt-4o)", text: $newModelName)
                            .textFieldStyle(.roundedBorder)
                        Button(l10n.t("Add")) {
                            if !newModelName.isEmpty {
                                editingPrices[newModelName] = ModelPricing.defaultPrice
                                newModelName = ""
                                showingAddModel = false
                                saveAllPrices()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        Button(l10n.t("Cancel")) {
                            showingAddModel = false
                            newModelName = ""
                        }
                    }
                }

                HStack {
                    Button(l10n.t("Add Model")) { showingAddModel = true }
                    Spacer()
                    Button(l10n.t("Reset to Defaults")) {
                        ModelPricing.resetToDefaults()
                        loadPrices()
                    }
                    .foregroundStyle(.red)
                }
            } header: {
                Text(l10n.t("Model Pricing (USD per 1M tokens)"))
            }

            Section(l10n.t("About")) {
                HStack {
                    Text("Tokmon").fontWeight(.medium)
                    Spacer()
                    Text("v1.0.0").foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 550, minHeight: 500)
        .onAppear {
            loadPrices()
            selectedLang = l10n.lang
        }
    }

    private func loadPrices() { editingPrices = ModelPricing.prices }

    private func saveAllPrices() {
        for (model, price) in editingPrices {
            ModelPricing.savePrice(for: model, price: price)
        }
    }

    private func binding(for model: String) -> Binding<ModelPricing.Price> {
        Binding(
            get: { editingPrices[model] ?? ModelPricing.defaultPrice },
            set: { newValue in
                editingPrices[model] = newValue
                ModelPricing.savePrice(for: model, price: newValue)
            }
        )
    }
}

struct EditablePricingRow: View {
    let model: String
    @Binding var price: ModelPricing.Price
    let l10n: L10n

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(model).fontWeight(.medium)
            HStack(spacing: 12) {
                priceField(l10n.t("Input"), value: $price.inputPerMillion)
                priceField(l10n.t("Output"), value: $price.outputPerMillion)
                priceField(l10n.t("Cache Write"), value: $price.cacheWritePerMillion)
                priceField(l10n.t("Cache Read"), value: $price.cacheReadPerMillion)
            }
        }
        .padding(.vertical, 4)
    }

    func priceField(_ label: String, value: Binding<Double>) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption2).foregroundStyle(.secondary)
            TextField("", value: value, format: .number.precision(.fractionLength(2)))
                .textFieldStyle(.roundedBorder)
                .frame(width: 80)
                .monospacedDigit()
        }
    }
}

enum AppearanceMode: String, CaseIterable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"
}

enum AppLanguage: String, CaseIterable, Identifiable {
    case en = "English"
    case zh = "中文"
    var id: String { rawValue }
}
