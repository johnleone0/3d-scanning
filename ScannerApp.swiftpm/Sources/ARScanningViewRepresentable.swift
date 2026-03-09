import SwiftUI
import RealityKit
import ARKit

struct ARScanningViewRepresentable: UIViewRepresentable {
    let scanningService: LiDARScanningService
    var visualizationMode: VisualizationMode = .mesh

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        arView.session = scanningService.arSession
        arView.automaticallyConfigureSession = false
        arView.renderOptions.insert(.disableMotionBlur)
        applyVisualizationMode(to: arView)
        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {
        applyVisualizationMode(to: uiView)
    }

    private func applyVisualizationMode(to arView: ARView) {
        // Reset debug options
        arView.debugOptions = []

        switch visualizationMode {
        case .mesh:
            arView.debugOptions.insert(.showSceneUnderstanding)
            arView.environment.sceneUnderstanding.options = [.receivesLighting]

        case .pointCloud:
            arView.debugOptions.insert(.showSceneUnderstanding)
            arView.debugOptions.insert(.showWorldOrigin)
            arView.environment.sceneUnderstanding.options = [.receivesLighting]

        case .solid:
            arView.debugOptions.insert(.showSceneUnderstanding)
            arView.environment.sceneUnderstanding.options = [.receivesLighting, .occlusion]
        }
    }
}
