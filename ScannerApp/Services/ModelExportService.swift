import Foundation
import ModelIO
import MetalKit
import simd

struct ModelExportService {

    /// Exports a merged mesh to the specified format and returns the file URL.
    static func export(
        mesh: MergedMesh,
        name: String,
        format: ExportFormat
    ) throws -> URL {
        let fileName = "\(name).\(format.fileExtension)"
        let fileURL = URL.documentsDirectory.appending(path: fileName)

        guard let device = MTLCreateSystemDefaultDevice() else {
            throw ExportError.noMetalDevice
        }

        let allocator = MTKMeshBufferAllocator(device: device)
        let mdlMesh = try createMDLMesh(from: mesh, allocator: allocator)

        let asset = MDLAsset()
        asset.add(mdlMesh)

        // Export using ModelIO
        guard MDLAsset.canExportFileExtension(format.fileExtension) else {
            // Fall back to manual OBJ writing if ModelIO can't handle it
            if format == .obj {
                try writeOBJManually(mesh: mesh, to: fileURL)
                return fileURL
            }
            throw ExportError.unsupportedFormat
        }

        try asset.export(to: fileURL)
        return fileURL
    }

    // MARK: - MDLMesh Construction

    private static func createMDLMesh(
        from mesh: MergedMesh,
        allocator: MTKMeshBufferAllocator
    ) throws -> MDLMesh {
        let vertexCount = mesh.vertices.count
        guard vertexCount > 0 else { throw ExportError.emptyMesh }

        // Create vertex buffer with positions
        let vertexData = Data(bytes: mesh.vertices, count: vertexCount * MemoryLayout<SIMD3<Float>>.stride)
        let vertexBuffer = allocator.newBuffer(with: vertexData, type: .vertex)

        let positionDescriptor = MDLVertexAttribute(
            name: MDLVertexAttributePosition,
            format: .float3,
            offset: 0,
            bufferIndex: 0
        )

        let vertexDescriptor = MDLVertexDescriptor()
        vertexDescriptor.attributes = NSMutableArray(array: [positionDescriptor])
        vertexDescriptor.layouts = NSMutableArray(array: [
            MDLVertexBufferLayout(stride: MemoryLayout<SIMD3<Float>>.stride)
        ])

        // Add normals if available
        if mesh.normals.count == vertexCount {
            let normalData = Data(bytes: mesh.normals, count: vertexCount * MemoryLayout<SIMD3<Float>>.stride)
            let normalBuffer = allocator.newBuffer(with: normalData, type: .vertex)

            let normalDescriptor = MDLVertexAttribute(
                name: MDLVertexAttributeNormal,
                format: .float3,
                offset: 0,
                bufferIndex: 1
            )

            vertexDescriptor.attributes = NSMutableArray(array: [positionDescriptor, normalDescriptor])
            vertexDescriptor.layouts = NSMutableArray(array: [
                MDLVertexBufferLayout(stride: MemoryLayout<SIMD3<Float>>.stride),
                MDLVertexBufferLayout(stride: MemoryLayout<SIMD3<Float>>.stride)
            ])

            // Create index buffer
            let indexData = Data(bytes: mesh.faces, count: mesh.faces.count * MemoryLayout<UInt32>.stride)
            let indexBuffer = allocator.newBuffer(with: indexData, type: .index)

            let submesh = MDLSubmesh(
                indexBuffer: indexBuffer,
                indexCount: mesh.faces.count,
                indexType: .uInt32,
                geometryType: .triangles,
                material: nil
            )

            let mdlMesh = MDLMesh(
                vertexBuffers: [vertexBuffer, normalBuffer],
                vertexCount: vertexCount,
                descriptor: vertexDescriptor,
                submeshes: [submesh]
            )

            return mdlMesh
        }

        // Without normals
        let indexData = Data(bytes: mesh.faces, count: mesh.faces.count * MemoryLayout<UInt32>.stride)
        let indexBuffer = allocator.newBuffer(with: indexData, type: .index)

        let submesh = MDLSubmesh(
            indexBuffer: indexBuffer,
            indexCount: mesh.faces.count,
            indexType: .uInt32,
            geometryType: .triangles,
            material: nil
        )

        let mdlMesh = MDLMesh(
            vertexBuffers: [vertexBuffer],
            vertexCount: vertexCount,
            descriptor: vertexDescriptor,
            submeshes: [submesh]
        )

        return mdlMesh
    }

    // MARK: - Manual OBJ Export (fallback)

    private static func writeOBJManually(mesh: MergedMesh, to url: URL) throws {
        var objString = "# 3D Scanner Export\n"
        objString += "# Vertices: \(mesh.vertices.count)\n"
        objString += "# Faces: \(mesh.faceCount)\n\n"

        // Write vertices
        for v in mesh.vertices {
            objString += "v \(v.x) \(v.y) \(v.z)\n"
        }

        // Write normals
        if !mesh.normals.isEmpty {
            objString += "\n"
            for n in mesh.normals {
                objString += "vn \(n.x) \(n.y) \(n.z)\n"
            }
        }

        // Write faces (OBJ indices are 1-based)
        objString += "\n"
        let hasNormals = mesh.normals.count == mesh.vertices.count
        for i in stride(from: 0, to: mesh.faces.count, by: 3) {
            let i0 = mesh.faces[i] + 1
            let i1 = mesh.faces[i + 1] + 1
            let i2 = mesh.faces[i + 2] + 1
            if hasNormals {
                objString += "f \(i0)//\(i0) \(i1)//\(i1) \(i2)//\(i2)\n"
            } else {
                objString += "f \(i0) \(i1) \(i2)\n"
            }
        }

        try objString.write(to: url, atomically: true, encoding: .utf8)
    }
}

enum ExportError: LocalizedError {
    case noMetalDevice
    case unsupportedFormat
    case emptyMesh

    var errorDescription: String? {
        switch self {
        case .noMetalDevice: return "Failed to initialize Metal device."
        case .unsupportedFormat: return "Export format is not supported."
        case .emptyMesh: return "No mesh data to export."
        }
    }
}
