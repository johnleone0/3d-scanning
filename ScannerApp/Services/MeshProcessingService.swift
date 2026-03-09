import ARKit
import simd

struct MergedMesh {
    var vertices: [SIMD3<Float>]
    var normals: [SIMD3<Float>]
    var faces: [UInt32] // Flat array of triangle indices (3 per face)
    var faceCount: Int { faces.count / 3 }
}

struct MeshProcessingService {

    /// Merges all ARMeshAnchors into a single unified mesh in world space.
    static func mergeMeshAnchors(_ anchors: [ARMeshAnchor]) -> MergedMesh {
        var allVertices: [SIMD3<Float>] = []
        var allNormals: [SIMD3<Float>] = []
        var allFaces: [UInt32] = []

        for anchor in anchors {
            let geometry = anchor.geometry
            let vertexOffset = UInt32(allVertices.count)

            // Extract and transform vertices to world space
            let vertices = geometry.vertices.asFloat3Array()
            let normals = geometry.normals.asFloat3Array()
            let transform = anchor.transform

            for i in 0..<vertices.count {
                let localPos = vertices[i]
                let worldPos = transform * SIMD4<Float>(localPos.x, localPos.y, localPos.z, 1.0)
                allVertices.append(SIMD3<Float>(worldPos.x, worldPos.y, worldPos.z))

                if i < normals.count {
                    let localNormal = normals[i]
                    // Transform normal (rotation only, no translation)
                    let worldNormal = simd_make_float3(
                        transform * SIMD4<Float>(localNormal.x, localNormal.y, localNormal.z, 0.0)
                    )
                    allNormals.append(normalize(worldNormal))
                }
            }

            // Extract face indices and offset them
            let faceIndices = geometry.faces.asUInt32Array()
            let indicesPerFace = geometry.faces.indexCountPerPrimitive // Should be 3 for triangles

            for i in stride(from: 0, to: faceIndices.count, by: indicesPerFace) {
                for j in 0..<min(indicesPerFace, 3) {
                    if i + j < faceIndices.count {
                        allFaces.append(faceIndices[i + j] + vertexOffset)
                    }
                }
            }
        }

        return MergedMesh(
            vertices: allVertices,
            normals: allNormals,
            faces: allFaces
        )
    }

    /// Computes axis-aligned bounding box of the merged mesh.
    static func boundingBox(of mesh: MergedMesh) -> (min: SIMD3<Float>, max: SIMD3<Float>) {
        guard let first = mesh.vertices.first else {
            return (.zero, .zero)
        }
        var minV = first
        var maxV = first
        for v in mesh.vertices {
            minV = min(minV, v)
            maxV = max(maxV, v)
        }
        return (minV, maxV)
    }
}
