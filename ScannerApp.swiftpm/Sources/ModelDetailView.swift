import SwiftUI
import QuickLook

struct ModelDetailView: View {
    let model: ScannedModel
    /// Optional mesh data passed directly from a scan session for editing/simplification.
    var mesh: MergedMesh?

    @Environment(AppState.self) private var appState
    @State private var showQuickLook = false
    @State private var showPointCloud = false
    @State private var showMeshEdit = false
    @State private var showSimplify = false
    @State private var reExportFormat: ExportFormat = .obj
    @State private var isReExporting = false
    @State private var reExportMessage: String?
    @State private var isSyncingToCloud = false
    @State private var currentMesh: MergedMesh?

    var body: some View {
        List {
            Section("Model Info") {
                LabeledContent("Name", value: model.name)
                LabeledContent("Vertices", value: model.vertexCount.formatted())
                LabeledContent("Faces", value: model.faceCount.formatted())
                LabeledContent("Format", value: model.format.rawValue)
                LabeledContent("Size", value: model.fileSizeString)
                LabeledContent("Date") {
                    Text(model.dateCreated, style: .date)
                }
                if model.hasColors {
                    LabeledContent("Colors", value: "Yes")
                }
                if model.isCloudSynced {
                    Label("Synced to iCloud", systemImage: "checkmark.icloud.fill")
                        .foregroundStyle(.green)
                }
            }

            if model.format == .usdz {
                Section {
                    Button {
                        showQuickLook = true
                    } label: {
                        Label("Preview in AR", systemImage: "arkit")
                    }
                }
            }

            // Mesh tools -- available when mesh data was passed from a scan
            if currentMesh != nil {
                Section("Mesh Tools") {
                    Button {
                        showPointCloud = true
                    } label: {
                        Label("View Point Cloud", systemImage: "aqi.medium")
                    }

                    Button {
                        showMeshEdit = true
                    } label: {
                        Label("Edit / Crop Mesh", systemImage: "crop")
                    }

                    Button {
                        showSimplify = true
                    } label: {
                        Label("Simplify Mesh", systemImage: "wand.and.rays")
                    }
                }
            } else {
                Section {
                    Text("Mesh editing tools are available immediately after scanning. Re-scan to access crop and simplify features.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Re-export in a different format
            Section("Re-export") {
                Picker("Format", selection: $reExportFormat) {
                    ForEach(ExportFormat.allCases, id: \.self) { format in
                        Text(format.rawValue).tag(format)
                    }
                }

                Button {
                    reExport()
                } label: {
                    if isReExporting {
                        HStack(spacing: 8) {
                            ProgressView()
                            Text("Exporting...")
                        }
                    } else {
                        Label("Export as \(reExportFormat.rawValue)", systemImage: "square.and.arrow.down")
                    }
                }
                .disabled(isReExporting || currentMesh == nil)

                if let message = reExportMessage {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if currentMesh == nil {
                    Text("Re-export requires mesh data from a recent scan.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Cloud sync
            Section {
                Button {
                    syncToCloud()
                } label: {
                    if isSyncingToCloud {
                        HStack(spacing: 8) {
                            ProgressView()
                            Text("Syncing...")
                        }
                    } else {
                        Label(
                            model.isCloudSynced ? "Re-sync to iCloud" : "Upload to iCloud",
                            systemImage: "icloud.and.arrow.up"
                        )
                    }
                }
                .disabled(isSyncingToCloud || !appState.cloudSync.isAvailable)

                if !appState.cloudSync.isAvailable {
                    Text("iCloud is not available. Sign in to iCloud in Settings.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                ShareLink(item: model.fileURL) {
                    Label("Share \(model.format.rawValue) File", systemImage: "square.and.arrow.up")
                }
            }
        }
        .navigationTitle(model.name)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            currentMesh = mesh
            reExportFormat = model.format
        }
        .quickLookPreview(Binding(
            get: { showQuickLook ? model.fileURL : nil },
            set: { if $0 == nil { showQuickLook = false } }
        ))
        .sheet(isPresented: $showPointCloud) {
            if let currentMesh {
                NavigationStack {
                    PointCloudView(mesh: currentMesh)
                        .navigationTitle("Point Cloud")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Done") { showPointCloud = false }
                            }
                        }
                }
            }
        }
        .sheet(isPresented: $showMeshEdit) {
            if let currentMesh {
                NavigationStack {
                    MeshEditView(mesh: currentMesh) { croppedMesh in
                        self.currentMesh = croppedMesh
                        showMeshEdit = false
                    }
                    .navigationTitle("Edit Mesh")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") { showMeshEdit = false }
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showSimplify) {
            if let currentMesh {
                NavigationStack {
                    MeshSimplifyView(mesh: currentMesh) { simplifiedMesh in
                        self.currentMesh = simplifiedMesh
                        showSimplify = false
                    }
                    .navigationTitle("Simplify Mesh")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") { showSimplify = false }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Actions

    private func reExport() {
        guard let currentMesh else { return }
        isReExporting = true
        reExportMessage = nil

        Task {
            do {
                let url = try ModelExportService.export(
                    mesh: currentMesh,
                    name: model.name,
                    format: reExportFormat
                )
                let newModel = ScannedModel(
                    id: UUID(),
                    name: "\(model.name)_\(reExportFormat.rawValue)",
                    dateCreated: Date(),
                    fileURL: url,
                    vertexCount: currentMesh.vertices.count,
                    faceCount: currentMesh.faceCount,
                    format: reExportFormat,
                    hasColors: currentMesh.hasColors
                )
                appState.addModel(newModel)
                reExportMessage = "Exported as \(reExportFormat.rawValue) successfully."
            } catch {
                reExportMessage = "Export failed: \(error.localizedDescription)"
            }
            isReExporting = false
        }
    }

    private func syncToCloud() {
        isSyncingToCloud = true
        Task {
            await appState.cloudSync.uploadScan(model)
            isSyncingToCloud = false
        }
    }
}
