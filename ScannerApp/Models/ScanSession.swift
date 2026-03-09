import Foundation
import ARKit

enum ScanState {
    case ready
    case scanning
    case paused
    case completed
}

struct ScanSession: Identifiable {
    let id = UUID()
    var startDate = Date()
    var meshAnchors: [ARMeshAnchor] = []
    var state: ScanState = .ready

    var anchorCount: Int { meshAnchors.count }

    var totalVertexCount: Int {
        meshAnchors.reduce(0) { $0 + $1.geometry.vertices.count }
    }

    var totalFaceCount: Int {
        meshAnchors.reduce(0) { $0 + $1.geometry.faces.count }
    }
}
