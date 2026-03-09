import ARKit
import simd

struct MergedMesh {
    var vertices: [SIMD3<Float>]
    var normals: [SIMD3<Float>]
    var faces: [UInt32]  // flat triangle indices
    var colors: [SIMD3<Float>]  // RGB 0-1, per vertex
    var faceCount: Int { faces.count / 3 }
    var hasColors: Bool { colors.count == vertices.count }
}

struct MeshProcessingService {

    // MARK: - Merge

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

        return MergedMesh(vertices: allVertices, normals: allNormals, faces: allFaces, colors: [])
    }

    // MARK: - Bounding Box

    static func boundingBox(of mesh: MergedMesh) -> (min: SIMD3<Float>, max: SIMD3<Float>) {
        guard let first = mesh.vertices.first else {
            return (min: .zero, max: .zero)
        }
        var bbMin = first
        var bbMax = first
        for v in mesh.vertices {
            bbMin = pointwiseMin(bbMin, v)
            bbMax = pointwiseMax(bbMax, v)
        }
        return (min: bbMin, max: bbMax)
    }

    // MARK: - Simplification (Vertex Clustering)

    /// Simplifies a mesh using vertex clustering on a uniform grid.
    /// `targetReduction` is a value in 0..<1 representing the fraction of
    /// detail to remove (e.g. 0.5 removes roughly half the vertices).
    /// Vertices falling into the same grid cell are merged; their positions,
    /// normals, and colors are averaged. Degenerate triangles (where two or
    /// more vertices collapse to the same cell) are discarded.
    static func simplifyMesh(_ mesh: MergedMesh, targetReduction: Float) -> MergedMesh {
        let reduction = Swift.max(0.0, Swift.min(targetReduction, 0.99))
        guard reduction > 0, !mesh.vertices.isEmpty else { return mesh }

        let (bbMin, bbMax) = boundingBox(of: mesh)
        let extent = bbMax - bbMin
        let maxExtent = Swift.max(extent.x, Swift.max(extent.y, extent.z))
        guard maxExtent > 0 else { return mesh }

        // Derive grid resolution from desired vertex count.
        let desiredCount = Swift.max(Float(mesh.vertices.count) * (1.0 - reduction), 8)
        let cellsPerAxis = Swift.max(Int(cbrtf(desiredCount)), 2)
        let cellSize = extent / Float(cellsPerAxis)

        // Avoid division by zero on flat axes.
        let safeCellSize = SIMD3<Float>(
            cellSize.x > 0 ? cellSize.x : maxExtent,
            cellSize.y > 0 ? cellSize.y : maxExtent,
            cellSize.z > 0 ? cellSize.z : maxExtent
        )

        // Spatial hash key for a grid cell.
        struct CellKey: Hashable {
            let x: Int, y: Int, z: Int
        }

        struct CellAccum {
            var positionSum: SIMD3<Float> = .zero
            var normalSum: SIMD3<Float> = .zero
            var colorSum: SIMD3<Float> = .zero
            var count: Int = 0
            var newIndex: UInt32 = 0
        }

        let hasColors = mesh.hasColors
        var cellMap: [CellKey: CellAccum] = [:]
        var vertexKeys = [CellKey]()
        vertexKeys.reserveCapacity(mesh.vertices.count)

        // Accumulate per-cell data.
        for i in 0..<mesh.vertices.count {
            let v = mesh.vertices[i]
            let rel = v - bbMin
            let cx = Swift.min(Int(rel.x / safeCellSize.x), cellsPerAxis - 1)
            let cy = Swift.min(Int(rel.y / safeCellSize.y), cellsPerAxis - 1)
            let cz = Swift.min(Int(rel.z / safeCellSize.z), cellsPerAxis - 1)
            let key = CellKey(x: cx, y: cy, z: cz)
            vertexKeys.append(key)

            var accum = cellMap[key] ?? CellAccum()
            accum.positionSum += v
            if i < mesh.normals.count {
                accum.normalSum += mesh.normals[i]
            }
            if hasColors {
                accum.colorSum += mesh.colors[i]
            }
            accum.count += 1
            cellMap[key] = accum
        }

        // Assign new indices and compute averaged attributes.
        var newVertices: [SIMD3<Float>] = []
        var newNormals: [SIMD3<Float>] = []
        var newColors: [SIMD3<Float>] = []

        newVertices.reserveCapacity(cellMap.count)
        newNormals.reserveCapacity(cellMap.count)
        if hasColors { newColors.reserveCapacity(cellMap.count) }

        var idx: UInt32 = 0
        for key in cellMap.keys {
            var accum = cellMap[key]!
            accum.newIndex = idx
            cellMap[key] = accum

            let c = Float(accum.count)
            newVertices.append(accum.positionSum / c)

            let avgNormal = accum.normalSum / c
            let nLen = length(avgNormal)
            newNormals.append(nLen > 0 ? avgNormal / nLen : avgNormal)

            if hasColors {
                newColors.append(accum.colorSum / c)
            }

            idx += 1
        }

        // Build old-to-new vertex index mapping.
        var oldToNew = [UInt32](repeating: 0, count: mesh.vertices.count)
        for i in 0..<mesh.vertices.count {
            oldToNew[i] = cellMap[vertexKeys[i]]!.newIndex
        }

        // Rebuild faces, dropping degenerate triangles.
        var newFaces: [UInt32] = []
        newFaces.reserveCapacity(mesh.faces.count)

        for t in 0..<mesh.faceCount {
            let base = t * 3
            let a = oldToNew[Int(mesh.faces[base])]
            let b = oldToNew[Int(mesh.faces[base + 1])]
            let c = oldToNew[Int(mesh.faces[base + 2])]
            if a != b && b != c && a != c {
                newFaces.append(a)
                newFaces.append(b)
                newFaces.append(c)
            }
        }

        return MergedMesh(
            vertices: newVertices,
            normals: newNormals,
            faces: newFaces,
            colors: newColors
        )
    }

    // MARK: - Crop

    /// Removes all vertices outside the axis-aligned bounding box defined by
    /// `cropMin` and `cropMax`. Faces referencing any removed vertex are dropped.
    /// Surviving vertices are compacted and face indices rewritten.
    static func cropMesh(_ mesh: MergedMesh, min cropMin: SIMD3<Float>, max cropMax: SIMD3<Float>) -> MergedMesh {
        var indexMap = [Int: UInt32]()
        var newVertices: [SIMD3<Float>] = []
        var newNormals: [SIMD3<Float>] = []
        var newColors: [SIMD3<Float>] = []

        for (i, v) in mesh.vertices.enumerated() {
            let inside = v.x >= cropMin.x && v.x <= cropMax.x
                      && v.y >= cropMin.y && v.y <= cropMax.y
                      && v.z >= cropMin.z && v.z <= cropMax.z
            if inside {
                indexMap[i] = UInt32(newVertices.count)
                newVertices.append(v)
                if i < mesh.normals.count { newNormals.append(mesh.normals[i]) }
                if i < mesh.colors.count { newColors.append(mesh.colors[i]) }
            }
        }

        var newFaces: [UInt32] = []
        newFaces.reserveCapacity(mesh.faces.count)

        for t in 0..<mesh.faceCount {
            let base = t * 3
            guard base + 2 < mesh.faces.count else { break }
            let a = Int(mesh.faces[base])
            let b = Int(mesh.faces[base + 1])
            let c = Int(mesh.faces[base + 2])
            if let na = indexMap[a], let nb = indexMap[b], let nc = indexMap[c] {
                newFaces.append(na)
                newFaces.append(nb)
                newFaces.append(nc)
            }
        }

        return MergedMesh(vertices: newVertices, normals: newNormals, faces: newFaces, colors: newColors)
    }
}
