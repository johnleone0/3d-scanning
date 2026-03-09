import SwiftUI
import simd

struct MeshSimplifyView: View {
    let mesh: MergedMesh
    let onSimplify: (MergedMesh) -> Void

    @State private var reductionPercent: Double = 50
    @State private var resultMesh: MergedMesh?
    @State private var isProcessing = false

    private var targetReduction: Float {
        Float(reductionPercent / 100.0)
    }

    private var estimatedVertexCount: Int {
        max(1, Int(Double(mesh.vertices.count) * (1.0 - reductionPercent / 100.0)))
    }

    private var estimatedFaceCount: Int {
        max(1, Int(Double(mesh.faceCount) * (1.0 - reductionPercent / 100.0)))
    }

    private var displayMesh: MergedMesh {
        resultMesh ?? mesh
    }

    var body: some View {
        VStack(spacing: 0) {
            PointCloudPreview(mesh: displayMesh)
                .frame(maxHeight: .infinity)

            Divider()

            VStack(spacing: 16) {
                // Reduction slider
                VStack(alignment: .leading, spacing: 4) {
                    Text("Reduction: \(Int(reductionPercent))%")
                        .font(.headline)

                    Slider(value: $reductionPercent, in: 0...90, step: 1) {
                        Text("Reduction")
                    } onEditingChanged: { editing in
                        if !editing {
                            // Clear previous result when slider changes
                            resultMesh = nil
                        }
                    }

                    HStack {
                        Text("0%")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("90%")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                // Stats
                statsSection

                // Action button
                Button {
                    performSimplification()
                } label: {
                    if isProcessing {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("Simplify")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isProcessing || reductionPercent == 0)

                if resultMesh != nil {
                    Button("Apply Result") {
                        if let result = resultMesh {
                            onSimplify(result)
                        }
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding()
        }
    }

    @ViewBuilder
    private var statsSection: some View {
        let hasResult = resultMesh != nil

        VStack(spacing: 8) {
            HStack {
                statColumn(title: "Before", vertices: mesh.vertices.count, faces: mesh.faceCount)
                Spacer()
                Image(systemName: "arrow.right")
                    .foregroundStyle(.secondary)
                Spacer()
                if hasResult, let result = resultMesh {
                    statColumn(title: "After", vertices: result.vertices.count, faces: result.faceCount)
                } else {
                    statColumn(title: "Estimated", vertices: estimatedVertexCount, faces: estimatedFaceCount)
                }
            }
        }
        .padding()
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))
    }

    @ViewBuilder
    private func statColumn(title: String, vertices: Int, faces: Int) -> some View {
        VStack(alignment: .center, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("\(vertices.formatted()) verts")
                .font(.subheadline)
                .monospacedDigit()
            Text("\(faces.formatted()) faces")
                .font(.caption)
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
    }

    private func performSimplification() {
        isProcessing = true
        let reduction = targetReduction
        let inputMesh = mesh
        DispatchQueue.global(qos: .userInitiated).async {
            let result = MeshProcessingService.simplifyMesh(inputMesh, targetReduction: reduction)
            DispatchQueue.main.async {
                resultMesh = result
                isProcessing = false
            }
        }
    }
}
