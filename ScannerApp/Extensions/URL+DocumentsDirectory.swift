import Foundation

extension URL {
    /// Returns the app's Documents directory URL.
    static var scansDirectory: URL {
        let url = documentsDirectory.appending(path: "Scans")
        if !FileManager.default.fileExists(atPath: url.path()) {
            try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        }
        return url
    }
}
