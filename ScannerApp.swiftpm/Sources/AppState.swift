import Foundation
import ARKit
import Observation

@Observable
final class AppState {
    var scannedModels: [ScannedModel] = []
    var isLiDARAvailable: Bool = false

    init() {
        isLiDARAvailable = LiDARAvailabilityChecker.isSupported
        loadSavedModels()
    }

    func addModel(_ model: ScannedModel) {
        scannedModels.insert(model, at: 0)
        saveModelList()
    }

    func deleteModel(_ model: ScannedModel) {
        scannedModels.removeAll { $0.id == model.id }
        try? FileManager.default.removeItem(at: model.fileURL)
        saveModelList()
    }

    private var modelsListURL: URL {
        URL.documentsDirectory.appending(path: "scanned_models.json")
    }

    private func saveModelList() {
        if let data = try? JSONEncoder().encode(scannedModels) {
            try? data.write(to: modelsListURL)
        }
    }

    private func loadSavedModels() {
        guard let data = try? Data(contentsOf: modelsListURL),
              let models = try? JSONDecoder().decode([ScannedModel].self, from: data) else { return }
        scannedModels = models.filter { FileManager.default.fileExists(atPath: $0.fileURL.path()) }
    }
}
