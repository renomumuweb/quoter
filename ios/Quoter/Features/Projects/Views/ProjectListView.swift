import SwiftUI

struct ProjectListView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                ContentUnavailableView {
                    Label("Projects", systemImage: "folder")
                } description: {
                    Text("Phase 5 will connect customer and project CRUD. The drawing workspace shell is ready for Phase 6.")
                } actions: {
                    NavigationLink("Open Drawing Workspace Preview") {
                        DrawingWorkspaceView()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .navigationTitle("Projects")
        }
    }
}
