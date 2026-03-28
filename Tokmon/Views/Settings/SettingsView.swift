import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var l10n: L10n
    @AppStorage("claudeDataPath") private var claudeDataPath = "~/.claude/projects"

    @State private var editingPrices: [String: ModelPricing.Price] = [:]
    @State private var newModelName = ""
    @State private var showingAddModel = false
    @State private var selectedLang: String = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text(l10n.t("Settings"))
                    .font(.largeTitle).fontWeight(.bold).foregroundStyle(Theme.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // Data Source
                settingsCard(title: l10n.t("Data Source")) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(l10n.t("Claude Data Path")).font(.caption).foregroundStyle(Theme.textTertiary)
                        HStack {
                            TextField("", text: $claudeDataPath)
                                .textFieldStyle(.roundedBorder)
                            Button(l10n.t("Reload Data")) {
                                appState.claudeDataPath = claudeDataPath
                                Task { await appState.loadData() }
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        Text(NSString(string: claudeDataPath).expandingTildeInPath)
                            .font(.caption2).foregroundStyle(Theme.textTertiary)
                    }
                }

                // Appearance & Language
                settingsCard(title: l10n.t("Language")) {
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

                // Model Pricing
                settingsCard(title: l10n.t("Model Pricing (USD per 1M tokens)")) {
                    VStack(spacing: 16) {
                        ForEach(Array(editingPrices.keys.sorted()), id: \.self) { model in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(model).fontWeight(.medium).foregroundStyle(Theme.textPrimary)
                                HStack(spacing: 12) {
                                    priceField(l10n.t("Input"), value: bindingFor(model, keyPath: \.inputPerMillion))
                                    priceField(l10n.t("Output"), value: bindingFor(model, keyPath: \.outputPerMillion))
                                    priceField(l10n.t("Cache Write"), value: bindingFor(model, keyPath: \.cacheWritePerMillion))
                                    priceField(l10n.t("Cache Read"), value: bindingFor(model, keyPath: \.cacheReadPerMillion))
                                }
                                Divider().overlay(Theme.cardBorder)
                            }
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
                                    showingAddModel = false; newModelName = ""
                                }
                            }
                        }

                        HStack {
                            Button(l10n.t("Add Model")) { showingAddModel = true }
                                .foregroundStyle(Theme.accentBlue)
                            Spacer()
                            Button(l10n.t("Reset to Defaults")) {
                                ModelPricing.resetToDefaults()
                                loadPrices()
                            }
                            .foregroundStyle(.red)
                        }
                    }
                }

                // About
                settingsCard(title: l10n.t("About")) {
                    HStack {
                        Text("Tokmon").fontWeight(.medium).foregroundStyle(Theme.textPrimary)
                        Spacer()
                        Text("v1.0.0").foregroundStyle(Theme.textTertiary)
                    }
                }
            }
            .padding(24)
        }
        .background(Theme.mainBg)
        .onAppear {
            loadPrices()
            selectedLang = l10n.lang
        }
    }

    func settingsCard(title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.headline).foregroundStyle(Theme.textPrimary)
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.cardBg)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.cardBorder, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    func priceField(_ label: String, value: Binding<Double>) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption2).foregroundStyle(Theme.textTertiary)
            TextField("", value: value, format: .number.precision(.fractionLength(2)))
                .textFieldStyle(.roundedBorder)
                .frame(width: 80)
                .monospacedDigit()
        }
    }

    private func loadPrices() { editingPrices = ModelPricing.prices }

    private func saveAllPrices() {
        for (model, price) in editingPrices { ModelPricing.savePrice(for: model, price: price) }
    }

    private func bindingFor(_ model: String, keyPath: WritableKeyPath<ModelPricing.Price, Double>) -> Binding<Double> {
        Binding(
            get: { editingPrices[model]?[keyPath: keyPath] ?? 0 },
            set: { newValue in
                editingPrices[model]?[keyPath: keyPath] = newValue
                if let price = editingPrices[model] { ModelPricing.savePrice(for: model, price: price) }
            }
        )
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
