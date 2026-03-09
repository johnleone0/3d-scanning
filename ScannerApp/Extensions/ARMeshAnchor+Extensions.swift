import ARKit

extension ARGeometrySource {
    /// Extracts vertex positions as an array of SIMD3<Float>.
    func asFloat3Array() -> [SIMD3<Float>] {
        let count = self.count
        let stride = self.stride
        let offset = self.offset
        let componentsPerVector = self.componentsPerVector

        var result: [SIMD3<Float>] = []
        result.reserveCapacity(count)

        let buffer = self.buffer
        let rawPointer = buffer.contents()

        for i in 0..<count {
            let pointer = rawPointer.advanced(by: offset + stride * i)
            if componentsPerVector >= 3 {
                let x = pointer.load(as: Float.self)
                let y = pointer.advanced(by: MemoryLayout<Float>.size).load(as: Float.self)
                let z = pointer.advanced(by: MemoryLayout<Float>.size * 2).load(as: Float.self)
                result.append(SIMD3<Float>(x, y, z))
            }
        }

        return result
    }
}

extension ARGeometryElement {
    /// Extracts face indices as a flat array of UInt32.
    func asUInt32Array() -> [UInt32] {
        let count = self.count
        let indexCountPerPrimitive = self.indexCountPerPrimitive
        let totalIndices = count * indexCountPerPrimitive

        var result: [UInt32] = []
        result.reserveCapacity(totalIndices)

        let buffer = self.buffer
        let rawPointer = buffer.contents()

        let bytesPerIndex = self.bytesPerIndex

        for i in 0..<totalIndices {
            let pointer = rawPointer.advanced(by: bytesPerIndex * i)
            switch bytesPerIndex {
            case 2:
                let value = pointer.load(as: UInt16.self)
                result.append(UInt32(value))
            case 4:
                let value = pointer.load(as: UInt32.self)
                result.append(value)
            default:
                let value = pointer.load(as: UInt8.self)
                result.append(UInt32(value))
            }
        }

        return result
    }
}
