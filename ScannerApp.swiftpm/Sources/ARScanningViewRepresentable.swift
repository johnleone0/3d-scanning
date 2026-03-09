import SwiftUI
import RealityKit
import ARKit

struct ARScanningViewRepresentable: UIViewRepresentable {
    let scanningService: LiDARScanningService

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        arView.session = scanningService.arSession
        arView.debugOptions.insert(.showSceneUnderstanding)
        arView.environment.sceneUnderstanding.options = [.receivesLighting, .occlusion]
        arView.automaticallyConfigureSession = false
        arView.renderOptions.insert(.disableMotionBlur)
        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {}
}
