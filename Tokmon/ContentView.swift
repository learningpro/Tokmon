import SwiftUI

enum SidebarItem: String, CaseIterable, Identifiable {
    case dashboard = "Dashboard"
    case projects = "Projects"
    case models = "Models"
    case sessions = "Sessions"
    case settings = "Settings"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .dashboard: return "chart.bar.fill"
        case .projects: return "folder.fill"
        case .models: return "cpu.fill"
        case .sessions: return "clock.fill"
        case .settings: return "gearshape.fill"
        }
    }
}

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var l10n: L10n
    @State private var selectedItem: SidebarItem = .dashboard

    var body: some View {
        NavigationSplitView {
            List(SidebarItem.allCases, selection: $selectedItem) { item in
                Label(l10n.t(item.rawValue), systemImage: item.icon)
                    .tag(item)
            }
            .navigationSplitViewColumnWidth(min: 160, ideal: 180, max: 220)
            .listStyle(.sidebar)
        } detail: {
            switch selectedItem {
            case .dashboard:
                DashboardView()
            case .projects:
                ProjectsView()
            case .models:
                ModelsView()
            case .sessions:
                SessionsView()
            case .settings:
                SettingsView()
            }
        }
        .navigationTitle("Tokmon")
        .task {
            await appState.loadData()
        }
    }
}
