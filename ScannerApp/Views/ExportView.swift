import SwiftUI

struct ExportView: View {
    @State private var viewModel: ExportViewModel

    init(model: ScannedModel) {
        _viewModel = State(initialValue: ExportViewModel(model: model))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Model Info") {
                    LabeledContent("Name", value: viewModel.model.name)
                    LabeledContent("Vertices", value: viewModel.model.vertexCount.formatted())
                    LabeledContent("Faces", value: viewModel.model.faceCount.formatted())
                    LabeledContent("Size", value: viewModel.model.fileSizeString)
                }

                Section("Export Format") {
                    Picker("Format", selection: $viewModel.selectedFormat) {
                        ForEach(ExportFormat.allCases, id: \.self) { format in
                            Text(format.rawValue).tag(format)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section {
                    ShareLink(item: viewModel.model.fileURL) {
                        Label("Share File", systemImage: "square.and.arrow.up")
                    }
                }
            }
            .navigationTitle("Export")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
