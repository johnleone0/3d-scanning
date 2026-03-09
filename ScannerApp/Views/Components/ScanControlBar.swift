import SwiftUI

struct ScanControlBar: View {
    let scanState: ScanState
    let isProcessing: Bool
    let onStart: () -> Void
    let onPause: () -> Void
    let onResume: () -> Void
    let onFinish: () -> Void

    var body: some View {
        HStack(spacing: 30) {
            switch scanState {
            case .ready:
                scanButton(icon: "record.circle", label: "Start", color: .red) {
                    onStart()
                }

            case .scanning:
                scanButton(icon: "pause.circle.fill", label: "Pause", color: .yellow) {
                    onPause()
                }
                scanButton(icon: "stop.circle.fill", label: "Done", color: .green) {
                    onFinish()
                }

            case .paused:
                scanButton(icon: "play.circle.fill", label: "Resume", color: .blue) {
                    onResume()
                }
                scanButton(icon: "stop.circle.fill", label: "Done", color: .green) {
                    onFinish()
                }

            case .completed:
                if isProcessing {
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

    private func scanButton(
        icon: String,
        label: String,
        color: Color,
        action: @escaping () -> Void
    ) -> some View {
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
        .disabled(isProcessing)
    }
}
