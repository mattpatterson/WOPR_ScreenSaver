import Foundation
import CoreGraphics

struct Geo { let lat: Double; let lon: Double }

/// Miller-cylindrical world map, centered so North America sits left and the
/// USSR right (Atlantic/Europe in the middle), like the NORAD big board.
final class WorldMap {
    static let shared = WorldMap()

    let centerLon: Double = 10
    let latTop: Double = 82
    let latBottom: Double = -56

    /// Polylines in normalized map space: x in [0,1] (may exceed after unwrap), y in [0,1] (0 = bottom).
    private(set) var coast: [[CGPoint]] = []
    private(set) var usa: [[CGPoint]] = []
    private(set) var ussr: [[CGPoint]] = []

    private let yTop: Double
    private let yBottom: Double

    private init() {
        yTop = WorldMap.miller(latTop)
        yBottom = WorldMap.miller(latBottom)
        coast = decode(MapData.base64)
        usa = decode(MapData.usa)
        ussr = decode(MapData.ussr)
    }

    static func miller(_ lat: Double) -> Double {
        let phi = lat * .pi / 180
        return 1.25 * log(tan(.pi / 4 + 0.4 * phi))
    }

    /// Width / height ratio of the map in normalized units.
    var aspect: Double { (2 * .pi) / (yTop - yBottom) }

    /// Normalized x for a longitude, wrapped to [0,1).
    func nx(_ lon: Double) -> Double {
        var d = (lon - centerLon + 180).truncatingRemainder(dividingBy: 360)
        if d < 0 { d += 360 }
        return d / 360
    }

    func ny(_ lat: Double) -> Double {
        let l = max(min(lat, 89), -89)
        return (WorldMap.miller(l) - yBottom) / (yTop - yBottom)
    }

    func project(_ g: Geo) -> CGPoint { CGPoint(x: nx(g.lon), y: ny(g.lat)) }

    private func decode(_ b64: String) -> [[CGPoint]] {
        guard let data = Data(base64Encoded: b64, options: .ignoreUnknownCharacters) else { return [] }
        var vals = [Int16](repeating: 0, count: data.count / 2)
        _ = vals.withUnsafeMutableBytes { data.copyBytes(to: $0) }
        var lines: [[CGPoint]] = []
        var i = 0
        while i < vals.count {
            let n = Int(Int16(littleEndian: vals[i])); i += 1
            var cur: [CGPoint] = []
            var prevX: Double?
            for _ in 0..<n {
                guard i + 1 < vals.count else { break }
                let lon = Double(Int16(littleEndian: vals[i])) / 100
                let lat = Double(Int16(littleEndian: vals[i + 1])) / 100
                i += 2
                let x = nx(lon)
                // Split polylines that wrap across the map seam.
                if let px = prevX, abs(x - px) > 0.5 {
                    if cur.count > 1 { lines.append(cur) }
                    cur = []
                }
                cur.append(CGPoint(x: x, y: ny(lat)))
                prevX = x
            }
            if cur.count > 1 { lines.append(cur) }
        }
        return lines
    }

    /// Great-circle path from a to b, as normalized points with continuous (unwrapped) x.
    func greatCircle(_ a: Geo, _ b: Geo, samples: Int = 40, bulge: Double = 0.0) -> [CGPoint] {
        func vec(_ g: Geo) -> (Double, Double, Double) {
            let la = g.lat * .pi / 180, lo = g.lon * .pi / 180
            return (cos(la) * cos(lo), cos(la) * sin(lo), sin(la))
        }
        let va = vec(a), vb = vec(b)
        let dot = max(-1, min(1, va.0 * vb.0 + va.1 * vb.1 + va.2 * vb.2))
        let omega = acos(dot)
        var pts: [CGPoint] = []
        pts.reserveCapacity(samples + 1)
        var prevX: Double?
        for k in 0...samples {
            let s = Double(k) / Double(samples)
            var v: (Double, Double, Double)
            if omega < 1e-6 { v = va } else {
                let sa = sin((1 - s) * omega) / sin(omega), sb = sin(s * omega) / sin(omega)
                v = (sa * va.0 + sb * vb.0, sa * va.1 + sb * vb.1, sa * va.2 + sb * vb.2)
            }
            let lat = atan2(v.2, sqrt(v.0 * v.0 + v.1 * v.1)) * 180 / .pi
            let lon = atan2(v.1, v.0) * 180 / .pi
            var x = nx(lon)
            if let px = prevX {
                while x - px > 0.5 { x -= 1 }
                while x - px < -0.5 { x += 1 }
            }
            prevX = x
            // Ballistic "lift": push the track up in the middle of flight.
            let y = ny(lat) + bulge * omega * sin(.pi * s)
            pts.append(CGPoint(x: x, y: y))
        }
        return pts
    }
}

/// Maps normalized map coordinates to view points.
struct MapFrame {
    let rect: CGRect
    func pt(_ p: CGPoint) -> CGPoint { CGPoint(x: rect.minX + p.x * rect.width, y: rect.minY + p.y * rect.height) }
    func pt(_ g: Geo) -> CGPoint { pt(WorldMap.shared.project(g)) }

    /// Lay the whole map out in the given content area, preserving aspect.
    static func fit(in area: CGRect) -> MapFrame {
        let aspect = CGFloat(WorldMap.shared.aspect)
        var w = area.width, h = w / aspect
        if h > area.height { h = area.height; w = h * aspect }
        return MapFrame(rect: CGRect(x: area.midX - w / 2, y: area.midY - h / 2, width: w, height: h))
    }

    /// A zoomed view: `zoom` x the size of a full-world fit, with `center` in the middle of `area`.
    static func zoomed(in area: CGRect, center: Geo, zoom: CGFloat) -> MapFrame {
        let base = fit(in: area).rect
        let w = base.width * zoom, h = base.height * zoom
        let c = WorldMap.shared.project(center)
        return MapFrame(rect: CGRect(x: area.midX - c.x * w, y: area.midY - c.y * h, width: w, height: h))
    }
}

/// One rear-projection screen on the NORAD wall.
struct Viewport {
    let screen: CGRect      // bezel rect
    let map: MapFrame
    let blank: Bool
    let zoom: CGFloat
}

/// Static artwork for big-board screens: dark screen, faint grid, coastlines (teal),
/// the USA (blue) and USSR (red), pre-plotted target dots and the white bezel.
enum BoardArt {
    static func drawScreens(_ rc: RenderContext, _ vps: [Viewport], neighbors: Bool) {
        let ctx = rc.ctx, u = rc.u
        if neighbors, let first = vps.first { drawNeighborBezels(rc, around: first.screen) }
        for vp in vps {
            ctx.saveGState()
            ctx.clip(to: vp.screen)
            ctx.setFillColor(Theme.screen)
            ctx.fill(vp.screen)
            drawGrid(ctx, vp.screen, step: 34 * u, u: u)
            if !vp.blank { drawMap(rc, vp) }
            ctx.restoreGState()
            drawBezel(ctx, vp.screen, u: u)
        }
    }

    static func drawBezel(_ ctx: CGContext, _ r: CGRect, u: CGFloat) {
        Draw.glowStroke(ctx, CGPath(rect: r, transform: nil), color: Theme.frame, width: max(1, 3.2 * u), glow: 2.6, alpha: 0.95)
    }

    /// Bits of the neighbouring screens peeking in at the sides, like the film's wide shots.
    static func drawNeighborBezels(_ rc: RenderContext, around s: CGRect) {
        let u = rc.u, gap = 26 * u
        let left = s.minX - gap, right = s.maxX + gap
        let p = CGMutablePath()
        if left > 4 * u {
            p.move(to: CGPoint(x: left, y: s.minY)); p.addLine(to: CGPoint(x: left, y: s.maxY))
        }
        if right < rc.size.width - 4 * u {
            p.move(to: CGPoint(x: right, y: s.minY)); p.addLine(to: CGPoint(x: right, y: s.maxY))
        }
        if !p.isEmpty { Draw.glowStroke(rc.ctx, p, color: Theme.frame, width: max(1, 3 * u), glow: 2.4, alpha: 0.75) }
    }

    static func drawGrid(_ ctx: CGContext, _ r: CGRect, step: CGFloat, u: CGFloat) {
        let g = CGMutablePath()
        var x = r.minX + step
        while x < r.maxX { g.move(to: CGPoint(x: x, y: r.minY)); g.addLine(to: CGPoint(x: x, y: r.maxY)); x += step }
        var y = r.minY + step
        while y < r.maxY { g.move(to: CGPoint(x: r.minX, y: y)); g.addLine(to: CGPoint(x: r.maxX, y: y)); y += step }
        ctx.addPath(g)
        ctx.setStrokeColor(Theme.grid)
        ctx.setLineWidth(max(0.5, 1.0 * u))
        ctx.strokePath()
    }

    static func drawMap(_ rc: RenderContext, _ vp: Viewport) {
        let ctx = rc.ctx, u = rc.u
        let map = WorldMap.shared
        let f = vp.map
        let lw = max(0.7, 1.7 * u * min(1.4, sqrt(vp.zoom)))
        // Clip to the map's latitude band (horizontal wraps are allowed in zoomed views).
        ctx.saveGState()
        defer { ctx.restoreGState() }
        let y0 = max(vp.screen.minY, f.rect.minY), y1 = min(vp.screen.maxY, f.rect.maxY)
        ctx.clip(to: CGRect(x: vp.screen.minX, y: y0, width: vp.screen.width, height: max(0, y1 - y0)))
        func path(_ lines: [[CGPoint]]) -> CGPath {
            let p = CGMutablePath()
            // Draw the map and its neighbours left/right so zoomed views never show the seam.
            for dx in [-1.0, 0.0, 1.0] as [CGFloat] {
                let ox = dx * f.rect.width
                if f.rect.minX + ox > vp.screen.maxX || f.rect.maxX + ox < vp.screen.minX { continue }
                for ln in lines {
                    let a = f.pt(ln[0])
                    p.move(to: CGPoint(x: a.x + ox, y: a.y))
                    for q in ln.dropFirst() { let b = f.pt(q); p.addLine(to: CGPoint(x: b.x + ox, y: b.y)) }
                }
            }
            return p
        }
        Draw.glowStroke(ctx, path(map.coast), color: Theme.teal, width: lw, glow: 2.4, alpha: 0.9)
        Draw.glowStroke(ctx, path(map.usa), color: Theme.usBlue, width: lw * 1.1, glow: 2.6)
        Draw.glowStroke(ctx, path(map.ussr), color: Theme.ussrRed, width: lw * 1.1, glow: 2.6)

        // Pre-plotted targets: small dots, blue over the superpowers, pale elsewhere.
        let r = max(0.8, 1.7 * u * min(1.5, sqrt(vp.zoom)))
        let groups: [([Place], CGColor)] = [
            (Places.usTargets, Theme.usBlue),
            (Places.ussrTargets + Places.warsawTargets, Theme.with(Theme.missile, alpha: 0.95)),
            (Places.natoTargets + Places.chinaTargets + Places.farEastWest + Places.middleEast + Places.southAsia
             + Places.latinAmerica + Places.africa + Places.oceania + Places.northAtlantic, Theme.with(Theme.blob, alpha: 0.8)),
        ]
        for (places, color) in groups {
            let dots = CGMutablePath()
            for p in places {
                let c = f.pt(p.geo)
                dots.addEllipse(in: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r))
            }
            ctx.addPath(dots)
            ctx.setFillColor(color)
            ctx.fillPath()
        }
    }
}

/// Caches rendered static artwork (CGLayers) by key, for the offscreen/static path.
final class StaticCache {
    private var layers: [String: CGLayer] = [:]
    private var size: CGSize = .zero

    func draw(_ rc: RenderContext, key: String, render: (RenderContext) -> Void) {
        if size != rc.size { layers.removeAll(); size = rc.size }
        if layers[key] == nil, let l = CGLayer(rc.ctx, size: rc.size, auxiliaryInfo: nil), let lctx = l.context {
            render(RenderContext(ctx: lctx, size: rc.size))
            layers[key] = l
        }
        if let l = layers[key] { rc.ctx.draw(l, at: .zero) }
    }
}
