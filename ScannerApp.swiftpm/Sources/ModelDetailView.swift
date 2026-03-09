import SwiftUI
import QuickLook

struct ModelDetailView: View {
    let model: ScannedModel
    @State private var showQuickLook = false

    var body: some View {
        List {
            Section("Model Info") {
                LabeledContent("Name", value: model.name)
                LabeledContent("Vertices", value: model.vertexCount.formatted())
                LabeledContent("Faces", value: model.faceCount.formatted())
                LabeledContent("Format", value: model.format.rawValue)
                LabeledContent("Size", value: model.fileSizeString)
                LabeledContent("Date") {
                    Text(model.dateCreated, style: .date)
                }
            }

            if model.format == .usdz {
                Section {
                    Button {
                        showQuickLook = true
                    } label: {
                        Label("Preview in AR", systemImage: "arkit")
                    }
                }
            }

            Section {
                ShareLink(item: model.fileURL) {
                    Label("Share \(model.format.rawValue) File", systemImage: "square.and.arrow.up")
                }
            }
        }
        .navigationTitle(model.name)
        .navigationBarTitleDisplayMode(.inline)
        .quickLookPreview(Binding(
            get: { showQuickLook ? model.fileURL : nil },
            set: { if $0 == nil { showQuickLook = false } }
        ))
    }
}
