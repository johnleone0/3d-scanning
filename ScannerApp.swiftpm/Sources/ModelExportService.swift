import Foundation
import ModelIO
import MetalKit

enum ExportError: LocalizedError {
    case noMetalDevice
    case unsupportedFormat
    case emptyMesh
    case writeFailed(String)

    var errorDescription: String? {
        switch self {
        case .noMetalDevice: return "Failed to initialize Metal device."
        case .unsupportedFormat: return "Export format is not supported."
        case .emptyMesh: return "No mesh data to export."
        case .writeFailed(let reason): return "Failed to write file: \(reason)"
        }
    }
}

struct ModelExportService {

    static func export(mesh: MergedMesh, name: String, format: ExportFormat) throws -> URL {
        let fileName = "\(name).\(format.fileExtension)"
        let fileURL = URL.documentsDirectory.appending(path: fileName)

        switch format {
        case .obj:
            try writeOBJ(mesh: mesh, to: fileURL)
            return fileURL

        case .stl:
            try writeSTL(mesh: mesh, to: fileURL)
            return fileURL

        case .ply:
            try writePLY(mesh: mesh, to: fileURL)
            return fileURL

        case .usdz:
            guard let device = MTLCreateSystemDefaultDevice() else {
                throw ExportError.noMetalDevice
            }

            let allocator = MTKMeshBufferAllocator(device: device)
            let mdlMesh = try buildMDLMesh(from: mesh, allocator: allocator)

            let asset = MDLAsset()
            asset.add(mdlMesh)

            if MDLAsset.canExportFileExtension(format.fileExtension) {
                try asset.export(to: fileURL)
                return fileURL
            }

            // Fallback: export as OBJ instead
            let fallbackURL = URL.documentsDirectory.appending(path: "\(name).obj")
            try writeOBJ(mesh: mesh, to: fallbackURL)
            return fallbackURL
        }
    }

    // MARK: - ModelIO Mesh Builder

    private static func buildMDLMesh(from mesh: MergedMesh, allocator: MTKMeshBufferAllocator) throws -> MDLMesh {
        let vertexCount = mesh.vertices.count
        guard vertexCount > 0 else { throw ExportError.emptyMesh }

        let vertexData = Data(bytes: mesh.vertices, count: vertexCount * MemoryLayout<SIMD3<Float>>.stride)
        let vertexBuffer = allocator.newBuffer(with: vertexData, type: .vertex)

        let posAttr = MDLVertexAttribute(
            name: MDLVertexAttributePosition,
            format: .float3,
            offset: 0,
            bufferIndex: 0
        )

        let descriptor = MDLVertexDescriptor()
        descriptor.attributes = NSMutableArray(array: [posAttr])
        descriptor.layouts = NSMutableArray(array: [
            MDLVertexBufferLayout(stride: MemoryLayout<SIMD3<Float>>.stride)
        ])

        let indexData = Data(bytes: mesh.faces, count: mesh.faces.count * MemoryLayout<UInt32>.stride)
        let indexBuffer = allocator.newBuffer(with: indexData, type: .index)

        let submesh = MDLSubmesh(
            indexBuffer: indexBuffer,
            indexCount: mesh.faces.count,
            indexType: .uInt32,
            geometryType: .triangles,
            material: nil
        )

        return MDLMesh(
            vertexBuffers: [vertexBuffer],
            vertexCount: vertexCount,
            descriptor: descriptor,
            submeshes: [submesh]
        )
    }

    // MARK: - OBJ Writer (with per-vertex color support)

    private static func writeOBJ(mesh: MergedMesh, to url: URL) throws {
        guard mesh.vertices.count > 0 else { throw ExportError.emptyMesh }

        var obj = "# 3D Scanner Export\n"
        obj += "# Vertices: \(mesh.vertices.count), Faces: \(mesh.faceCount)\n\n"

        let hasColors = mesh.hasColors

        // OBJ supports per-vertex color as an extension to the 'v' line: v x y z r g b
        for i in 0..<mesh.vertices.count {
            let v = mesh.vertices[i]
            if hasColors {
                let c = mesh.colors[i]
                obj += "v \(v.x) \(v.y) \(v.z) \(c.x) \(c.y) \(c.z)\n"
            } else {
                obj += "v \(v.x) \(v.y) \(v.z)\n"
            }
        }

        if !mesh.normals.isEmpty {
            obj += "\n"
            for n in mesh.normals {
                obj += "vn \(n.x) \(n.y) \(n.z)\n"
            }
        }

        obj += "\n"
        let hasNormals = mesh.normals.count == mesh.vertices.count
        for i in stride(from: 0, to: mesh.faces.count, by: 3) {
            let i0 = mesh.faces[i] + 1
            let i1 = mesh.faces[i + 1] + 1
            let i2 = mesh.faces[i + 2] + 1
            if hasNormals {
                obj += "f \(i0)//\(i0) \(i1)//\(i1) \(i2)//\(i2)\n"
            } else {
                obj += "f \(i0) \(i1) \(i2)\n"
            }
        }

        try obj.write(to: url, atomically: true, encoding: .utf8)
    }

    // MARK: - Binary STL Writer

    private static func writeSTL(mesh: MergedMesh, to url: URL) throws {
        guard mesh.vertices.count > 0 else { throw ExportError.emptyMesh }

        let triangleCount = mesh.faceCount
        // Binary STL: 80-byte header + 4-byte triangle count + 50 bytes per triangle
        let dataSize = 80 + 4 + triangleCount * 50
        var data = Data(count: dataSize)

        data.withUnsafeMutableBytes { rawBuffer in
            guard let basePtr = rawBuffer.baseAddress else { return }
            var offset = 0

            // 80-byte header
            let header = "3D Scanner Export - Binary STL"
            let headerData = header.data(using: .ascii)!
            headerData.withUnsafeBytes { headerBytes in
                basePtr.copyMemory(from: headerBytes.baseAddress!, byteCount: min(headerData.count, 80))
            }
            offset = 80

            // Triangle count (UInt32, little-endian)
            var count = UInt32(triangleCount)
            basePtr.advanced(by: offset).copyMemory(from: &count, byteCount: 4)
            offset += 4

            let hasNormals = mesh.normals.count == mesh.vertices.count

            // Each triangle: 12 bytes normal + 3×12 bytes vertices + 2 bytes attribute
            for f in 0..<triangleCount {
                let idx0 = Int(mesh.faces[f * 3])
                let idx1 = Int(mesh.faces[f * 3 + 1])
                let idx2 = Int(mesh.faces[f * 3 + 2])

                let v0 = mesh.vertices[idx0]
                let v1 = mesh.vertices[idx1]
                let v2 = mesh.vertices[idx2]

                // Face normal: average vertex normals or compute from cross product
                var normal: SIMD3<Float>
                if hasNormals {
                    let n = mesh.normals[idx0] + mesh.normals[idx1] + mesh.normals[idx2]
                    let len = simd_length(n)
                    normal = len > 0 ? n / len : SIMD3<Float>(0, 0, 1)
                } else {
                    let edge1 = v1 - v0
                    let edge2 = v2 - v0
                    let cross = simd_cross(edge1, edge2)
                    let len = simd_length(cross)
                    normal = len > 0 ? cross / len : SIMD3<Float>(0, 0, 1)
                }

                // Write normal
                var nx = normal.x, ny = normal.y, nz = normal.z
                basePtr.advanced(by: offset).copyMemory(from: &nx, byteCount: 4); offset += 4
                basePtr.advanced(by: offset).copyMemory(from: &ny, byteCount: 4); offset += 4
                basePtr.advanced(by: offset).copyMemory(from: &nz, byteCount: 4); offset += 4

                // Write vertices
                for v in [v0, v1, v2] {
                    var x = v.x, y = v.y, z = v.z
                    basePtr.advanced(by: offset).copyMemory(from: &x, byteCount: 4); offset += 4
                    basePtr.advanced(by: offset).copyMemory(from: &y, byteCount: 4); offset += 4
                    basePtr.advanced(by: offset).copyMemory(from: &z, byteCount: 4); offset += 4
                }

                // Attribute byte count (unused)
                var attrByteCount: UInt16 = 0
                basePtr.advanced(by: offset).copyMemory(from: &attrByteCount, byteCount: 2); offset += 2
            }
        }

        try data.write(to: url, options: .atomic)
    }

    // MARK: - PLY Writer (with per-vertex color support)

    private static func writePLY(mesh: MergedMesh, to url: URL) throws {
        guard mesh.vertices.count > 0 else { throw ExportError.emptyMesh }

        let hasColors = mesh.hasColors
        let hasNormals = mesh.normals.count == mesh.vertices.count
        let vertexCount = mesh.vertices.count
        let faceCount = mesh.faceCount

        // Build header
        var header = "ply\n"
        header += "format ascii 1.0\n"
        header += "comment Generated by 3D Scanner App\n"
        header += "element vertex \(vertexCount)\n"
        header += "property float x\n"
        header += "property float y\n"
        header += "property float z\n"
        if hasNormals {
            header += "property float nx\n"
            header += "property float ny\n"
            header += "property float nz\n"
        }
        if hasColors {
            header += "property uchar red\n"
            header += "property uchar green\n"
            header += "property uchar blue\n"
        }
        header += "element face \(faceCount)\n"
        header += "property list uchar int vertex_indices\n"
        header += "end_header\n"

        // Use a data buffer for efficient string building
        var output = header

        // Reserve approximate capacity to reduce reallocations
        let estimatedLineLength = hasColors ? 60 : 40
        output.reserveCapacity(header.count + vertexCount * estimatedLineLength + faceCount * 30)

        // Write vertices
        for i in 0..<vertexCount {
            let v = mesh.vertices[i]
            var line = "\(v.x) \(v.y) \(v.z)"
            if hasNormals {
                let n = mesh.normals[i]
                line += " \(n.x) \(n.y) \(n.z)"
            }
            if hasColors {
                let c = mesh.colors[i]
                let r = UInt8(clamping: Int((c.x * 255).rounded()))
                let g = UInt8(clamping: Int((c.y * 255).rounded()))
                let b = UInt8(clamping: Int((c.z * 255).rounded()))
                line += " \(r) \(g) \(b)"
            }
            output += line + "\n"
        }

        // Write faces
        for i in stride(from: 0, to: mesh.faces.count, by: 3) {
            let i0 = mesh.faces[i]
            let i1 = mesh.faces[i + 1]
            let i2 = mesh.faces[i + 2]
            output += "3 \(i0) \(i1) \(i2)\n"
        }

        try output.write(to: url, atomically: true, encoding: .utf8)
    }
}
