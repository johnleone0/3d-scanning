import Foundation
import UniformTypeIdentifiers

struct ScannedModel: Identifiable, Codable {
    let id: UUID
    let name: String
    let dateCreated: Date
    let fileURL: URL
    let vertexCount: Int
    let faceCount: Int
    let format: ExportFormat
    var hasColors: Bool = false
    var isCloudSynced: Bool = false

    var fileSizeString: String {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: fileURL.path()),
              let size = attrs[.size] as? Int64 else { return "Unknown" }
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }

    var fileExists: Bool {
        FileManager.default.fileExists(atPath: fileURL.path())
    }
}

enum ExportFormat: String, CaseIterable, Codable {
    case obj = "OBJ"
    case usdz = "USDZ"
    case stl = "STL"
    case ply = "PLY"

    var fileExtension: String {
        switch self {
        case .obj: return "obj"
        case .usdz: return "usdz"
        case .stl: return "stl"
        case .ply: return "ply"
        }
    }

    var utType: UTType {
        switch self {
        case .usdz: return .usdz
        case .obj: return UTType(filenameExtension: "obj") ?? .data
        case .stl: return UTType(filenameExtension: "stl") ?? .data
        case .ply: return UTType(filenameExtension: "ply") ?? .data
        }
    }

    var supportsColor: Bool {
        switch self {
        case .ply, .obj: return true
        case .stl, .usdz: return false
        }
    }
}

enum ScanState {
    case ready
    case scanning
    case paused
    case completed
}

enum VisualizationMode: String, CaseIterable {
    case mesh = "Mesh"
    case pointCloud = "Points"
    case solid = "Solid"
}
