import ARKit
import CoreVideo
import simd
import Accelerate

/// Maps camera frame RGB pixels onto mesh vertices by projecting each vertex
/// into the camera image using ARFrame camera intrinsics and extrinsics.
struct ColorCaptureService {

    /// Default color used when a vertex projects outside the camera frame.
    private static let defaultColor = SIMD3<Float>(0.5, 0.5, 0.5) // neutral gray

    /// Captures per-vertex colors by projecting mesh vertices into the most recent camera frame.
    ///
    /// - Parameters:
    ///   - anchors: Array of ARMeshAnchors containing the mesh geometry.
    ///   - frame: The most recent ARFrame whose capturedImage will be sampled.
    ///   - orientation: The interface orientation for correct projection. Defaults to `.portrait`.
    /// - Returns: An array of SIMD3<Float> RGB colors (0-1 range), one per vertex across all anchors
    ///   in the same order that `MeshProcessingService.mergeMeshAnchors` produces vertices.
    static func captureColors(
        from anchors: [ARMeshAnchor],
        frame: ARFrame,
        orientation: UIInterfaceOrientation = .portrait
    ) -> [SIMD3<Float>] {
        let camera = frame.camera
        let pixelBuffer = frame.capturedImage

        let imageWidth = CVPixelBufferGetWidth(pixelBuffer)
        let imageHeight = CVPixelBufferGetHeight(pixelBuffer)

        // Camera intrinsics (3x3) and view matrix (4x4)
        let intrinsics = camera.intrinsics
        let viewMatrix = camera.viewMatrix(for: orientation)

        // Projection pipeline:
        // worldPoint -> cameraSpace (viewMatrix) -> imageCoords (intrinsics)

        // Lock pixel buffer once for all reads
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }

        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else {
            return anchors.flatMap { anchor in
                Array(repeating: defaultColor, count: anchor.geometry.vertices.count)
            }
        }

        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        let pixelFormat = CVPixelBufferGetPixelFormatType(pixelBuffer)

        var allColors: [SIMD3<Float>] = []

        for anchor in anchors {
            let geometry = anchor.geometry
            let vertices = geometry.vertices.asFloat3Array()
            let anchorTransform = anchor.transform

            var colors: [SIMD3<Float>] = []
            colors.reserveCapacity(vertices.count)

            for localVertex in vertices {
                // Transform vertex from anchor-local to world space
                let worldPos4 = anchorTransform * SIMD4<Float>(localVertex.x, localVertex.y, localVertex.z, 1.0)
                let worldPos = SIMD3<Float>(worldPos4.x, worldPos4.y, worldPos4.z)

                // Project to camera space
                let cameraPos4 = viewMatrix * SIMD4<Float>(worldPos.x, worldPos.y, worldPos.z, 1.0)

                // Skip vertices behind the camera
                guard cameraPos4.z < 0 else {
                    colors.append(defaultColor)
                    continue
                }

                // Project to 2D using intrinsics
                // Camera convention: looking down -Z, so we negate Z for projection
                let zInv = -1.0 / cameraPos4.z
                let px = intrinsics[0][0] * cameraPos4.x * zInv + intrinsics[2][0]
                let py = intrinsics[1][1] * cameraPos4.y * zInv + intrinsics[2][1]

                let pixelX = Int(px.rounded())
                let pixelY = Int(py.rounded())

                // Check bounds
                guard pixelX >= 0, pixelX < imageWidth,
                      pixelY >= 0, pixelY < imageHeight else {
                    colors.append(defaultColor)
                    continue
                }

                let color = samplePixel(
                    baseAddress: baseAddress,
                    bytesPerRow: bytesPerRow,
                    pixelFormat: pixelFormat,
                    x: pixelX,
                    y: pixelY
                )
                colors.append(color)
            }

            allColors.append(contentsOf: colors)
        }

        return allColors
    }

    /// Samples a single pixel from the CVPixelBuffer's raw memory.
    /// Handles both BGRA and bi-planar YCbCr (420v/420f) formats.
    private static func samplePixel(
        baseAddress: UnsafeMutableRawPointer,
        bytesPerRow: Int,
        pixelFormat: OSType,
        x: Int,
        y: Int
    ) -> SIMD3<Float> {
        if pixelFormat == kCVPixelFormatType_32BGRA {
            return sampleBGRA(baseAddress: baseAddress, bytesPerRow: bytesPerRow, x: x, y: y)
        } else {
            // For YCbCr formats (420v, 420f), we cannot use the simple base address
            // approach because they're bi-planar. Fall back to the default color here;
            // callers should use the bi-planar variant instead.
            return defaultColor
        }
    }

    private static func sampleBGRA(
        baseAddress: UnsafeMutableRawPointer,
        bytesPerRow: Int,
        x: Int,
        y: Int
    ) -> SIMD3<Float> {
        let offset = y * bytesPerRow + x * 4
        let ptr = baseAddress.advanced(by: offset).assumingMemoryBound(to: UInt8.self)
        let b = Float(ptr[0]) / 255.0
        let g = Float(ptr[1]) / 255.0
        let r = Float(ptr[2]) / 255.0
        return SIMD3<Float>(r, g, b)
    }

    /// Captures per-vertex colors with full support for bi-planar YCbCr pixel buffers
    /// (the default format for ARFrame.capturedImage on iOS).
    ///
    /// This variant handles the 420v/420f pixel format by reading from Y and CbCr planes
    /// separately and converting to RGB.
    static func captureColorsYCbCr(
        from anchors: [ARMeshAnchor],
        frame: ARFrame,
        orientation: UIInterfaceOrientation = .portrait
    ) -> [SIMD3<Float>] {
        let camera = frame.camera
        let pixelBuffer = frame.capturedImage

        let imageWidth = CVPixelBufferGetWidth(pixelBuffer)
        let imageHeight = CVPixelBufferGetHeight(pixelBuffer)

        let intrinsics = camera.intrinsics
        let viewMatrix = camera.viewMatrix(for: orientation)

        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }

        // Get Y plane (plane 0)
        guard let yBaseAddress = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0) else {
            return anchors.flatMap { Array(repeating: defaultColor, count: $0.geometry.vertices.count) }
        }
        let yBytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 0)

        // Get CbCr plane (plane 1) - half resolution in each dimension
        guard let cbcrBaseAddress = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 1) else {
            return anchors.flatMap { Array(repeating: defaultColor, count: $0.geometry.vertices.count) }
        }
        let cbcrBytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 1)

        var allColors: [SIMD3<Float>] = []

        for anchor in anchors {
            let geometry = anchor.geometry
            let vertices = geometry.vertices.asFloat3Array()
            let anchorTransform = anchor.transform

            var colors: [SIMD3<Float>] = []
            colors.reserveCapacity(vertices.count)

            for localVertex in vertices {
                let worldPos4 = anchorTransform * SIMD4<Float>(localVertex.x, localVertex.y, localVertex.z, 1.0)

                let cameraPos4 = viewMatrix * SIMD4<Float>(worldPos4.x, worldPos4.y, worldPos4.z, 1.0)

                guard cameraPos4.z < 0 else {
                    colors.append(defaultColor)
                    continue
                }

                let zInv = -1.0 / cameraPos4.z
                let px = intrinsics[0][0] * cameraPos4.x * zInv + intrinsics[2][0]
                let py = intrinsics[1][1] * cameraPos4.y * zInv + intrinsics[2][1]

                let pixelX = Int(px.rounded())
                let pixelY = Int(py.rounded())

                guard pixelX >= 0, pixelX < imageWidth,
                      pixelY >= 0, pixelY < imageHeight else {
                    colors.append(defaultColor)
                    continue
                }

                let color = sampleYCbCr(
                    yBase: yBaseAddress,
                    yBytesPerRow: yBytesPerRow,
                    cbcrBase: cbcrBaseAddress,
                    cbcrBytesPerRow: cbcrBytesPerRow,
                    x: pixelX,
                    y: pixelY
                )
                colors.append(color)
            }

            allColors.append(contentsOf: colors)
        }

        return allColors
    }

    /// Samples from bi-planar YCbCr and converts to RGB.
    private static func sampleYCbCr(
        yBase: UnsafeMutableRawPointer,
        yBytesPerRow: Int,
        cbcrBase: UnsafeMutableRawPointer,
        cbcrBytesPerRow: Int,
        x: Int,
        y: Int
    ) -> SIMD3<Float> {
        // Y plane: full resolution, one byte per pixel
        let yPtr = yBase.advanced(by: y * yBytesPerRow + x).assumingMemoryBound(to: UInt8.self)
        let yVal = Float(yPtr.pointee)

        // CbCr plane: half resolution, two bytes per sample (Cb, Cr interleaved)
        let chromaX = x / 2
        let chromaY = y / 2
        let cbcrPtr = cbcrBase.advanced(by: chromaY * cbcrBytesPerRow + chromaX * 2).assumingMemoryBound(to: UInt8.self)
        let cb = Float(cbcrPtr[0]) - 128.0
        let cr = Float(cbcrPtr[1]) - 128.0

        // BT.601 YCbCr to RGB conversion
        let r = yVal + 1.402 * cr
        let g = yVal - 0.344136 * cb - 0.714136 * cr
        let b = yVal + 1.772 * cb

        return SIMD3<Float>(
            min(max(r / 255.0, 0), 1),
            min(max(g / 255.0, 0), 1),
            min(max(b / 255.0, 0), 1)
        )
    }
}
