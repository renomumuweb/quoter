import SwiftUI

@main
struct QuoterApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .task {
                    await appState.restoreSession()
                }
        }
    }
}
