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

    var fileSizeString: String {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: fileURL.path()),
              let size = attrs[.size] as? Int64 else { return "Unknown" }
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
}

enum ExportFormat: String, CaseIterable, Codable {
    case usdz = "USDZ"
    case obj = "OBJ"

    var fileExtension: String {
        switch self {
        case .usdz: return "usdz"
        case .obj: return "obj"
        }
    }

    var utType: UTType {
        switch self {
        case .usdz: return .usdz
        case .obj: return UTType(filenameExtension: "obj") ?? .data
        }
    }
}

enum ScanState {
    case ready
    case scanning
    case paused
    case completed
}
