import Foundation
import CoreGraphics

enum Bloc { case west, east, other
    var color: CGColor {
        switch self {
        case .west: return Theme.usa
        case .east: return Theme.ussr
        case .other: return Theme.amber
        }
    }
}

struct Wave {
    let bloc: Bloc
    let from: [Place]
    let to: [Place]
    let start: Double   // fraction of scene duration
    let spread: Double  // launches spread over this fraction
    let count: Int
}

struct ScenarioSpec {
    let title: String
    let waves: [Wave]
}

// MARK: - Scenario library

enum Scenarios {
    typealias P = Places
    static let westAll = P.usICBM + P.usSLBM
    static let eastAll = P.ussrICBM + P.ussrSLBM
    static let westWorld = P.ussrTargets + P.warsawTargets
    static let eastWorld = P.usTargets + P.natoTargets

    /// The long, detailed opening exchange.
    static let main = ScenarioSpec(title: "U.S.S.R. FIRST STRIKE", waves: [
        Wave(bloc: .east, from: P.ussrSLBM, to: P.usTargets, start: 0.04, spread: 0.08, count: 14),
        Wave(bloc: .east, from: P.ussrICBM, to: P.usTargets, start: 0.07, spread: 0.16, count: 70),
        Wave(bloc: .east, from: P.warsawIRBM, to: P.natoTargets, start: 0.09, spread: 0.12, count: 24),
        Wave(bloc: .west, from: P.usICBM, to: P.ussrTargets, start: 0.15, spread: 0.18, count: 70),
        Wave(bloc: .west, from: P.usSLBM, to: P.ussrTargets + P.warsawTargets, start: 0.17, spread: 0.16, count: 34),
        Wave(bloc: .west, from: P.natoIRBM, to: P.warsawTargets + P.ussrTargets, start: 0.19, spread: 0.12, count: 22),
        Wave(bloc: .east, from: P.ussrICBM + P.ussrSLBM, to: P.usTargets + P.farEastWest, start: 0.30, spread: 0.15, count: 46),
        Wave(bloc: .west, from: P.usICBM + P.usSLBM, to: P.ussrTargets + P.chinaTargets.prefix(3), start: 0.34, spread: 0.15, count: 46),
        Wave(bloc: .east, from: eastAll, to: eastWorld, start: 0.46, spread: 0.10, count: 16),
        Wave(bloc: .west, from: westAll, to: westWorld, start: 0.48, spread: 0.10, count: 16),
    ])

    static func exchange(_ title: String, first: Bloc, scale: Double = 1) -> ScenarioSpec {
        let n = { (x: Double) in max(2, Int(x * scale)) }
        let a = Wave(bloc: .west, from: westAll, to: westWorld, start: first == .west ? 0.05 : 0.2, spread: 0.25, count: n(60))
        let b = Wave(bloc: .east, from: eastAll, to: eastWorld, start: first == .east ? 0.05 : 0.2, spread: 0.25, count: n(60))
        let c = Wave(bloc: .west, from: P.natoIRBM, to: P.warsawTargets, start: 0.22, spread: 0.2, count: n(12))
        let d = Wave(bloc: .east, from: P.warsawIRBM, to: P.natoTargets, start: 0.22, spread: 0.2, count: n(12))
        return ScenarioSpec(title: title, waves: [a, b, c, d])
    }

    /// A regional conflict that drags the superpowers in.
    static func theater(_ title: String, region: [Place], westFrom: [Place], eastFrom: [Place],
                        local: Bool = false, escalation: Double = 1) -> ScenarioSpec {
        var w: [Wave] = []
        if local { w.append(Wave(bloc: .other, from: region, to: region, start: 0.03, spread: 0.2, count: 10)) }
        w.append(Wave(bloc: .west, from: westFrom, to: region, start: 0.06, spread: 0.2, count: 10))
        w.append(Wave(bloc: .east, from: eastFrom, to: region, start: 0.08, spread: 0.2, count: 10))
        if escalation > 0 {
            w.append(Wave(bloc: .east, from: eastAll, to: eastWorld, start: 0.25, spread: 0.25, count: Int(40 * escalation)))
            w.append(Wave(bloc: .west, from: westAll, to: westWorld, start: 0.28, spread: 0.25, count: Int(40 * escalation)))
        }
        return ScenarioSpec(title: title, waves: w)
    }

    /// The rapid-fire cycle that follows tic-tac-toe.
    static let cycle: [ScenarioSpec] = [
        exchange("U.S. FIRST STRIKE", first: .west),
        exchange("USSR FIRST STRIKE", first: .east),
        theater("NATO / WARSAW PACT", region: P.natoTargets + P.warsawTargets, westFrom: P.natoIRBM, eastFrom: P.warsawIRBM),
        theater("FAR EAST STRATEGY", region: P.farEastWest + Array(P.ussrTargets[20...26]), westFrom: P.usSLBM + P.usICBM, eastFrom: P.ussrSLBM),
        exchange("US USSR ESCALATION", first: .west, scale: 1.4),
        theater("MIDDLE EAST WAR", region: P.middleEast, westFrom: P.usSLBM + P.natoIRBM, eastFrom: P.warsawIRBM, local: true),
        theater("USSR CHINA ATTACK", region: P.chinaTargets, westFrom: P.chinaICBM, eastFrom: P.ussrICBM, escalation: 0.7),
        theater("INDIA PAKISTAN WAR", region: P.southAsia, westFrom: P.usSLBM, eastFrom: P.ussrICBM, local: true, escalation: 0.6),
        theater("MEDITERRANEAN WAR", region: P.natoTargets.filter { $0.geo.lat < 43 } + P.middleEast, westFrom: P.usSLBM, eastFrom: P.warsawIRBM),
        theater("HONGKONG VARIANT", region: P.farEastWest + P.chinaTargets, westFrom: P.usSLBM, eastFrom: P.ussrICBM),
        theater("SEATO DECAPITATING", region: P.farEastWest + P.southAsia, westFrom: P.usSLBM, eastFrom: P.ussrSLBM),
        theater("CUBAN PROVOCATION", region: P.latinAmerica + P.usTargets, westFrom: P.usICBM, eastFrom: [P.latinAmerica[0], P.latinAmerica[10]] + P.ussrSLBM),
        exchange("ATLANTIC HEAVY", first: .east, scale: 1.2),
        theater("CUBAN PARAMILITARY", region: P.latinAmerica, westFrom: P.usICBM, eastFrom: P.ussrSLBM, local: true),
        theater("NICARAGUAN PREEMPTIVE", region: P.latinAmerica + Array(P.usTargets.prefix(15)), westFrom: P.usICBM, eastFrom: [P.latinAmerica[1]] + P.ussrSLBM),
        theater("PACIFIC TERRITORIAL", region: P.farEastWest + P.oceania, westFrom: P.usSLBM, eastFrom: P.ussrSLBM),
        theater("BURMESE THEATERWIDE", region: P.southAsia + Array(P.chinaTargets.prefix(5)), westFrom: P.usSLBM, eastFrom: P.ussrICBM, local: true),
        theater("TURKISH DECOY", region: P.natoTargets.filter { $0.geo.lon > 25 } + P.middleEast, westFrom: P.natoIRBM, eastFrom: P.warsawIRBM),
        theater("ARGENTINA ESCALATION", region: P.latinAmerica + P.africa, westFrom: P.usSLBM, eastFrom: P.ussrSLBM, local: true),
        theater("ICELAND MAXIMUM", region: P.northAtlantic + P.natoTargets.prefix(6), westFrom: P.usSLBM, eastFrom: P.ussrSLBM + P.ussrICBM, escalation: 1.5),
        theater("ARABIAN THEATERWIDE", region: P.middleEast + [P.southAsia[2]], westFrom: P.usSLBM, eastFrom: P.ussrICBM, local: true),
        exchange("U.S. SUBVERSION", first: .west, scale: 0.8),
        theater("AUSTRALIAN MANEUVER", region: P.oceania + P.farEastWest, westFrom: P.usSLBM, eastFrom: P.ussrSLBM),
        theater("SUDAN SURPRISE", region: P.africa + P.middleEast.prefix(6), westFrom: P.usSLBM, eastFrom: P.warsawIRBM, local: true),
        theater("NATO TERRITORIAL", region: P.natoTargets, westFrom: P.natoIRBM, eastFrom: P.warsawIRBM + P.ussrICBM),
        theater("ICELAND INCIDENT", region: P.northAtlantic, westFrom: P.usSLBM, eastFrom: P.ussrSLBM),
        theater("ENGLISH ESCALATION", region: Array(P.natoTargets.prefix(3)) + [P.natoTargets[13], P.natoTargets[20], P.natoIRBM[0]], westFrom: P.natoIRBM, eastFrom: P.warsawIRBM, escalation: 1.3),
        theater("MIDDLE EAST HEAVY", region: P.middleEast, westFrom: P.usSLBM + P.natoIRBM, eastFrom: P.ussrICBM, local: true, escalation: 1.4),
        theater("MEXICAN TAKEOVER", region: P.latinAmerica.prefix(4) + P.usTargets.suffix(30), westFrom: P.usICBM, eastFrom: P.ussrSLBM),
        theater("IRANIAN DIVERSION", region: P.middleEast + P.southAsia.prefix(4), westFrom: P.usSLBM, eastFrom: P.ussrICBM, local: true),
        theater("LIBYAN LOCAL", region: P.middleEast.filter { $0.geo.lon < 35 } + P.africa.prefix(4), westFrom: P.natoIRBM, eastFrom: P.warsawIRBM, local: true),
        theater("ZAIRE ALLIANCE", region: P.africa, westFrom: P.usSLBM, eastFrom: P.ussrSLBM, local: true),
        theater("EGYPT PARAMILITARY", region: P.middleEast + P.africa.prefix(3), westFrom: P.usSLBM, eastFrom: P.warsawIRBM, local: true),
        theater("PAKISTAN SOVEREIGNTY", region: P.southAsia, westFrom: P.usSLBM, eastFrom: P.ussrICBM, local: true),
        theater("AFGHANISTAN MISDIRECTION", region: P.southAsia + P.middleEast.prefix(2), westFrom: P.usSLBM, eastFrom: P.ussrICBM),
        theater("ETHIOPIAN CALAMITY", region: P.africa + P.middleEast.suffix(3), westFrom: P.usSLBM, eastFrom: P.ussrSLBM, local: true),
        theater("GREENLAND INCURSION", region: P.northAtlantic, westFrom: P.usICBM, eastFrom: P.ussrSLBM, escalation: 1.2),
        theater("KAMCHATKA GAMBIT", region: Array(P.ussrTargets[26...26]) + P.farEastWest.suffix(4) + [P.usTargets[24]], westFrom: P.usSLBM, eastFrom: P.ussrSLBM),
        exchange("GLOBAL THERMONUCLEAR WAR", first: .east, scale: 1.6),
    ]
}

// MARK: - Simulation

// MARK: - Simulation

struct Missile {
    let bloc: Bloc
    let launch: Double
    let flight: Double
    let path: [CGPoint]           // normalized, unwrapped
    let wraps: Int                // -1, 0, +1: which neighbor copy is also needed
    let targetName: String
    var impact: Double { launch + flight }
}

/// Accumulated finished trails + detonation blobs. One per Director (i.e. per view/display).
/// Keyed by camera, so cutting between the big board and the wall only catches up, never rebuilds.
final class TrailCache {
    final class Entry {
        var owner: ObjectIdentifier?
        var layer: CGLayer?
        var count = 0
        var size = CGSize.zero
    }
    private var entries: [String: Entry] = [:]
    func entry(_ key: String) -> Entry {
        if let e = entries[key] { return e }
        let e = Entry(); entries[key] = e; return e
    }
}

/// The NORAD big board running one scenario.
///   .full  — the long opening exchange (single screen, with a cut to the wall of screens)
///   .flash — one scenario in the accelerating cycle
///   .wall  — a cycle scenario shown across the wall of zoomed screens
final class WarScene: WOPRScene {
    enum Detail { case full, flash, wall }

    let duration: Double
    let spec: ScenarioSpec
    let detail: Detail
    let index: Int
    private(set) var missiles: [Missile] = []
    private let impactsByTime: [Int]
    private let trailCache: TrailCache

    init(spec: ScenarioSpec, duration: Double, seed: UInt64, detail: Detail, index: Int = 0, total: Int = 0, density: Double = 1,
         trailCache: TrailCache = TrailCache()) {
        self.trailCache = trailCache
        self.spec = spec
        self.duration = duration
        self.detail = detail
        self.index = index
        var rng = SplitMix64(seed: seed)
        let map = WorldMap.shared
        var ms: [Missile] = []
        for w in spec.waves where !w.from.isEmpty && !w.to.isEmpty {
            let count = max(1, Int((Double(w.count) * density).rounded()))
            for _ in 0..<count {
                let from = w.from[Int(rng.next() % UInt64(w.from.count))]
                var to = w.to[Int(rng.next() % UInt64(w.to.count))]
                if to.name == from.name { to = w.to[(Int(rng.next() % UInt64(w.to.count)))] }
                let fg = Geo(lat: from.geo.lat + rng.range(-1.2, 1.2), lon: from.geo.lon + rng.range(-1.8, 1.8))
                let tg = Geo(lat: to.geo.lat + rng.range(-0.4, 0.4), lon: to.geo.lon + rng.range(-0.6, 0.6))
                let launch = duration * min(0.6, w.start + w.spread * pow(rng.unit(), 0.8))
                let va = WarScene.angle(fg, tg)
                let flight = duration * (0.035 + 0.24 * va / .pi) * rng.range(0.9, 1.1)
                let path = map.greatCircle(fg, tg, samples: 36, bulge: 0.016)
                let minX = path.map(\.x).min() ?? 0, maxX = path.map(\.x).max() ?? 0
                let wraps = minX < 0 ? 1 : (maxX > 1 ? -1 : 0)
                ms.append(Missile(bloc: w.bloc, launch: launch, flight: flight, path: path, wraps: wraps, targetName: to.name))
            }
        }
        missiles = ms
        impactsByTime = ms.indices.sorted { ms[$0].impact < ms[$1].impact }
    }

    static func angle(_ a: Geo, _ b: Geo) -> Double {
        let la1 = a.lat * .pi / 180, la2 = b.lat * .pi / 180
        let dl = (b.lon - a.lon) * .pi / 180
        let c = sin(la1) * sin(la2) + cos(la1) * cos(la2) * cos(dl)
        return acos(max(-1, min(1, c)))
    }

    // MARK: Camera

    private enum Camera: String { case single, wall }

    private func camera(at t: Double) -> Camera {
        switch detail {
        case .flash: return .single
        case .wall: return .wall
        case .full:
            // Cut to the wall of screens mid-exchange, then back to the big board.
            let k = t / duration
            return (k > 0.42 && k < 0.6) ? .wall : .single
        }
    }

    /// Single big screen: bezel fills the height, title row at the bottom inside the bezel.
    static func singleViewport(_ rc: RenderContext) -> Viewport {
        let u = rc.u
        let margin = 26 * u, pad = 22 * u, titleRow = 118 * u
        let outer = CGRect(x: margin, y: margin, width: rc.size.width - 2 * margin, height: rc.size.height - 2 * margin)
        let mapArea = CGRect(x: outer.minX + pad, y: outer.minY + titleRow, width: outer.width - 2 * pad, height: outer.height - titleRow - pad)
        let mf = MapFrame.fit(in: mapArea)
        let screenW = min(outer.width, mf.rect.width + 2 * pad)
        let screen = CGRect(x: rc.size.width / 2 - screenW / 2, y: outer.minY, width: screenW, height: outer.height)
        return Viewport(screen: screen, map: mf, blank: false, zoom: 1)
    }

    /// The wall: 3 x 2 screens, each zoomed on a region (one dark, as in the film).
    static func wallViewports(_ rc: RenderContext) -> [Viewport] {
        let u = rc.u
        let gap = 22 * u, margin = 26 * u
        let cols = 3, rows = 2
        let w = (rc.size.width - 2 * margin - CGFloat(cols - 1) * gap) / CGFloat(cols)
        let h = (rc.size.height - 2 * margin - CGFloat(rows - 1) * gap) / CGFloat(rows)
        let views: [(Geo, CGFloat, Bool)] = [
            (Geo(lat: 44, lon: -100), 2.9, false),  // top left: North America
            (Geo(lat: 14, lon: 10), 1.0, false),    // top middle: the world
            (Geo(lat: 52, lon: 50), 2.4, false),    // top right: Europe / USSR
            (Geo(lat: 52, lon: -30), 2.2, false),   // bottom left: North Atlantic
            (Geo(lat: 0, lon: 0), 1, true),         // bottom middle: dark
            (Geo(lat: 42, lon: 125), 2.5, false),   // bottom right: Far East
        ]
        var out: [Viewport] = []
        for r in 0..<rows {
            for c in 0..<cols {
                let screen = CGRect(x: margin + CGFloat(c) * (w + gap), y: rc.size.height - margin - CGFloat(r + 1) * h - CGFloat(r) * gap,
                                    width: w, height: h)
                let v = views[r * cols + c]
                out.append(Viewport(screen: screen, map: MapFrame.zoomed(in: screen.insetBy(dx: 8 * u, dy: 8 * u), center: v.0, zoom: v.1),
                                    blank: v.2, zoom: v.1))
            }
        }
        return out
    }

    private func viewports(_ rc: RenderContext, _ cam: Camera) -> [Viewport] {
        cam == .single ? [WarScene.singleViewport(rc)] : WarScene.wallViewports(rc)
    }

    // MARK: Draw

    func draw(_ rc: RenderContext, t: Double) {
        let cam = camera(at: t)
        let vps = viewports(rc, cam)
        Director.provideStatic(rc, key: "board-\(cam.rawValue)") { src in
            BoardArt.drawScreens(src, cam == .single ? [WarScene.singleViewport(src)] : WarScene.wallViewports(src),
                                 neighbors: cam == .single)
        }
        let k = doneCount(t)
        drawDoneLayer(rc, vps, cam: cam, upTo: k)
        // The opening exchange cuts between cameras: keep the off-screen camera's cache current
        // (a few missiles per frame) so the cut itself never has to rebuild it.
        if detail == .full {
            let other: Camera = cam == .single ? .wall : .single
            drawDoneLayer(rc, viewports(rc, other), cam: other, upTo: k, composite: false)
        }
        for vp in vps where !vp.blank {
            rc.ctx.saveGState()
            rc.ctx.clip(to: vp.screen.insetBy(dx: 2 * rc.u, dy: 2 * rc.u))
            drawLive(rc, vp, t: t)
            rc.ctx.restoreGState()
        }
        if cam == .single { drawCaptions(rc, vps[0], t: t) } else { drawWallCaption(rc, vps, t: t) }
    }

    // MARK: Missiles

    private func addPath(_ path: CGMutablePath, _ m: Missile, upTo p: Double, frame: MapFrame) {
        let n = m.path.count - 1
        let f = p * Double(n)
        let k = min(n, Int(f))
        for shift in (m.wraps == 0 ? [0] : [0, m.wraps]) {
            let dx = CGFloat(shift)
            func P(_ q: CGPoint) -> CGPoint { frame.pt(CGPoint(x: q.x + dx, y: q.y)) }
            path.move(to: P(m.path[0]))
            if k >= 1 { for i in 1...k { path.addLine(to: P(m.path[i])) } }
            if k < n {
                let a = m.path[k], b = m.path[k + 1], r = CGFloat(f - Double(k))
                path.addLine(to: P(CGPoint(x: a.x + (b.x - a.x) * r, y: a.y + (b.y - a.y) * r)))
            }
        }
    }

    private func points(_ m: Missile, p: Double, frame: MapFrame) -> [CGPoint] {
        let n = m.path.count - 1
        let f = min(1, max(0, p)) * Double(n)
        let k = min(n - 1, Int(f))
        let a = m.path[k], b = m.path[k + 1], r = CGFloat(f - Double(k))
        let q = CGPoint(x: a.x + (b.x - a.x) * r, y: a.y + (b.y - a.y) * r)
        var out = [frame.pt(q)]
        if m.wraps != 0 { out.append(frame.pt(CGPoint(x: q.x + CGFloat(m.wraps), y: q.y))) }
        return out
    }

    /// Beaded vector streak: a soft continuous glow under a string of bright dots.
    private func strokeStreak(_ ctx: CGContext, _ p: CGPath, u: CGFloat, zoom: CGFloat, alpha: CGFloat, beads: Bool = true) {
        let w = max(0.8, 2.3 * u * min(1.3, sqrt(zoom)))
        ctx.saveGState()
        ctx.setLineCap(.round)
        ctx.setLineJoin(.round)
        ctx.addPath(p)
        ctx.setStrokeColor(Theme.with(Theme.missile, alpha: 0.16 * alpha))
        ctx.setLineWidth(w * 3.6)
        ctx.strokePath()
        ctx.addPath(p)
        ctx.setStrokeColor(Theme.with(Theme.missile, alpha: 0.85 * alpha))
        ctx.setLineWidth(w)
        // Beaded texture (CG dashing is costly, so only for trails drawn once into the cache).
        if beads { ctx.setLineDash(phase: 0, lengths: [0.01, w * 1.9]) } else { ctx.setLineWidth(w * 0.75) }
        ctx.strokePath()
        ctx.restoreGState()
    }

    private func blobRadius(_ u: CGFloat, _ zoom: CGFloat) -> CGFloat { 11 * u * min(1.8, sqrt(zoom)) }

    /// Soft white detonation blob (fill-only, cheap).
    private func drawBlob(_ ctx: CGContext, _ c: CGPoint, r: CGFloat, alpha: CGFloat) {
        ctx.setFillColor(Theme.with(Theme.blob, alpha: 0.22 * alpha))
        ctx.fillEllipse(in: CGRect(x: c.x - r * 1.45, y: c.y - r * 1.45, width: r * 2.9, height: r * 2.9))
        ctx.setFillColor(Theme.with(Theme.blob, alpha: 0.55 * alpha))
        ctx.fillEllipse(in: CGRect(x: c.x - r * 1.12, y: c.y - r * 1.12, width: r * 2.24, height: r * 2.24))
        ctx.setFillColor(Theme.with(Theme.blob, alpha: 0.92 * alpha))
        ctx.fillEllipse(in: CGRect(x: c.x - r * 0.85, y: c.y - r * 0.85, width: r * 1.7, height: r * 1.7))
    }

    private func doneCount(_ t: Double) -> Int {
        var lo = 0, hi = impactsByTime.count
        while lo < hi {
            let mid = (lo + hi) / 2
            if missiles[impactsByTime[mid]].impact <= t { lo = mid + 1 } else { hi = mid }
        }
        return lo
    }

    /// Finished trails + blobs only ever grow (a prefix of `impactsByTime`), so they're accumulated
    /// incrementally. Each missile is drawn in full, one at a time, so batching never changes the result.
    private func drawDoneLayer(_ rc: RenderContext, _ vps: [Viewport], cam: Camera, upTo k: Int, composite: Bool = true) {
        let c = trailCache.entry(cam.rawValue)
        let me = ObjectIdentifier(self)
        if c.layer == nil || c.owner != me || c.size != rc.size || k < c.count {
            c.owner = me; c.size = rc.size; c.count = 0
            c.layer = CGLayer(rc.ctx, size: rc.size, auxiliaryInfo: nil)
        }
        guard let layer = c.layer, let lctx = layer.context else { return }
        if k > c.count {
            let u = rc.u
            for i in impactsByTime[c.count..<k] {
                let m = missiles[i]
                for vp in vps where !vp.blank {
                    lctx.saveGState()
                    lctx.clip(to: vp.screen.insetBy(dx: 2 * u, dy: 2 * u))
                    let p = CGMutablePath()
                    addPath(p, m, upTo: 1, frame: vp.map)
                    strokeStreak(lctx, p, u: u, zoom: vp.zoom, alpha: 0.62)
                    for e in points(m, p: 1, frame: vp.map) { drawBlob(lctx, e, r: blobRadius(u, vp.zoom), alpha: 0.85) }
                    lctx.restoreGState()
                }
            }
            c.count = k
        }
        if composite { rc.ctx.draw(layer, at: .zero) }
    }

    private func drawLive(_ rc: RenderContext, _ vp: Viewport, t: Double) {
        let ctx = rc.ctx, u = rc.u
        let bloomT = min(1.2, max(0.2, duration * 0.04))
        let trails = CGMutablePath()
        var heads: [CGPoint] = []
        for m in missiles where t >= m.launch && t < m.impact {
            let p = (t - m.launch) / m.flight
            addPath(trails, m, upTo: p, frame: vp.map)
            heads.append(contentsOf: points(m, p: p, frame: vp.map))
        }
        if !trails.isEmpty { strokeStreak(ctx, trails, u: u, zoom: vp.zoom, alpha: 1, beads: false) }

        // Launch flares: a bright blob that fades at the silo/sub.
        for m in missiles where t >= m.launch && t < m.launch + bloomT * 1.4 {
            let a = 1 - (t - m.launch) / (bloomT * 1.4)
            for p in points(m, p: 0, frame: vp.map) { drawBlob(ctx, p, r: blobRadius(u, vp.zoom) * CGFloat(0.5 + 0.4 * a), alpha: CGFloat(a)) }
        }
        // Warheads.
        if !heads.isEmpty {
            let r = max(1, 3.0 * u * min(1.3, sqrt(vp.zoom)))
            for (rr, a) in [(r * 2.6, 0.2), (r * 1.5, 0.45), (r, 1.0)] as [(CGFloat, CGFloat)] {
                let dots = CGMutablePath()
                for h in heads { dots.addEllipse(in: CGRect(x: h.x - rr, y: h.y - rr, width: 2 * rr, height: 2 * rr)) }
                ctx.addPath(dots)
                ctx.setFillColor(Theme.with(a == 1 ? Theme.blob : Theme.missile, alpha: a))
                ctx.fillPath()
            }
        }
        // Fresh detonations swell before settling into the persistent blob.
        for m in missiles where t >= m.impact && t < m.impact + bloomT {
            let k = (t - m.impact) / bloomT
            let r = blobRadius(u, vp.zoom) * CGFloat(0.4 + 1.1 * sin(.pi * 0.5 * min(1, k * 1.6)) - 0.3 * k)
            for p in points(m, p: 1, frame: vp.map) { drawBlob(ctx, p, r: r, alpha: CGFloat(1 - 0.5 * k)) }
        }
    }

    // MARK: Captions (big-board lettering at the bottom of the screen)

    private var titleUntil: Double { duration < 2.5 ? duration : max(2.2, duration * 0.09) }
    private var winnerAt: Double { duration * (detail == .full ? 0.88 : 0.76) }
    private var noneAt: Double { winnerAt + min(1.2, duration * 0.07) }

    private func drawCaptions(_ rc: RenderContext, _ vp: Viewport, t: Double) {
        let u = rc.u
        let size = 40 * u
        let baseline = vp.screen.minY + 44 * u
        if t < titleUntil {
            VectorFont.draw(rc.ctx, spec.title, x: vp.screen.midX, baselineY: baseline, size: size, color: Theme.title, align: .center)
        } else if t >= winnerAt {
            let label = "WINNER:", none = "NONE"
            let gapW = VectorFont.width("   ", size: size)
            let total = VectorFont.width(label, size: size) + gapW + VectorFont.width(none, size: size)
            let x0 = vp.screen.midX - total / 2
            let w = VectorFont.draw(rc.ctx, label, x: x0, baselineY: baseline, size: size, color: Theme.title)
            if t >= noneAt {
                VectorFont.draw(rc.ctx, none, x: x0 + w + gapW, baselineY: baseline, size: size, color: Theme.title)
            }
        }
    }

    private func drawWallCaption(_ rc: RenderContext, _ vps: [Viewport], t: Double) {
        // The title (and later the verdict) appears on the dark screen of the wall.
        guard let dark = vps.first(where: { $0.blank }) else { return }
        let u = rc.u
        let size = 26 * u
        let text: String
        if t >= noneAt { text = "WINNER: NONE" } else if t >= winnerAt { text = "WINNER:" } else { text = spec.title }
        VectorFont.draw(rc.ctx, text, x: dark.screen.midX, baselineY: dark.screen.midY - size / 2, size: size, color: Theme.title, align: .center)
    }
}
