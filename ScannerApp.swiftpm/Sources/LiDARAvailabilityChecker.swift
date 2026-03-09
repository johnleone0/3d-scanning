import ARKit

struct LiDARAvailabilityChecker {
    static var isSupported: Bool {
        ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh)
    }
}
