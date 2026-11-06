import Foundation
import CoreGraphics

/// A plain black pause between acts.
final class BlackScene: WOPRScene {
    let duration: Double
    init(_ d: Double) { duration = d }
    func draw(_ rc: RenderContext, t: Double) {}
}

/// The full loop:
///   intro terminal -> long detailed exchange -> tic-tac-toe -> accelerating
///   scenario cycle with strobing -> blackout -> closing terminal message.
final class Director {
    struct Entry {
        let scene: WOPRScene
        let start: Double
        let fadeIn: Double
        let fadeOut: Double
        let strobe: Bool
        let name: String
    }

    private(set) var entries: [Entry] = []
    private(set) var total: Double = 0
    private let crt = CRTOverlay()
    /// Per-Director so several views (one per display) never invalidate each other's cache.
    let trailCache = TrailCache()

    init(seed: UInt64 = 1983) {
        build(seed: seed)
    }

    private func add(_ s: WOPRScene, _ name: String, fadeIn: Double = 0, fadeOut: Double = 0, strobe: Bool = false) {
        entries.append(Entry(scene: s, start: total, fadeIn: fadeIn, fadeOut: fadeOut, strobe: strobe, name: name))
        total += s.duration
    }

    private func build(seed: UInt64) {
        var rng = SplitMix64(seed: seed)
        add(BlackScene(1.0), "black")
        add(TerminalScene.intro(), "intro", fadeIn: 0.4, fadeOut: 0.6)
        add(BlackScene(0.8), "black")
        add(WarScene(spec: Scenarios.main, duration: 56, seed: rng.next(), detail: .full, density: 0.6, trailCache: trailCache),
            "main", fadeIn: 1.0, fadeOut: 0.6)
        add(LaunchCodeScene(duration: 9, seed: rng.next()), "code", fadeIn: 0.3, fadeOut: 0.3)
        add(BlackScene(0.6), "black")
        add(TicTacToeScene(duration: 14, seed: rng.next()), "tictactoe", fadeIn: 0.4)

        // Accelerating cycle, as in the film: ~10 s per scenario at first, then a strobe.
        // After the first three, the WOPR posts its scoreboard; later it flashes it again.
        let cycle = Scenarios.cycle
        var d = 8.0
        var i = 0
        var cycleTime = 0.0
        var lastFlash = -10.0
        var played: [String] = []
        while cycleTime < 46 {
            let spec: ScenarioSpec
            if i < cycle.count { spec = cycle[i] } else { spec = cycle[Int(rng.next() % UInt64(cycle.count))] }
            let density = min(1.0, 0.35 + d / 6)
            // Strobe on short scenes, but never more than ~2.5 flashes/s (photosensitivity: WCAG 2.3.1 < 3 Hz).
            let flash = d < 1.2 && cycleTime - lastFlash >= 0.4
            if flash { lastFlash = cycleTime }
            // Every few mid-length scenarios cut to the wall of zoomed screens.
            let detail: WarScene.Detail = (d > 1.5 && i % 3 == 2) ? .wall : .flash
            add(WarScene(spec: spec, duration: d, seed: rng.next(), detail: detail, index: i, density: density,
                         trailCache: trailCache), "cycle", strobe: flash)
            played.append(spec.title)
            cycleTime += d
            if i == 2 {
                add(StrategyTableScene(rows: played, duration: 3.5), "table")
            } else if i == 9 {
                add(StrategyTableScene(rows: played, duration: 2.8, preShown: 3), "table")
            }
            d = max(0.28, d * 0.8)
            i += 1
        }
        add(StrategyTableScene(rows: played, duration: 2.5, preShown: max(0, played.count - 6)), "table")
        add(BlackScene(3.0), "black")
        add(TerminalScene.ending(), "ending", fadeIn: 0.3, fadeOut: 1.5)
        add(BlackScene(2.5), "black")
    }

    /// Start time (seconds into the loop) of the first entry with this name.
    func startOf(_ name: String) -> Double { entries.first { $0.name == name }?.start ?? 0 }

    func entry(at time: Double) -> (Entry, Double) {
        let t = time.truncatingRemainder(dividingBy: total)
        var lo = 0, hi = entries.count - 1
        while lo < hi {
            let mid = (lo + hi + 1) / 2
            if entries[mid].start <= t { lo = mid } else { hi = mid - 1 }
        }
        let e = entries[lo]
        return (e, min(max(0, t - e.start), e.scene.duration - 1e-6))
    }

    /// When true (the live view), the static world map and CRT overlay are composited by the
    /// GPU as separate CALayers; scenes then only report where the map goes.
    static var externalStatics = false
    /// Static artwork the current frame wants under it (live path), or nil.
    static var frameStatic: (key: String, render: (RenderContext) -> Void)?
    /// Static artwork cache for the offscreen/all-in-one path (render tool).
    private static let offlineStatics = StaticCache()

    /// Scenes call this for their unchanging artwork (screens, map, bezels). In the live view it's
    /// rendered once at full resolution and composited by the GPU; offscreen it's drawn from a cache.
    static func provideStatic(_ rc: RenderContext, key: String, render: @escaping (RenderContext) -> Void) {
        if externalStatics { frameStatic = (key, render) } else { offlineStatics.draw(rc, key: key, render: render) }
    }

    func draw(ctx: CGContext, size: CGSize, time: Double) {
        let rc = RenderContext(ctx: ctx, size: size)
        let bounds = CGRect(origin: .zero, size: size)
        Director.frameStatic = nil
        if Director.externalStatics { ctx.clear(bounds) } else {
            ctx.setFillColor(Theme.background)
            ctx.fill(bounds)
        }

        let (e, t) = entry(at: max(0, time))
        ctx.saveGState()
        e.scene.draw(rc, t: t)
        ctx.restoreGState()

        // Fades to black.
        var black = 0.0
        if e.fadeIn > 0, t < e.fadeIn { black = max(black, 1 - t / e.fadeIn) }
        if e.fadeOut > 0, t > e.scene.duration - e.fadeOut { black = max(black, (t - (e.scene.duration - e.fadeOut)) / e.fadeOut) }
        if black > 0 {
            ctx.setFillColor(Theme.with(Theme.background, alpha: CGFloat(min(1, black))))
            ctx.fill(bounds)
        }
        // Strobe: the NORAD room flashes white as each scenario resolves.
        if e.strobe, t < 0.06 {
            ctx.setFillColor(CGColor(red: 0.9, green: 0.95, blue: 1, alpha: 0.4))
            ctx.fill(bounds)
        }
        if !Director.externalStatics { crt.draw(rc) }
    }

    /// Renders static artwork to an image for a CALayer.
    static func staticImage(size: CGSize, scale: CGFloat, render: (RenderContext) -> Void) -> CGImage? {
        guard let ctx = CGContext(data: nil, width: Int(size.width * scale), height: Int(size.height * scale), bitsPerComponent: 8,
                                  bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue) else { return nil }
        ctx.scaleBy(x: scale, y: scale)
        render(RenderContext(ctx: ctx, size: size))
        return ctx.makeImage()
    }

    static func crtImage(size: CGSize, scale: CGFloat) -> CGImage? {
        guard let ctx = CGContext(data: nil, width: Int(size.width * scale), height: Int(size.height * scale), bitsPerComponent: 8,
                                  bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue) else { return nil }
        ctx.scaleBy(x: scale, y: scale)
        CRTOverlay().draw(RenderContext(ctx: ctx, size: size))
        return ctx.makeImage()
    }
}

/// Scanlines + vignette, cached per size.
final class CRTOverlay {
    private var layer: CGLayer?
    private var key: CGSize = .zero

    func draw(_ rc: RenderContext) {
        if layer == nil || key != rc.size {
            key = rc.size
            layer = CGLayer(rc.ctx, size: rc.size, auxiliaryInfo: nil)
            if let l = layer?.context { render(l, rc.size, rc.u) }
        }
        if let layer { rc.ctx.draw(layer, at: .zero) }
    }

    private func render(_ ctx: CGContext, _ size: CGSize, _ u: CGFloat) {
        let step = max(2, 3 * u)
        ctx.setFillColor(CGColor(gray: 0, alpha: 0.22))
        var y: CGFloat = 0
        while y < size.height {
            ctx.fill(CGRect(x: 0, y: y, width: size.width, height: step * 0.4))
            y += step
        }
        let cs = CGColorSpaceCreateDeviceRGB()
        if let g = CGGradient(colorsSpace: cs, colors: [CGColor(gray: 0, alpha: 0), CGColor(gray: 0, alpha: 0.55)] as CFArray, locations: [0.55, 1]) {
            let c = CGPoint(x: size.width / 2, y: size.height / 2)
            ctx.drawRadialGradient(g, startCenter: c, startRadius: 0, endCenter: c,
                                   endRadius: hypot(size.width, size.height) / 2, options: [.drawsAfterEndLocation])
        }
    }
}
