import SwiftUI
import simd

struct MeshEditView: View {
    let mesh: MergedMesh
    let onCrop: (MergedMesh) -> Void

    @State private var cropMin: SIMD3<Float> = .zero
    @State private var cropMax: SIMD3<Float> = .zero
    @State private var originalMin: SIMD3<Float> = .zero
    @State private var originalMax: SIMD3<Float> = .zero
    @State private var isProcessing = false

    private var previewMesh: MergedMesh {
        filterVerticesInBounds(mesh, min: cropMin, max: cropMax)
    }

    var body: some View {
        VStack(spacing: 0) {
            PointCloudPreview(mesh: previewMesh)
                .frame(maxHeight: .infinity)

            Divider()

            ScrollView {
                VStack(spacing: 16) {
                    axisSliders(label: "X", minVal: $cropMin.x, maxVal: $cropMax.x,
                                range: originalMin.x...originalMax.x)
                    axisSliders(label: "Y", minVal: $cropMin.y, maxVal: $cropMax.y,
                                range: originalMin.y...originalMax.y)
                    axisSliders(label: "Z", minVal: $cropMin.z, maxVal: $cropMax.z,
                                range: originalMin.z...originalMax.z)

                    Text("\(previewMesh.vertices.count.formatted()) of \(mesh.vertices.count.formatted()) vertices in region")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 16) {
                        Button("Reset") {
                            resetBounds()
                        }
                        .buttonStyle(.bordered)

                        Button("Apply Crop") {
                            applyCrop()
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(isProcessing)
                    }
                    .padding(.bottom, 8)
                }
                .padding()
            }
            .frame(maxHeight: 320)
        }
        .onAppear {
            let bb = MeshProcessingService.boundingBox(of: mesh)
            originalMin = bb.min
            originalMax = bb.max
            cropMin = bb.min
            cropMax = bb.max
        }
    }

    @ViewBuilder
    private func axisSliders(label: String, minVal: Binding<Float>, maxVal: Binding<Float>,
                             range: ClosedRange<Float>) -> some View {
        let span = range.upperBound - range.lowerBound
        let effectiveRange = span > 0 ? range : (range.lowerBound - 0.5)...(range.upperBound + 0.5)

        VStack(alignment: .leading, spacing: 4) {
            Text("\(label) Axis")
                .font(.headline)

            HStack {
                Text("Min")
                    .font(.caption)
                    .frame(width: 30)
                Slider(value: minVal, in: effectiveRange)
                Text(String(format: "%.3f", minVal.wrappedValue))
                    .font(.caption)
                    .monospacedDigit()
                    .frame(width: 60, alignment: .trailing)
            }

            HStack {
                Text("Max")
                    .font(.caption)
                    .frame(width: 30)
                Slider(value: maxVal, in: effectiveRange)
                Text(String(format: "%.3f", maxVal.wrappedValue))
                    .font(.caption)
                    .monospacedDigit()
                    .frame(width: 60, alignment: .trailing)
            }
        }
    }

    private func resetBounds() {
        cropMin = originalMin
        cropMax = originalMax
    }

    private func applyCrop() {
        isProcessing = true
        let result = MeshProcessingService.cropMesh(mesh, min: cropMin, max: cropMax)
        isProcessing = false
        onCrop(result)
    }

    /// Lightweight vertex filter for the live preview (no face remapping needed for point display).
    private func filterVerticesInBounds(_ mesh: MergedMesh, min bbMin: SIMD3<Float>, max bbMax: SIMD3<Float>) -> MergedMesh {
        var verts: [SIMD3<Float>] = []
        var norms: [SIMD3<Float>] = []
        var cols: [SIMD3<Float>] = []

        for (i, v) in mesh.vertices.enumerated() {
            let inside = v.x >= bbMin.x && v.x <= bbMax.x
                      && v.y >= bbMin.y && v.y <= bbMax.y
                      && v.z >= bbMin.z && v.z <= bbMax.z
            if inside {
                verts.append(v)
                if i < mesh.normals.count { norms.append(mesh.normals[i]) }
                if i < mesh.colors.count { cols.append(mesh.colors[i]) }
            }
        }

        return MergedMesh(vertices: verts, normals: norms, faces: [], colors: cols)
    }
}
