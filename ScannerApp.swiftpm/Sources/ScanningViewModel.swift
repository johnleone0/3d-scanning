import Foundation
import ARKit
import Observation

@Observable
final class ScanningViewModel {
    let scanningService = LiDARScanningService()
    var scanName: String = ""
    var isProcessing = false
    var exportedModel: ScannedModel?
    var errorMessage: String?

    var scanState: ScanState {
        scanningService.scanState
    }

    var anchorCount: Int {
        scanningService.anchorCount
    }

    var vertexCount: Int {
        scanningService.totalVertexCount
    }

    var faceCount: Int {
        scanningService.totalFaceCount
    }

    func startScan() {
        scanName = "Scan_\(Self.dateFormatter.string(from: Date()))"
        scanningService.startScanning()
    }

    func pauseScan() {
        scanningService.pauseScanning()
    }

    func resumeScan() {
        scanningService.resumeScanning()
    }

    func finishScan(format: ExportFormat = .obj) async -> ScannedModel? {
        scanningService.stopScanning()
        isProcessing = true
        errorMessage = nil

        do {
            let anchors = scanningService.collectMeshAnchors()
            guard !anchors.isEmpty else {
                errorMessage = "No mesh data captured. Try scanning again."
                isProcessing = false
                return nil
            }

            let mergedMesh = MeshProcessingService.mergeMeshAnchors(anchors)

            let fileURL = try ModelExportService.export(
                mesh: mergedMesh,
                name: scanName,
                format: format
            )

            let model = ScannedModel(
                id: UUID(),
                name: scanName,
                dateCreated: Date(),
                fileURL: fileURL,
                vertexCount: mergedMesh.vertices.count,
                faceCount: mergedMesh.faceCount,
                format: format
            )

            exportedModel = model
            isProcessing = false
            return model
        } catch {
            errorMessage = error.localizedDescription
            isProcessing = false
            return nil
        }
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd_HHmmss"
        return f
    }()
}
