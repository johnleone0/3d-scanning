import simd

extension simd_float4x4 {
    /// Extract the translation component from a 4x4 transform matrix.
    var translation: SIMD3<Float> {
        SIMD3<Float>(columns.3.x, columns.3.y, columns.3.z)
    }
}

/// Convenience to create float3 from float4 (dropping w).
func simd_make_float3(_ v: SIMD4<Float>) -> SIMD3<Float> {
    SIMD3<Float>(v.x, v.y, v.z)
}
