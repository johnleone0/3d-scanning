import Foundation
import RealityKit
import Observation

@Observable
final class ModelPreviewViewModel {
    let model: ScannedModel
    var isLoading = true
    var errorMessage: String?

    init(model: ScannedModel) {
        self.model = model
    }

    var modelExists: Bool {
        FileManager.default.fileExists(atPath: model.fileURL.path())
    }

    var modelInfo: String {
        """
        Name: \(model.name)
        Vertices: \(model.vertexCount.formatted())
        Faces: \(model.faceCount.formatted())
        Format: \(model.format.rawValue)
        Size: \(model.fileSizeString)
        """
    }
}
