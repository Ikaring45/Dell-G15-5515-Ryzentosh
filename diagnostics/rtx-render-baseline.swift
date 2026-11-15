import Foundation
import Metal

enum Failure: Error { case unavailable, badResult }

func run() throws {
    let blend = CommandLine.arguments.contains("--blend")
    guard let gpu = MTLCopyAllDevices().first(where: { $0.name.contains("RTX 3060") }),
          let queue = gpu.makeCommandQueue() else { throw Failure.unavailable }
    let library = try gpu.makeLibrary(source: """
        #include <metal_stdlib>
        using namespace metal;
        vertex float4 vmain(uint i [[vertex_id]]) {
            const float2 p[3] = {float2(-1,-1), float2(3,-1), float2(-1,3)};
            return float4(p[i], 0, 1);
        }
        fragment float4 fmain() { return float4(0.25, 0.5, 0.75, \(blend ? "0.5" : "1.0")); }
        """, options: nil)
    let pipeline = MTLRenderPipelineDescriptor()
    pipeline.vertexFunction = library.makeFunction(name: "vmain")
    pipeline.fragmentFunction = library.makeFunction(name: "fmain")
    let attachment = pipeline.colorAttachments[0]!
    attachment.pixelFormat = .rgba8Unorm
    if blend {
        attachment.isBlendingEnabled = true
        attachment.sourceRGBBlendFactor = .sourceAlpha
        attachment.destinationRGBBlendFactor = .oneMinusSourceAlpha
        attachment.sourceAlphaBlendFactor = .one
        attachment.destinationAlphaBlendFactor = .oneMinusSourceAlpha
    }
    let state = try gpu.makeRenderPipelineState(descriptor: pipeline)

    for (width, height) in [(1920, 1080), (2560, 1440), (3840, 2160)] {
        let desc = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba8Unorm,
                                                            width: width, height: height, mipmapped: false)
        desc.usage = [.renderTarget, .shaderRead]
        guard let texture = gpu.makeTexture(descriptor: desc) else { throw Failure.unavailable }
        let pass = MTLRenderPassDescriptor()
        pass.colorAttachments[0].texture = texture
        pass.colorAttachments[0].loadAction = .clear
        pass.colorAttachments[0].storeAction = .store
        pass.colorAttachments[0].clearColor = blend ? MTLClearColorMake(1, 0, 0, 1) : MTLClearColorMake(0, 0, 0, 0)

        var samples = [Double]()
        for index in 0..<23 {
            let start = DispatchTime.now().uptimeNanoseconds
            guard let buffer = queue.makeCommandBuffer(),
                  let encoder = buffer.makeRenderCommandEncoder(descriptor: pass) else { throw Failure.unavailable }
            encoder.setRenderPipelineState(state)
            encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
            encoder.endEncoding()
            buffer.commit()
            buffer.waitUntilCompleted()
            if buffer.status != .completed { throw buffer.error ?? Failure.badResult }
            if index >= 3 { samples.append(Double(DispatchTime.now().uptimeNanoseconds - start) / 1_000_000) }
        }
        var pixel = [UInt8](repeating: 0, count: 4)
        texture.getBytes(&pixel, bytesPerRow: 4, from: MTLRegionMake2D(width / 2, height / 2, 1, 1), mipmapLevel: 0)
        let expected = blend ? [159, 64, 96, 255] : [64, 128, 191, 255]
        if zip(pixel, expected).contains(where: { abs(Int($0.0) - $0.1) > 1 }) { throw Failure.badResult }
        samples.sort()
        print(String(format: "RTX_%@_BASELINE %dx%d median_ms=%.3f p95_ms=%.3f passed=true",
                     blend ? "BLEND" : "RENDER", width, height, (samples[9] + samples[10]) / 2, samples[18]))
    }
}

do { try run() }
catch {
    fputs("\(error)\n", stderr)
    exit(1)
}
