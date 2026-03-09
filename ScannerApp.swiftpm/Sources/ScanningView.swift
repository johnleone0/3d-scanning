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
            // AR Camera feed with mesh wireframe overlay
            ARScanningViewRepresentable(scanningService: viewModel.scanningService)
                .ignoresSafeArea()

            VStack {
                // Top bar: close button + format picker
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

                    Picker("Format", selection: $exportFormat) {
                        ForEach(ExportFormat.allCases, id: \.self) { format in
                            Text(format.rawValue).tag(format)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 140)
                }
                .padding()

                Spacer()

                // Live stats during scan
                if viewModel.scanState == .scanning || viewModel.scanState == .paused {
                    HStack(spacing: 20) {
                        StatLabel(title: "Anchors", value: "\(viewModel.anchorCount)")
                        StatLabel(title: "Vertices", value: viewModel.vertexCount.formatted())
                        StatLabel(title: "Faces", value: viewModel.faceCount.formatted())
                    }
                    .padding()
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                }

                // Scan controls
                scanControls
                    .padding(.bottom, 30)
            }
        }
        .alert("Scan Complete", isPresented: $showCompletionAlert) {
            Button("View Model") { dismiss() }
            Button("New Scan") { viewModel = ScanningViewModel() }
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

    @ViewBuilder
    private var scanControls: some View {
        HStack(spacing: 30) {
            switch viewModel.scanState {
            case .ready:
                controlButton(icon: "record.circle", label: "Start", color: .red) {
                    viewModel.startScan()
                }

            case .scanning:
                controlButton(icon: "pause.circle.fill", label: "Pause", color: .yellow) {
                    viewModel.pauseScan()
                }
                controlButton(icon: "stop.circle.fill", label: "Done", color: .green) {
                    finishScan()
                }

            case .paused:
                controlButton(icon: "play.circle.fill", label: "Resume", color: .blue) {
                    viewModel.resumeScan()
                }
                controlButton(icon: "stop.circle.fill", label: "Done", color: .green) {
                    finishScan()
                }

            case .completed:
                if viewModel.isProcessing {
                    ProgressView()
                        .tint(.white)
                    Text("Processing...")
                        .foregroundStyle(.white)
                        .font(.headline)
                }
            }
        }
        .padding(.horizontal, 30)
        .padding(.vertical, 16)
        .background(.ultraThinMaterial, in: Capsule())
    }

    private func controlButton(icon: String, label: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 44))
                    .foregroundStyle(color)
                Text(label)
                    .font(.caption.bold())
                    .foregroundStyle(.white)
            }
        }
        .disabled(viewModel.isProcessing)
    }

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

struct StatLabel: View {
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
