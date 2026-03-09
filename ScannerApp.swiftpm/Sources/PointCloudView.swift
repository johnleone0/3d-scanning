import SwiftUI
import SceneKit
import simd

struct PointCloudView: UIViewRepresentable {
    let mesh: MergedMesh

    func makeUIView(context: Context) -> SCNView {
        let scnView = SCNView()
        scnView.scene = SCNScene()
        scnView.allowsCameraControl = true
        scnView.autoenablesDefaultLighting = true
        scnView.backgroundColor = .black

        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.camera?.automaticallyAdjustsZRange = true
        cameraNode.position = SCNVector3(0, 0, 2)
        scnView.scene?.rootNode.addChildNode(cameraNode)

        let pointCloudNode = buildPointCloudNode(from: mesh)
        scnView.scene?.rootNode.addChildNode(pointCloudNode)

        return scnView
    }

    func updateUIView(_ uiView: SCNView, context: Context) {
        guard let scene = uiView.scene else { return }

        // Remove existing point cloud nodes (tagged with name)
        scene.rootNode.childNodes
            .filter { $0.name == "pointCloud" }
            .forEach { $0.removeFromParentNode() }

        let pointCloudNode = buildPointCloudNode(from: mesh)
        scene.rootNode.addChildNode(pointCloudNode)
    }

    private func buildPointCloudNode(from mesh: MergedMesh) -> SCNNode {
        let vertexCount = mesh.vertices.count
        guard vertexCount > 0 else {
            let node = SCNNode()
            node.name = "pointCloud"
            return node
        }

        // Position source
        let positionData = mesh.vertices.withUnsafeBufferPointer { buffer in
            Data(bytes: buffer.baseAddress!, count: buffer.count * MemoryLayout<SIMD3<Float>>.stride)
        }
        let positionSource = SCNGeometrySource(
            data: positionData,
            semantic: .vertex,
            vectorCount: vertexCount,
            usesFloatComponents: true,
            componentsPerVector: 3,
            bytesPerComponent: MemoryLayout<Float>.size,
            dataOffset: 0,
            dataStride: MemoryLayout<SIMD3<Float>>.stride
        )

        // Color source
        let colorSource: SCNGeometrySource
        if mesh.hasColors {
            let colorData = mesh.colors.withUnsafeBufferPointer { buffer in
                Data(bytes: buffer.baseAddress!, count: buffer.count * MemoryLayout<SIMD3<Float>>.stride)
            }
            colorSource = SCNGeometrySource(
                data: colorData,
                semantic: .color,
                vectorCount: vertexCount,
                usesFloatComponents: true,
                componentsPerVector: 3,
                bytesPerComponent: MemoryLayout<Float>.size,
                dataOffset: 0,
                dataStride: MemoryLayout<SIMD3<Float>>.stride
            )
        } else {
            // Default white color for all vertices
            let white = [SIMD3<Float>](repeating: SIMD3<Float>(1, 1, 1), count: vertexCount)
            let colorData = white.withUnsafeBufferPointer { buffer in
                Data(bytes: buffer.baseAddress!, count: buffer.count * MemoryLayout<SIMD3<Float>>.stride)
            }
            colorSource = SCNGeometrySource(
                data: colorData,
                semantic: .color,
                vectorCount: vertexCount,
                usesFloatComponents: true,
                componentsPerVector: 3,
                bytesPerComponent: MemoryLayout<Float>.size,
                dataOffset: 0,
                dataStride: MemoryLayout<SIMD3<Float>>.stride
            )
        }

        // Point element
        let indices = (0..<UInt32(vertexCount)).map { $0 }
        let indexData = indices.withUnsafeBufferPointer { buffer in
            Data(bytes: buffer.baseAddress!, count: buffer.count * MemoryLayout<UInt32>.size)
        }
        let element = SCNGeometryElement(
            data: indexData,
            primitiveType: .point,
            primitiveCount: vertexCount,
            bytesPerIndex: MemoryLayout<UInt32>.size
        )
        element.pointSize = 2
        element.minimumPointScreenSpaceRadius = 1
        element.maximumPointScreenSpaceRadius = 5

        let geometry = SCNGeometry(sources: [positionSource, colorSource], elements: [element])
        let material = SCNMaterial()
        material.lightingModel = .constant
        geometry.materials = [material]

        let node = SCNNode(geometry: geometry)
        node.name = "pointCloud"
        return node
    }
}

struct PointCloudPreview: View {
    let mesh: MergedMesh

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            PointCloudView(mesh: mesh)

            Text("\(mesh.vertices.count.formatted()) vertices")
                .font(.caption)
                .monospacedDigit()
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 6))
                .padding(8)
        }
    }
}
