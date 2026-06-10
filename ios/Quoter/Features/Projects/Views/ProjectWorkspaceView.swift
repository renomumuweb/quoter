import SwiftUI

struct ProjectWorkspaceView: View {
    let project: Project

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text(project.title)
                        .font(.title3.weight(.semibold))
                    HStack(spacing: 12) {
                        Label(project.customerName ?? AppLanguage.localizedString("Customer"), systemImage: "person")
                        Label(Project.serviceScopeTitle(project.roomType), systemImage: "square.grid.2x2")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }

            Section("Project Tools") {
                NavigationLink {
                    DrawingWorkspaceView(project: project)
                } label: {
                    ProjectToolRow(
                        title: "Drawing",
                        subtitle: "Layout, measurements, product objects, and annotations",
                        systemImage: "pencil.and.ruler"
                    )
                }

                NavigationLink {
                    EstimateTemplateView(project: project)
                } label: {
                    ProjectToolRow(
                        title: "Estimate Template",
                        subtitle: "Broad contractor categories with custom quote items",
                        systemImage: "list.bullet.clipboard"
                    )
                }
            }
        }
        .navigationTitle("Project")
    }
}

private struct ProjectToolRow: View {
    let title: String
    let subtitle: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(.blue)
                .frame(width: 34, height: 34)
                .background(Color.blue.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 4) {
                Text(LocalizedStringKey(title))
                    .font(.headline)
                Text(LocalizedStringKey(subtitle))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            .padding(.vertical, 4)
        }
    }
}
