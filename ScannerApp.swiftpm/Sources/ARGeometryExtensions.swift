import ARKit

extension ARGeometrySource {
    func asFloat3Array() -> [SIMD3<Float>] {
        let count = self.count
        let stride = self.stride
        let offset = self.offset
        let componentsPerVector = self.componentsPerVector

        var result: [SIMD3<Float>] = []
        result.reserveCapacity(count)

        let rawPointer = self.buffer.contents()

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
    func asUInt32Array() -> [UInt32] {
        let count = self.count
        let indexCountPerPrimitive = self.indexCountPerPrimitive
        let totalIndices = count * indexCountPerPrimitive

        var result: [UInt32] = []
        result.reserveCapacity(totalIndices)

        let rawPointer = self.buffer.contents()
        let bytesPerIndex = self.bytesPerIndex

        for i in 0..<totalIndices {
            let pointer = rawPointer.advanced(by: bytesPerIndex * i)
            switch bytesPerIndex {
            case 2:
                result.append(UInt32(pointer.load(as: UInt16.self)))
            case 4:
                result.append(pointer.load(as: UInt32.self))
            default:
                result.append(UInt32(pointer.load(as: UInt8.self)))
            }
        }

        return result
    }
}

extension simd_float4x4 {
    var translation: SIMD3<Float> {
        SIMD3<Float>(columns.3.x, columns.3.y, columns.3.z)
    }
}
