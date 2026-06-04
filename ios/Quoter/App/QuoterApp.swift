import SwiftUI

@main
struct QuoterApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            LocalizedAppRoot(localization: appState.localization)
                .environmentObject(appState)
                .task {
                    await appState.restoreSession()
                }
        }
    }
}

private struct LocalizedAppRoot: View {
    @ObservedObject var localization: AppLocalization

    var body: some View {
        RootView()
            .environmentObject(localization)
            .environment(\.locale, Locale(identifier: localization.language.localeIdentifier))
    }
}
