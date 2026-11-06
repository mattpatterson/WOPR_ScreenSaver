import Foundation
import CoreGraphics

/// Produces the per-frame dynamic image at a capped pixel budget. The static map and
/// CRT overlay are rendered once at full resolution and composited by the GPU.
final class LiveRenderer {
    let director: Director
    /// Upper bound on pixels drawn by the CPU per frame (~1080p+).
    var pixelBudget: CGFloat = 2_300_000

    private var contexts: [CGContext] = []
    private var flip = 0
    private var ctxKey: (CGSize, CGFloat) = (.zero, 0)
    private var mapImages: [String: CGImage] = [:]
    private var mapKeySize: CGSize = .zero
    private var mapKeyScale: CGFloat = 0

    init(director: Director) { self.director = director }

    func dynamicScale(size: CGSize, backing: CGFloat) -> CGFloat {
        let pts = max(1, size.width * size.height)
        return min(backing, max(0.35, sqrt(pixelBudget / pts)))
    }

    struct Frame { let image: CGImage?; let staticKey: String?; let staticRender: ((RenderContext) -> Void)? }

    func render(size: CGSize, backing: CGFloat, time: Double) -> Frame {
        let scale = dynamicScale(size: size, backing: backing)
        if contexts.isEmpty || ctxKey.0 != size || ctxKey.1 != scale {
            ctxKey = (size, scale)
            contexts = (0..<2).compactMap { _ in
                let c = CGContext(data: nil, width: max(1, Int(size.width * scale)), height: max(1, Int(size.height * scale)),
                                  bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)
                c?.scaleBy(x: scale, y: scale)
                c?.interpolationQuality = .low
                return c
            }
        }
        guard !contexts.isEmpty else { return Frame(image: nil, staticKey: nil, staticRender: nil) }
        flip = (flip + 1) % contexts.count
        let ctx = contexts[flip]
        Director.externalStatics = true
        director.draw(ctx: ctx, size: size, time: time)
        Director.externalStatics = false
        return Frame(image: ctx.makeImage(), staticKey: Director.frameStatic?.key, staticRender: Director.frameStatic?.render)
    }

    func staticImage(size: CGSize, key: String, backing: CGFloat, render: (RenderContext) -> Void) -> CGImage? {
        if mapKeySize != size || mapKeyScale != backing { mapImages.removeAll(); mapKeySize = size; mapKeyScale = backing }
        if let img = mapImages[key] { return img }
        let img = Director.staticImage(size: size, scale: backing, render: render)
        mapImages[key] = img
        return img
    }
}
