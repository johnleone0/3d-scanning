import ARKit
import RealityKit
import Observation

@Observable
final class LiDARScanningService: NSObject, ARSessionDelegate {
    let arSession = ARSession()
    private(set) var meshAnchors: [UUID: ARMeshAnchor] = [:]
    private(set) var scanState: ScanState = .ready
    private(set) var lastError: String?

    var anchorCount: Int { meshAnchors.count }

    var totalVertexCount: Int {
        meshAnchors.values.reduce(0) { $0 + $1.geometry.vertices.count }
    }

    var totalFaceCount: Int {
        meshAnchors.values.reduce(0) { $0 + $1.geometry.faces.count }
    }

    override init() {
        super.init()
        arSession.delegate = self
    }

    func startScanning() {
        guard LiDARAvailabilityChecker.isSupported else {
            lastError = "This device does not support LiDAR scanning."
            return
        }

        meshAnchors.removeAll()
        lastError = nil

        let config = ARWorldTrackingConfiguration()
        config.sceneReconstruction = .meshWithClassification
        config.environmentTexturing = .automatic

        if let hiRes = ARWorldTrackingConfiguration.supportedVideoFormats
            .filter({ $0.captureDevicePosition == .back })
            .sorted(by: { $0.imageResolution.width > $1.imageResolution.width })
            .first {
            config.videoFormat = hiRes
        }

        if ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth) {
            config.frameSemantics.insert(.sceneDepth)
        }

        arSession.run(config, options: [.removeExistingAnchors, .resetTracking])
        scanState = .scanning
    }

    func pauseScanning() {
        arSession.pause()
        scanState = .paused
    }

    func resumeScanning() {
        let config = ARWorldTrackingConfiguration()
        config.sceneReconstruction = .meshWithClassification
        config.environmentTexturing = .automatic
        if ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth) {
            config.frameSemantics.insert(.sceneDepth)
        }
        arSession.run(config)
        scanState = .scanning
    }

    func stopScanning() {
        arSession.pause()
        scanState = .completed
    }

    func collectMeshAnchors() -> [ARMeshAnchor] {
        Array(meshAnchors.values)
    }

    // MARK: - ARSessionDelegate

    func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        for anchor in anchors.compactMap({ $0 as? ARMeshAnchor }) {
            meshAnchors[anchor.identifier] = anchor
        }
    }

    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        for anchor in anchors.compactMap({ $0 as? ARMeshAnchor }) {
            meshAnchors[anchor.identifier] = anchor
        }
    }

    func session(_ session: ARSession, didRemove anchors: [ARAnchor]) {
        for anchor in anchors.compactMap({ $0 as? ARMeshAnchor }) {
            meshAnchors.removeValue(forKey: anchor.identifier)
        }
    }

    func session(_ session: ARSession, didFailWithError error: Error) {
        lastError = error.localizedDescription
    }
}
