import ARKit
import simd

struct MergedMesh {
    var vertices: [SIMD3<Float>]
    var normals: [SIMD3<Float>]
    var faces: [UInt32]
    var faceCount: Int { faces.count / 3 }
}

struct MeshProcessingService {

    static func mergeMeshAnchors(_ anchors: [ARMeshAnchor]) -> MergedMesh {
        var allVertices: [SIMD3<Float>] = []
        var allNormals: [SIMD3<Float>] = []
        var allFaces: [UInt32] = []

        for anchor in anchors {
            let geometry = anchor.geometry
            let vertexOffset = UInt32(allVertices.count)

            let vertices = geometry.vertices.asFloat3Array()
            let normals = geometry.normals.asFloat3Array()
            let transform = anchor.transform

            for i in 0..<vertices.count {
                let localPos = vertices[i]
                let worldPos = transform * SIMD4<Float>(localPos.x, localPos.y, localPos.z, 1.0)
                allVertices.append(SIMD3<Float>(worldPos.x, worldPos.y, worldPos.z))

                if i < normals.count {
                    let localNormal = normals[i]
                    let worldNormal = transform * SIMD4<Float>(localNormal.x, localNormal.y, localNormal.z, 0.0)
                    let n = SIMD3<Float>(worldNormal.x, worldNormal.y, worldNormal.z)
                    let len = length(n)
                    allNormals.append(len > 0 ? n / len : n)
                }
            }

            let faceIndices = geometry.faces.asUInt32Array()
            let indicesPerFace = geometry.faces.indexCountPerPrimitive

            for i in stride(from: 0, to: faceIndices.count, by: indicesPerFace) {
                for j in 0..<min(indicesPerFace, 3) {
                    if i + j < faceIndices.count {
                        allFaces.append(faceIndices[i + j] + vertexOffset)
                    }
                }
            }
        }

        return MergedMesh(vertices: allVertices, normals: allNormals, faces: allFaces)
    }
}
