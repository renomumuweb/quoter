import SwiftUI

struct DrawingWorkspaceView: View {
    @State private var drawingData = Data()
    @State private var selectedObjectID: UUID?
    @State private var objects = [DrawingObject.preview]
    @State private var annotations = [DrawingAnnotation.preview]

    var body: some View {
        HStack(spacing: 0) {
            projectPanel
                .frame(width: 230)
                .background(Color(.secondarySystemGroupedBackground))

            ZStack {
                CanvasGridView()
                PencilCanvasView(drawingData: $drawingData)
                ForEach(objects) { object in
                    ProductObjectOverlayView(
                        object: object,
                        isSelected: selectedObjectID == object.id
                    )
                    .onTapGesture {
                        selectedObjectID = object.id
                    }
                }
                ForEach(annotations) { annotation in
                    AnnotationOverlayView(annotation: annotation)
                }
            }
            .clipped()
            .background(Color(.systemBackground))

            inspectorPanel
                .frame(width: 320)
                .background(Color(.secondarySystemGroupedBackground))
        }
        .navigationTitle("Drawing Workspace")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var projectPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Smith Bathroom", systemImage: "folder")
                .font(.headline)
            Text("Layers")
                .font(.subheadline.weight(.semibold))
            Toggle("Drawing", isOn: .constant(true))
            Toggle("Objects", isOn: .constant(true))
            Toggle("Annotations", isOn: .constant(true))
            Divider()
            Button("Save Draft") {}
                .buttonStyle(.borderedProminent)
            Text("PencilKit data is cached locally in Phase 1 and will upload by pre-signed URL in Phase 6.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding()
    }

    private var inspectorPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Inspector")
                .font(.headline)

            Button("Add Vanity Object") {
                objects.append(DrawingObject.preview)
            }
            .buttonStyle(.borderedProminent)

            Button("Add Annotation") {
                annotations.append(DrawingAnnotation.preview)
            }
            .buttonStyle(.bordered)

            Divider()

            if let selected = objects.first(where: { $0.id == selectedObjectID }) {
                Text(selected.objectType.capitalized)
                    .font(.title3.weight(.semibold))
                LabeledContent("Quantity", value: "\(selected.quantity)")
                LabeledContent("Unit", value: selected.unit)
                LabeledContent("Quote", value: selected.isQuoteEnabled ? "Enabled" : "Hidden")
                Text(selected.notes)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                Text("Select an object to bind products, edit quantity, discounts, install fees, and quote visibility in later phases.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding()
    }
}
