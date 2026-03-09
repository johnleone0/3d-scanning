import SwiftUI

struct HomeView: View {
    @Environment(AppState.self) private var appState
    @State private var showScanner = false

    var body: some View {
        NavigationStack {
            Group {
                if appState.scannedModels.isEmpty {
                    emptyState
                } else {
                    modelsList
                }
            }
            .navigationTitle("3D Scanner")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    cloudSyncButton
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showScanner = true
                    } label: {
                        Image(systemName: "plus.viewfinder")
                            .font(.title2)
                    }
                    .disabled(!appState.isLiDARAvailable)
                }
            }
            .fullScreenCover(isPresented: $showScanner) {
                ScanningView()
                    .environment(appState)
            }
            .overlay {
                if !appState.isLiDARAvailable {
                    noLiDAROverlay
                }
            }
            .refreshable {
                await appState.syncWithCloud()
            }
        }
    }

    // MARK: - Cloud Sync Button

    private var cloudSyncButton: some View {
        Button {
            Task {
                await appState.syncWithCloud()
            }
        } label: {
            if appState.cloudSync.isSyncing {
                ProgressView()
            } else {
                Image(systemName: appState.cloudSync.isAvailable ? "icloud.and.arrow.up.fill" : "icloud.slash")
                    .symbolRenderingMode(.hierarchical)
            }
        }
        .disabled(appState.cloudSync.isSyncing || !appState.cloudSync.isAvailable)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Scans Yet", systemImage: "cube.transparent")
        } description: {
            Text("Tap the scan button to capture your first 3D object.")
        } actions: {
            Button("Start Scanning") {
                showScanner = true
            }
            .buttonStyle(.borderedProminent)
            .disabled(!appState.isLiDARAvailable)
        }
    }

    // MARK: - Models List

    private var modelsList: some View {
        List {
            if let lastSync = appState.cloudSync.lastSyncDate {
                Section {
                    HStack {
                        Image(systemName: "icloud.fill")
                            .foregroundStyle(.secondary)
                        Text("Last synced: \(lastSync, style: .relative) ago")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            ForEach(appState.scannedModels) { model in
                NavigationLink(destination: ModelDetailView(model: model).environment(appState)) {
                    modelRow(model)
                }
            }
            .onDelete { indexSet in
                for index in indexSet {
                    appState.deleteModel(appState.scannedModels[index])
                }
            }
        }
    }

    private func modelRow(_ model: ScannedModel) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(model.name)
                    .font(.headline)
                if model.isCloudSynced {
                    Image(systemName: "icloud.fill")
                        .font(.caption)
                        .foregroundStyle(.blue)
                }
            }
            HStack(spacing: 12) {
                Label("\(model.vertexCount.formatted()) verts", systemImage: "circle.grid.3x3")
                Label(model.format.rawValue, systemImage: "doc")
                Label(model.fileSizeString, systemImage: "internaldrive")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            Text(model.dateCreated, style: .date)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }

    // MARK: - No LiDAR Overlay

    private var noLiDAROverlay: some View {
        VStack(spacing: 16) {
            Image(systemName: "sensor.tag.radiowaves.forward.fill")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            Text("LiDAR Not Available")
                .font(.title2.bold())
            Text("This app requires an iPhone or iPad with a LiDAR sensor.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }
}
