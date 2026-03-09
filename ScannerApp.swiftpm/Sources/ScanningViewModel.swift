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
    var visualizationMode: VisualizationMode = .mesh
    var isCapturingColors = false

    /// The merged mesh from the most recent completed scan, available for editing/simplification.
    var lastMergedMesh: MergedMesh?

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

    var canUndo: Bool {
        scanningService.canUndo
    }

    var canRedo: Bool {
        scanningService.canRedo
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

    func saveUndoPoint() {
        scanningService.saveUndoPoint()
    }

    func undo() {
        scanningService.undo()
    }

    func redo() {
        scanningService.redo()
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

            var mergedMesh = MeshProcessingService.mergeMeshAnchors(anchors)

            // Capture colors from the latest camera frame if available
            if let frame = scanningService.latestFrame {
                isCapturingColors = true
                let colors = ColorCaptureService.captureColors(for: anchors, from: frame)
                if !colors.isEmpty {
                    mergedMesh = MergedMesh(
                        vertices: mergedMesh.vertices,
                        normals: mergedMesh.normals,
                        faces: mergedMesh.faces,
                        colors: colors
                    )
                }
                isCapturingColors = false
            }

            lastMergedMesh = mergedMesh

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
                format: format,
                hasColors: mergedMesh.hasColors
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
