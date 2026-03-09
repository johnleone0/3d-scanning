import SwiftUI

struct ScanningView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = ScanningViewModel()
    @State private var exportFormat: ExportFormat = .obj
    @State private var showCompletionAlert = false
    @State private var completedModel: ScannedModel?

    var body: some View {
        ZStack {
            // AR Camera Feed with mesh overlay
            ARScanningViewRepresentable(scanningService: viewModel.scanningService)
                .ignoresSafeArea()

            // UI Overlay
            VStack {
                // Top bar
                topBar

                Spacer()

                // Stats overlay
                if viewModel.scanState == .scanning || viewModel.scanState == .paused {
                    scanStatsOverlay
                }

                // Control bar
                ScanControlBar(
                    scanState: viewModel.scanState,
                    isProcessing: viewModel.isProcessing,
                    onStart: { viewModel.startScan() },
                    onPause: { viewModel.pauseScan() },
                    onResume: { viewModel.resumeScan() },
                    onFinish: { finishScan() }
                )
                .padding(.bottom, 30)
            }
        }
        .alert("Scan Complete", isPresented: $showCompletionAlert) {
            Button("View Model") {
                dismiss()
            }
            Button("New Scan") {
                viewModel = ScanningViewModel()
            }
        } message: {
            if let model = completedModel {
                Text("Saved \"\(model.name)\" with \(model.vertexCount.formatted()) vertices.")
            }
        }
        .alert("Error", isPresented: .init(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .statusBarHidden()
    }

    // MARK: - Subviews

    private var topBar: some View {
        HStack {
            Button {
                viewModel.scanningService.stopScanning()
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.white)
            }

            Spacer()

            // Format picker
            Picker("Format", selection: $exportFormat) {
                ForEach(ExportFormat.allCases, id: \.self) { format in
                    Text(format.rawValue).tag(format)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 140)
        }
        .padding()
    }

    private var scanStatsOverlay: some View {
        HStack(spacing: 20) {
            StatBadge(title: "Anchors", value: "\(viewModel.anchorCount)")
            StatBadge(title: "Vertices", value: viewModel.vertexCount.formatted())
            StatBadge(title: "Faces", value: viewModel.faceCount.formatted())
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
        .padding(.bottom, 8)
    }

    // MARK: - Actions

    private func finishScan() {
        Task {
            if let model = await viewModel.finishScan(format: exportFormat) {
                appState.addModel(model)
                completedModel = model
                showCompletionAlert = true
            }
        }
    }
}

// MARK: - Stat Badge

struct StatBadge: View {
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.headline.monospacedDigit())
                .foregroundStyle(.white)
            Text(title)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.7))
        }
    }
}
