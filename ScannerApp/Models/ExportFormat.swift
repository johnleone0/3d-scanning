import Foundation
import UniformTypeIdentifiers

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
