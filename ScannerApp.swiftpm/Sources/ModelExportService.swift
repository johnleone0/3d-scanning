import Foundation
import ModelIO
import MetalKit

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

struct ModelExportService {

    static func export(mesh: MergedMesh, name: String, format: ExportFormat) throws -> URL {
        let fileName = "\(name).\(format.fileExtension)"
        let fileURL = URL.documentsDirectory.appending(path: fileName)

        // Always use manual OBJ writer for reliability in Playgrounds
        if format == .obj {
            try writeOBJ(mesh: mesh, to: fileURL)
            return fileURL
        }

        // For USDZ, try ModelIO first
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

    private static func writeOBJ(mesh: MergedMesh, to url: URL) throws {
        var obj = "# 3D Scanner Export\n"
        obj += "# Vertices: \(mesh.vertices.count), Faces: \(mesh.faceCount)\n\n"

        for v in mesh.vertices {
            obj += "v \(v.x) \(v.y) \(v.z)\n"
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
}
