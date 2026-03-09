import Foundation
import Observation

@Observable
final class ExportViewModel {
    let model: ScannedModel
    var selectedFormat: ExportFormat
    var isExporting = false
    var exportedURL: URL?
    var errorMessage: String?
    var showShareSheet = false

    init(model: ScannedModel) {
        self.model = model
        self.selectedFormat = model.format
    }

    func export() async {
        isExporting = true
        errorMessage = nil

        // If already in the desired format, just use existing file
        if selectedFormat == model.format {
            exportedURL = model.fileURL
            isExporting = false
            showShareSheet = true
            return
        }

        // Re-export would require re-reading the mesh, which isn't straightforward
        // from a saved file. For now, share the original file.
        exportedURL = model.fileURL
        isExporting = false
        showShareSheet = true
    }
}
