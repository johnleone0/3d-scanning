import SwiftUI
import QuickLook

struct ModelPreviewView: View {
    let model: ScannedModel
    @State private var showExport = false
    @State private var showQuickLook = false

    var body: some View {
        VStack(spacing: 0) {
            // Model info card
            VStack(alignment: .leading, spacing: 8) {
                Label(model.name, systemImage: "cube.fill")
                    .font(.title2.bold())

                Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 4) {
                    GridRow {
                        Text("Vertices").foregroundStyle(.secondary)
                        Text(model.vertexCount.formatted())
                    }
                    GridRow {
                        Text("Faces").foregroundStyle(.secondary)
                        Text(model.faceCount.formatted())
                    }
                    GridRow {
                        Text("Format").foregroundStyle(.secondary)
                        Text(model.format.rawValue)
                    }
                    GridRow {
                        Text("Size").foregroundStyle(.secondary)
                        Text(model.fileSizeString)
                    }
                    GridRow {
                        Text("Date").foregroundStyle(.secondary)
                        Text(model.dateCreated, style: .date)
                    }
                }
                .font(.subheadline)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.systemGroupedBackground))

            Divider()

            // 3D Preview
            if model.format == .usdz {
                // USDZ files can use QuickLook for 3D preview
                Button {
                    showQuickLook = true
                } label: {
                    VStack(spacing: 12) {
                        Image(systemName: "arkit")
                            .font(.system(size: 60))
                            .foregroundStyle(.blue)
                        Text("Tap to Preview in 3D")
                            .font(.headline)
                        Text("Uses AR Quick Look")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .quickLookPreview($quickLookURL)
            } else {
                // OBJ files show file info
                VStack(spacing: 12) {
                    Image(systemName: "cube.transparent")
                        .font(.system(size: 60))
                        .foregroundStyle(.secondary)
                    Text("3D Model Saved")
                        .font(.headline)
                    Text("Export as USDZ for AR preview, or share the OBJ file.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle("Preview")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                ShareLink(item: model.fileURL) {
                    Image(systemName: "square.and.arrow.up")
                }
            }
        }
    }

    private var quickLookURL: Binding<URL?> {
        Binding(
            get: { showQuickLook ? model.fileURL : nil },
            set: { if $0 == nil { showQuickLook = false } }
        )
    }
}
