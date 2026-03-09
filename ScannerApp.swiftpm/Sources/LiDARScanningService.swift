import ARKit
import RealityKit
import Observation

/// Snapshot of anchor UUIDs at a point in time, used for undo/redo.
struct UndoSnapshot {
    let anchorIDs: Set<UUID>
}

@Observable
final class LiDARScanningService: NSObject, ARSessionDelegate {
    let arSession = ARSession()
    private(set) var meshAnchors: [UUID: ARMeshAnchor] = [:]
    private(set) var scanState: ScanState = .ready
    private(set) var lastError: String?

    /// The most recent camera frame delivered by ARKit.
    private(set) var latestFrame: ARFrame?

    // MARK: - Undo / Redo

    private var undoStack: [UndoSnapshot] = []
    private var redoStack: [UndoSnapshot] = []

    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }

    // MARK: - Computed Properties

    var anchorCount: Int { meshAnchors.count }

    var totalVertexCount: Int {
        meshAnchors.values.reduce(0) { $0 + $1.geometry.vertices.count }
    }

    var totalFaceCount: Int {
        meshAnchors.values.reduce(0) { $0 + $1.geometry.faces.count }
    }

    // MARK: - Init

    override init() {
        super.init()
        arSession.delegate = self
    }

    // MARK: - Scanning Control

    func startScanning() {
        guard LiDARAvailabilityChecker.isSupported else {
            lastError = "This device does not support LiDAR scanning."
            return
        }

        meshAnchors.removeAll()
        undoStack.removeAll()
        redoStack.removeAll()
        latestFrame = nil
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

    // MARK: - Undo / Redo Support

    /// Saves the current set of anchor UUIDs as an undo point.
    func saveUndoPoint() {
        let snapshot = UndoSnapshot(anchorIDs: Set(meshAnchors.keys))
        undoStack.append(snapshot)
        // Any new action invalidates the redo history.
        redoStack.removeAll()
    }

    /// Reverts to the most recent undo snapshot by removing anchors that were
    /// added after that snapshot was taken.
    func undo() {
        guard let snapshot = undoStack.popLast() else { return }

        // Save current state for redo.
        let currentSnapshot = UndoSnapshot(anchorIDs: Set(meshAnchors.keys))
        redoStack.append(currentSnapshot)

        // Remove anchors that are not in the snapshot.
        let toRemove = Set(meshAnchors.keys).subtracting(snapshot.anchorIDs)
        for id in toRemove {
            meshAnchors.removeValue(forKey: id)
        }
    }

    /// Restores the state that was undone most recently.
    func redo() {
        guard let snapshot = redoStack.popLast() else { return }

        // Save current state for undo.
        let currentSnapshot = UndoSnapshot(anchorIDs: Set(meshAnchors.keys))
        undoStack.append(currentSnapshot)

        // Redo cannot resurrect anchors that ARKit has removed from the session,
        // but it restores the set of tracked IDs. Anchors still held in the
        // session's current frame will already be in meshAnchors; those that
        // were removed by undo but are still available can be re-added from
        // the session's current anchors.
        if let currentAnchors = arSession.currentFrame?.anchors {
            for anchor in currentAnchors.compactMap({ $0 as? ARMeshAnchor }) {
                if snapshot.anchorIDs.contains(anchor.identifier) {
                    meshAnchors[anchor.identifier] = anchor
                }
            }
        }
    }

    // MARK: - ARSessionDelegate

    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        latestFrame = frame
    }

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
