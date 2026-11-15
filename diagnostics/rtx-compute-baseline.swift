import Foundation
import Metal

struct CheckFailure: Error {
    let message: String
}

func run() throws {
    guard let gpu = MTLCopyAllDevices().first(where: { $0.name.contains("RTX 3060") }),
          let queue = gpu.makeCommandQueue() else {
        throw CheckFailure(message: "RTX 3060 compute queue unavailable")
    }
    let library = try gpu.makeLibrary(source: """
        #include <metal_stdlib>
        using namespace metal;
        kernel void sample(device uint *output [[buffer(0)]], uint id [[thread_position_in_grid]]) {
            uint value = id;
            for (uint i = 0; i < 64; ++i)
                value = (value ^ (value >> 13)) * 1664525u + 1013904223u;
            output[id] = value;
        }
        """, options: nil)
    guard let function = library.makeFunction(name: "sample") else {
        throw CheckFailure(message: "Metal function unavailable")
    }
    let pipeline = try gpu.makeComputePipelineState(function: function)
    let elements = 1 << 20
    guard let output = gpu.makeBuffer(length: elements * MemoryLayout<UInt32>.stride,
                                      options: .storageModeShared) else {
        throw CheckFailure(message: "GPU buffer allocation failed")
    }

    let width = pipeline.threadExecutionWidth
    var samples = [Double]()
    for index in 0..<23 {
        let start = DispatchTime.now().uptimeNanoseconds
        guard let command = queue.makeCommandBuffer(), let encoder = command.makeComputeCommandEncoder() else {
            throw CheckFailure(message: "Metal command allocation failed")
        }
        encoder.setComputePipelineState(pipeline)
        encoder.setBuffer(output, offset: 0, index: 0)
        encoder.dispatchThreads(MTLSize(width: elements, height: 1, depth: 1),
                                threadsPerThreadgroup: MTLSize(width: width, height: 1, depth: 1))
        encoder.endEncoding()
        command.commit()
        command.waitUntilCompleted()
        guard command.status == .completed else {
            throw CheckFailure(message: "Metal command failed: \(String(describing: command.error))")
        }
        if index >= 3 {
            samples.append(Double(DispatchTime.now().uptimeNanoseconds - start) / 1_000_000)
        }
    }

    let results = output.contents().assumingMemoryBound(to: UInt32.self)
    for index in [0, elements / 2, elements - 1] {
        var expected = UInt32(index)
        for _ in 0..<64 { expected = ((expected ^ (expected >> 13)) &* 1664525) &+ 1013904223 }
        guard results[index] == expected else {
            throw CheckFailure(message: "GPU result mismatch at \(index)")
        }
    }
    samples.sort()
    let median = (samples[9] + samples[10]) / 2
    print(String(format: "RTX_COMPUTE_BASELINE samples=%d median_ms=%.3f p95_ms=%.3f passed=true",
                 samples.count, median, samples[18]))
}

do {
    try run()
} catch {
    fputs("\(error)\n", stderr)
    exit(1)
}
