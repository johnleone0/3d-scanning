import SwiftUI
import RealityKit
import ARKit

struct ARScanningViewRepresentable: UIViewRepresentable {
    let scanningService: LiDARScanningService

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)

        // Use the scanning service's AR session
        arView.session = scanningService.arSession

        // Show the real-time mesh wireframe overlay from LiDAR
        arView.debugOptions.insert(.showSceneUnderstanding)

        // Enable scene understanding features
        arView.environment.sceneUnderstanding.options = [
            .receivesLighting,
            .occlusion
        ]

        // Disable automatic AR session configuration (we manage it ourselves)
        arView.automaticallyConfigureSession = false

        // Enable person occlusion if available
        arView.renderOptions.insert(.disableMotionBlur)

        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {
        // No dynamic updates needed — the ARSession drives everything
    }
}
