import Foundation
import UniformTypeIdentifiers

struct ScannedModel: Identifiable, Codable {
    let id: UUID
    let name: String
    let dateCreated: Date
    let fileURL: URL
    let thumbnailURL: URL?
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
