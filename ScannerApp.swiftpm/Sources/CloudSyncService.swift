import Foundation
import Observation

/// Handles iCloud document-based sync for scan files.
/// Uses NSUbiquitousKeyValueStore for model metadata and
/// the iCloud ubiquity container for actual scan file storage.
@Observable
final class CloudSyncService {

    // MARK: - Sync State

    enum SyncState: Equatable {
        case idle
        case syncing
        case succeeded
        case failed(String)

        var isSyncing: Bool { self == .syncing }
    }

    private(set) var syncState: SyncState = .idle
    private(set) var iCloudAvailable: Bool = false
    private(set) var lastSyncDate: Date?
    private(set) var cloudModels: [ScannedModel] = []

    // MARK: - Constants

    private static let metadataKey = "syncedScanModels"
    private static let containerIdentifier: String? = nil // uses default container

    // MARK: - Dependencies

    private let fileManager = FileManager.default
    private let kvStore = NSUbiquitousKeyValueStore.default

    // MARK: - Init

    init() {
        checkiCloudAvailability()
        observeKVStoreChanges()
        if iCloudAvailable {
            loadCloudMetadata()
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Public API

    /// Uploads a scanned model's file and metadata to iCloud.
    func uploadScan(_ model: ScannedModel) async throws {
        guard iCloudAvailable else {
            syncState = .failed("iCloud is not available. Please sign in to iCloud in Settings.")
            return
        }

        guard model.fileExists else {
            syncState = .failed("Local scan file not found.")
            return
        }

        syncState = .syncing

        do {
            let cloudURL = try cloudFileURL(for: model)

            // Create directory structure if needed
            let directory = cloudURL.deletingLastPathComponent()
            if !fileManager.fileExists(atPath: directory.path()) {
                try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            }

            // Copy or replace file in iCloud container
            if fileManager.fileExists(atPath: cloudURL.path()) {
                try fileManager.removeItem(at: cloudURL)
            }
            try fileManager.copyItem(at: model.fileURL, to: cloudURL)

            // Update metadata in KV store
            var updatedModel = model
            updatedModel.isCloudSynced = true
            addOrUpdateModelMetadata(updatedModel)

            syncState = .succeeded
            lastSyncDate = Date()
        } catch {
            syncState = .failed("Upload failed: \(error.localizedDescription)")
            throw error
        }
    }

    /// Downloads all scan files from iCloud that aren't present locally.
    func downloadScans() async throws -> [ScannedModel] {
        guard iCloudAvailable else {
            syncState = .failed("iCloud is not available. Please sign in to iCloud in Settings.")
            return []
        }

        syncState = .syncing

        do {
            loadCloudMetadata()

            var downloadedModels: [ScannedModel] = []

            for model in cloudModels {
                let cloudURL = try cloudFileURL(for: model)

                // Skip if cloud file doesn't exist
                guard fileManager.fileExists(atPath: cloudURL.path()) else {
                    continue
                }

                // Skip if already present locally
                if fileManager.fileExists(atPath: model.fileURL.path()) {
                    continue
                }

                // Start downloading if file is not yet available (evicted)
                try startDownloadingIfNeeded(at: cloudURL)

                // Copy from cloud to local documents
                let localURL = URL.documentsDirectory.appending(
                    path: cloudURL.lastPathComponent
                )
                if fileManager.fileExists(atPath: localURL.path()) {
                    try fileManager.removeItem(at: localURL)
                }
                try fileManager.copyItem(at: cloudURL, to: localURL)

                let localModel = ScannedModel(
                    id: model.id,
                    name: model.name,
                    dateCreated: model.dateCreated,
                    fileURL: localURL,
                    vertexCount: model.vertexCount,
                    faceCount: model.faceCount,
                    format: model.format,
                    hasColors: model.hasColors,
                    isCloudSynced: true
                )
                downloadedModels.append(localModel)
            }

            syncState = .succeeded
            lastSyncDate = Date()
            return downloadedModels
        } catch {
            syncState = .failed("Download failed: \(error.localizedDescription)")
            throw error
        }
    }

    /// Performs a full bidirectional sync: uploads local-only scans and downloads cloud-only scans.
    func syncAll(localModels: [ScannedModel]) async throws -> [ScannedModel] {
        guard iCloudAvailable else {
            syncState = .failed("iCloud is not available. Please sign in to iCloud in Settings.")
            return localModels
        }

        syncState = .syncing

        do {
            // Upload any local models that aren't yet synced
            for model in localModels where !model.isCloudSynced {
                try await uploadScan(model)
            }

            // Download any cloud-only models
            let downloaded = try await downloadScans()

            // Merge: start with local models, add any cloud-only ones
            let localIDs = Set(localModels.map(\.id))
            let newFromCloud = downloaded.filter { !localIDs.contains($0.id) }

            syncState = .succeeded
            lastSyncDate = Date()

            return localModels + newFromCloud
        } catch {
            syncState = .failed("Sync failed: \(error.localizedDescription)")
            throw error
        }
    }

    /// Refreshes the iCloud availability status.
    func refreshAvailability() {
        checkiCloudAvailability()
    }

    // MARK: - iCloud Availability

    private func checkiCloudAvailability() {
        iCloudAvailable = fileManager.ubiquityIdentityToken != nil
    }

    // MARK: - Cloud File Paths

    private func ubiquityContainerURL() throws -> URL {
        guard let containerURL = fileManager.url(
            forUbiquityContainerIdentifier: Self.containerIdentifier
        ) else {
            throw CloudSyncError.containerUnavailable
        }
        return containerURL
    }

    private func cloudFileURL(for model: ScannedModel) throws -> URL {
        let container = try ubiquityContainerURL()
        let scansDir = container.appending(path: "Documents/Scans")
        let fileName = "\(model.id.uuidString).\(model.format.fileExtension)"
        return scansDir.appending(path: fileName)
    }

    private func startDownloadingIfNeeded(at url: URL) throws {
        var isDownloaded: AnyObject?
        try (url as NSURL).getResourceValue(
            &isDownloaded,
            forKey: .ubiquitousItemDownloadingStatusKey
        )

        if let status = isDownloaded as? String,
           status != URLUbiquitousItemDownloadingStatus.current.rawValue {
            try fileManager.startDownloadingUbiquitousItem(at: url)
        }
    }

    // MARK: - Metadata (NSUbiquitousKeyValueStore)

    private func loadCloudMetadata() {
        kvStore.synchronize()

        guard let data = kvStore.data(forKey: Self.metadataKey),
              let models = try? JSONDecoder().decode([ScannedModel].self, from: data) else {
            cloudModels = []
            return
        }

        cloudModels = models
    }

    private func addOrUpdateModelMetadata(_ model: ScannedModel) {
        loadCloudMetadata()

        if let idx = cloudModels.firstIndex(where: { $0.id == model.id }) {
            cloudModels[idx] = model
        } else {
            cloudModels.append(model)
        }

        saveCloudMetadata()
    }

    private func saveCloudMetadata() {
        guard let data = try? JSONEncoder().encode(cloudModels) else { return }
        kvStore.set(data, forKey: Self.metadataKey)
        kvStore.synchronize()
    }

    // MARK: - KV Store Change Observation

    private func observeKVStoreChanges() {
        NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: kvStore,
            queue: .main
        ) { [weak self] notification in
            guard let self else { return }
            self.handleKVStoreChange(notification)
        }
    }

    private func handleKVStoreChange(_ notification: Notification) {
        guard let reason = notification.userInfo?[NSUbiquitousKeyValueStoreChangeReasonKey] as? Int else {
            return
        }

        switch reason {
        case NSUbiquitousKeyValueStoreServerChange,
             NSUbiquitousKeyValueStoreInitialSyncChange:
            loadCloudMetadata()
        case NSUbiquitousKeyValueStoreAccountChange:
            checkiCloudAvailability()
            if iCloudAvailable {
                loadCloudMetadata()
            } else {
                cloudModels = []
            }
        default:
            break
        }
    }
}

// MARK: - Errors

enum CloudSyncError: LocalizedError {
    case containerUnavailable
    case fileNotFound
    case iCloudNotAvailable

    var errorDescription: String? {
        switch self {
        case .containerUnavailable:
            return "iCloud container is not available. Please ensure iCloud is enabled."
        case .fileNotFound:
            return "The scan file could not be found."
        case .iCloudNotAvailable:
            return "iCloud is not available. Please sign in to iCloud in Settings."
        }
    }
}
