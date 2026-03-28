import SwiftUI

@main
struct TokmonApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var l10n = L10n.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .environmentObject(l10n)
                .frame(minWidth: 900, minHeight: 600)
                .preferredColorScheme(.dark)
        }
        .windowStyle(.titleBar)
        .defaultSize(width: 1200, height: 800)

        Settings {
            SettingsView()
                .environmentObject(appState)
                .environmentObject(l10n)
                .preferredColorScheme(.dark)
        }
    }
}
