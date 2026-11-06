import CoreGraphics

/// Big-board lettering: a single-stroke vector font in the style of the HP vector displays on
/// the NORAD big board ("U.S. FIRST STRIKE", "WINNER: NONE"). Uniform thin strokes, simple
/// geometric sans, Hershey/plotter-like.
///
/// Glyphs are polylines on a grid where the cap height is 6 units and most letters are
/// 4 units wide. Strings are built once into a unit path (cap height = 1) cached per
/// (string, tracking) and scaled/translated with the CTM at draw time.
enum VectorFont {
    /// Draws `s` with its baseline at `baselineY` (CG coords). `size` is the cap height.
    /// `tracking` is extra spacing between glyphs as a fraction of `size`. Lowercase is drawn
    /// as uppercase. Returns drawn width.
    @discardableResult
    static func draw(_ ctx: CGContext, _ s: String, x: CGFloat, baselineY: CGFloat, size: CGFloat,
                     color: CGColor, align: Draw.Align = .left, tracking: CGFloat = 0.35, alpha: CGFloat = 1) -> CGFloat {
        guard size > 0, !s.isEmpty else { return 0 }
        let e = entry(s, tracking: tracking)
        let w = e.width * size
        var ox = x
        if align == .center { ox -= w / 2 } else if align == .right { ox -= w }
        guard !e.path.isEmpty, alpha > 0 else { return w }
        if useBitmapCache, let m = mask(e, key: Key(s: s, tracking: tracking), size: size, ctx: ctx) {
            var r = CGRect(x: ox + m.origin.x, y: baselineY + m.origin.y, width: m.size.width, height: m.size.height)
            // Snap to whole device pixels so the cached mask stays crisp.
            let t = ctx.userSpaceToDeviceSpaceTransform
            if t.b == 0, t.c == 0 {
                var d = r.origin.applying(t)
                d.x = d.x.rounded(); d.y = d.y.rounded()
                r.origin = d.applying(t.inverted())
            }
            ctx.saveGState()
            ctx.clip(to: r, mask: m.image)
            ctx.setFillColor(color.copy(alpha: color.alpha * alpha) ?? color)
            ctx.fill(r)
            ctx.restoreGState()
            return w
        }
        strokeVector(ctx, e.path, x: ox, baselineY: baselineY, size: size, color: color, alpha: alpha)
        return w
    }

    /// When true (default), each (string, size, device scale) is rasterized once into a glow mask
    /// and blitted; stroking the vector paths every frame costs ~8 ms per 10 strings at 1080p.
    static var useBitmapCache = true

    private static func strokeVector(_ ctx: CGContext, _ unitPath: CGPath, x: CGFloat, baselineY: CGFloat,
                                     size: CGFloat, color: CGColor, alpha: CGFloat) {
        ctx.saveGState()
        ctx.translateBy(x: x, y: baselineY)
        ctx.scaleBy(x: size, y: size)
        Draw.glowStroke(ctx, unitPath, color: color, width: strokeWidth(size: size) / size, glow: glow, alpha: alpha)
        ctx.restoreGState()
    }

    private static let glow: CGFloat = 2.2

    /// Width in points of `s` at cap height `size` (no trailing tracking).
    static func width(_ s: String, size: CGFloat, tracking: CGFloat = 0.35) -> CGFloat {
        guard !s.isEmpty else { return 0 }
        return entry(s, tracking: tracking).width * size
    }

    /// The core stroke width used for a given cap height.
    static func strokeWidth(size: CGFloat) -> CGFloat { max(size * 0.085, 0.7) }

    /// The string as an (unstroked) centerline path, origin at the left end of the baseline,
    /// scaled so the cap height is `size`.
    static func path(_ s: String, size: CGFloat, tracking: CGFloat = 0.35) -> CGPath {
        let e = entry(s, tracking: tracking)
        var t = CGAffineTransform(scaleX: size, y: size)
        return e.path.copy(using: &t) ?? e.path
    }

    // MARK: - Cache

    private struct Key: Hashable { let s: String; let tracking: CGFloat }
    private struct Entry { let path: CGPath; let width: CGFloat }   // unit cap height
    private static var cache: [Key: Entry] = [:]

    private static func entry(_ s: String, tracking: CGFloat) -> Entry {
        let key = Key(s: s, tracking: tracking)
        if let e = cache[key] { return e }
        if cache.count >= 512 { cache.removeAll(keepingCapacity: true) }
        let e = build(s, tracking: tracking)
        cache[key] = e
        return e
    }

    private struct MaskKey: Hashable { let k: Key; let size: CGFloat; let scale: CGFloat }
    /// `origin`/`size` are in user points relative to the string's baseline origin.
    private struct Mask { let image: CGImage; let origin: CGPoint; let size: CGSize; let bytes: Int }
    private static var masks: [MaskKey: Mask] = [:]
    private static var maskBytes = 0
    private static let maxMaskBytes = 48 << 20

    private static func mask(_ e: Entry, key: Key, size: CGFloat, ctx: CGContext) -> Mask? {
        let t = ctx.userSpaceToDeviceSpaceTransform
        let scale = max(0.05, (t.a * t.a + t.b * t.b).squareRoot())
        let mk = MaskKey(k: key, size: size, scale: scale)
        if let m = masks[mk] { return m }
        let lw = strokeWidth(size: size)
        let pad = lw * glow + 2 / scale
        let b = e.path.boundingBoxOfPath
        let origin = CGPoint(x: b.minX * size - pad, y: b.minY * size - pad)
        let pw = Int(((b.width * size + 2 * pad) * scale).rounded(.up))
        let ph = Int(((b.height * size + 2 * pad) * scale).rounded(.up))
        guard pw > 0, ph > 0, pw * ph < 16_000_000,
              let mc = CGContext(data: nil, width: pw, height: ph, bitsPerComponent: 8, bytesPerRow: 0,
                                 space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue)
        else { return nil }
        mc.setFillColor(gray: 0, alpha: 1)
        mc.fill(CGRect(x: 0, y: 0, width: pw, height: ph))
        mc.scaleBy(x: scale, y: scale)
        // Painting white over black with the same passes as Draw.glowStroke yields exactly the
        // combined coverage, so filling `color` through this mask matches the vector rendering.
        strokeVector(mc, e.path, x: -origin.x, baselineY: -origin.y, size: size,
                     color: CGColor(gray: 1, alpha: 1), alpha: 1)
        guard let img = mc.makeImage() else { return nil }
        let bytes = mc.bytesPerRow * ph
        if masks.count >= 512 || maskBytes + bytes > maxMaskBytes { masks.removeAll(); maskBytes = 0 }
        let m = Mask(image: img, origin: origin, size: CGSize(width: CGFloat(pw) / scale, height: CGFloat(ph) / scale), bytes: bytes)
        masks[mk] = m
        maskBytes += bytes
        return m
    }

    private static func build(_ s: String, tracking: CGFloat) -> Entry {
        let unit: CGFloat = 1.0 / capUnits
        let gap = tracking * capUnits          // tracking in grid units
        let path = CGMutablePath()
        var pen: CGFloat = 0
        var first = true
        for ch in s.uppercased() {
            if !first { pen += gap }
            first = false
            let g = glyphs[ch] ?? fallback
            for stroke in g.strokes where !stroke.isEmpty {
                path.move(to: CGPoint(x: (stroke[0].x + pen) * unit, y: stroke[0].y * unit))
                if stroke.count == 1 {
                    path.addLine(to: CGPoint(x: (stroke[0].x + pen) * unit + 0.0001, y: stroke[0].y * unit))
                }
                for p in stroke.dropFirst() {
                    path.addLine(to: CGPoint(x: (p.x + pen) * unit, y: p.y * unit))
                }
            }
            pen += g.advance
        }
        return Entry(path: path.copy() ?? path, width: pen * unit)
    }

    // MARK: - Glyph data

    private static let capUnits: CGFloat = 6

    private struct Glyph { let strokes: [[CGPoint]]; let advance: CGFloat }

    /// Normalizes a glyph so its left edge is x = 0; advance = ink width (or `adv` if given).
    private static func g(_ strokes: [[CGPoint]], adv: CGFloat? = nil) -> Glyph {
        let xs = strokes.flatMap { $0.map(\.x) }
        guard let minX = xs.min(), let maxX = xs.max() else { return Glyph(strokes: [], advance: adv ?? 3) }
        let shifted = strokes.map { $0.map { CGPoint(x: $0.x - minX, y: $0.y) } }
        return Glyph(strokes: shifted, advance: adv ?? (maxX - minX))
    }

    private static let fallback = g([L(0, 0, 3, 0, 3, 4, 0, 4, 0, 0)])

    private static let glyphs: [Character: Glyph] = {
        var m: [Character: Glyph] = [:]
        func put(_ c: Character, _ strokes: [[CGPoint]], adv: CGFloat? = nil) { m[c] = g(strokes, adv: adv) }

        // Round-letter geometry: half-ellipse ends, rx = half width, ry = 2.2.
        let ry: CGFloat = 2.2
        let oTop = 6 - ry
        let oval = S(arc(2, oTop, 2, ry, 0, 180), arc(2, ry, 2, ry, 180, 360), [P(4, oTop)])

        put("A", [L(0, 0, 2.1, 6, 4.2, 0), L(0.7, 2, 3.5, 2)])
        put("B", [S(L(0, 3.15, 2.3, 3.15), arc(2.3, 4.575, 1.425, 1.425, -90, 90),
                    L(0, 6, 0, 0, 2.4, 0), arc(2.4, 1.575, 1.6, 1.575, -90, 90), L(2.3, 3.15))])
        put("C", [S(arc(2, oTop, 2, ry, 38, 180), arc(2, ry, 2, ry, 180, 322))])
        put("D", [S(L(0, 0, 0, 6, 1.9, 6), arc(1.9, oTop, 2.1, ry, 90, 0),
                    arc(1.9, ry, 2.1, ry, 0, -90), L(0, 0))])
        put("E", [L(3.7, 6, 0, 6, 0, 0, 3.7, 0), L(0, 3.15, 2.8, 3.15)])
        put("F", [L(3.7, 6, 0, 6, 0, 0), L(0, 3.15, 2.8, 3.15)])
        put("G", [S(arc(2, oTop, 2, ry, 38, 180), arc(2, ry, 2, ry, 180, 360), L(4, 2.7, 2.3, 2.7))])
        put("H", [L(0, 0, 0, 6), L(4, 0, 4, 6), L(0, 3.15, 4, 3.15)])
        put("I", [L(0, 0, 0, 6)])
        put("J", [S(L(3.4, 6), arc(1.7, 1.9, 1.7, 1.9, 0, -180), L(0, 2.3))])
        put("K", [L(0, 0, 0, 6), L(4, 6, 0, 2.1), L(1.45, 3.48, 4, 0)])
        put("L", [L(0, 6, 0, 0, 3.6, 0)])
        put("M", [L(0, 0, 0, 6, 2.4, 0.9, 4.8, 6, 4.8, 0)])
        put("N", [L(0, 0, 0, 6, 4, 0, 4, 6)])
        put("O", [oval])
        put("P", [S(L(0, 0, 0, 6, 2.4, 6), arc(2.4, 4.4, 1.6, 1.6, 90, -90), L(0, 2.8))])
        put("Q", [oval, L(2.5, 1.3, 4.2, -0.4)])
        put("R", [S(L(0, 0, 0, 6, 2.4, 6), arc(2.4, 4.4, 1.6, 1.6, 90, -90), L(0, 2.8)), L(2.2, 2.8, 4, 0)])
        put("S", [S(arc(2, 4.52, 1.85, 1.48, 28, 270), arc(2, 1.52, 2, 1.52, 90, -148))])
        put("T", [L(0, 6, 4.2, 6), L(2.1, 6, 2.1, 0)])
        put("U", [S(L(0, 6), arc(2, ry, 2, ry, 180, 360), L(4, 6))])
        put("V", [L(0, 6, 2.1, 0, 4.2, 6)])
        put("W", [L(0, 6, 1.3, 0, 2.6, 4.8, 3.9, 0, 5.2, 6)])
        put("X", [L(0, 0, 4, 6), L(0, 6, 4, 0)])
        put("Y", [L(0, 6, 2.1, 3, 4.2, 6), L(2.1, 3, 2.1, 0)])
        put("Z", [L(0, 6, 4, 6, 0, 0, 4, 0)])

        // Digits
        put("0", [S(arc(1.8, oTop, 1.8, ry, 0, 180), arc(1.8, ry, 1.8, ry, 180, 360), [P(3.6, oTop)])])
        put("1", [L(0, 4.7, 1.4, 6, 1.4, 0)])
        put("2", [S(arc(1.9, 4.2, 1.9, 1.8, 162, -32), L(0, 0, 4, 0))])
        put("3", [S(arc(1.95, 4.55, 1.8, 1.45, 152, -90), arc(1.95, 1.55, 2.0, 1.55, 90, -152)),
                  L(1.2, 3.1, 1.95, 3.1)])
        put("4", [L(3, 0, 3, 6, 0, 1.7, 4.1, 1.7)])
        put("5", [S(L(3.7, 6, 0.55, 6, 0.4, 3.3), arc(2, 2.0, 2, 2.0, 138, -145))])
        let six = [S(arc(2, 4.0, 2, 2.0, 52, 180), arc(2, 1.85, 2, 1.85, 180, 540))]
        put("6", six)
        put("7", [L(0, 6, 4, 6, 1.3, 0)])
        put("8", [ell(2, 4.6, 1.72, 1.4), ell(2, 1.6, 2, 1.6)])
        put("9", xf(six) { CGPoint(x: 4 - $0.x, y: 6 - $0.y) })

        // Punctuation
        let dotR: CGFloat = 0.28
        func dot(_ x: CGFloat, _ y: CGFloat) -> [CGPoint] { ell(x, y, dotR, dotR, steps: 12) }
        m[" "] = Glyph(strokes: [], advance: 3.2)
        put(".", [dot(0.3, 0.3)])
        put(",", [dot(0.5, 0.3), L(0.78, 0.3, 0, -1.1)])
        put(":", [dot(0.3, 0.3), dot(0.3, 3.6)])
        put(";", [dot(0.5, 3.6), dot(0.5, 0.3), L(0.78, 0.3, 0, -1.1)])
        put("-", [L(0, 3, 3, 3)])
        put("+", [L(0, 3, 4, 3), L(2, 1, 2, 5)])
        put("=", [L(0, 2.2, 4, 2.2), L(0, 3.8, 4, 3.8)])
        put("/", [L(0, -0.3, 3.4, 6.3)])
        put("_", [L(0, -0.9, 4, -0.9)])
        put("?", [S(arc(1.9, 4.4, 1.9, 1.6, 160, -90), L(1.9, 1.7)), dot(1.9, 0.3)])
        put("!", [L(0.3, 6, 0.3, 1.8), dot(0.3, 0.3)])
        put("'", [L(0, 6, 0, 4.3)])
        put("\"", [L(0, 6, 0, 4.3), L(1.2, 6, 1.2, 4.3)])
        let lp = [arc(2.6, 3, 2.2, 3.7, 126, 234)]
        put("(", lp)
        put(")", xf(lp) { CGPoint(x: -$0.x, y: $0.y) })
        put("[", [L(1.4, 6.4, 0, 6.4, 0, -0.4, 1.4, -0.4)])
        put("]", [L(0, 6.4, 1.4, 6.4, 1.4, -0.4, 0, -0.4)])
        put("|", [L(0, -0.4, 0, 6.4)])
        put("#", [L(1.3, 0.6, 1.3, 5.4), L(2.9, 0.6, 2.9, 5.4), L(0, 2.2, 4.2, 2.2), L(0, 3.8, 4.2, 3.8)])
        let sx: CGFloat = 1.6 * 0.866, sy: CGFloat = 1.6 * 0.5
        put("*", [L(2, 1.4, 2, 4.6), L(2 - sx, 3 - sy, 2 + sx, 3 + sy), L(2 - sx, 3 + sy, 2 + sx, 3 - sy)])
        put(">", [L(0, 1, 3.6, 3, 0, 5)])
        put("<", [L(3.6, 1, 0, 3, 3.6, 5)])
        put("%", [L(0.2, 0, 4.2, 6), ell(0.95, 4.9, 0.95, 1.1), ell(3.45, 1.1, 0.95, 1.1)])
        put("&", [S(L(4.3, 0), arc(2.0, 4.85, 1.15, 1.15, 219, -55),
                    arc(1.75, 1.45, 1.6, 1.45, 142, 330), L(3.9, 2.5))])
        put("@", [ell(2.4, 3, 1.0, 1.1),
                  S(L(3.4, 4.1), arc(4.168, 2.353, 0.768, 0.768, 180, 320),
                    arc(2.4, 3, 2.6, 2.7, -25, 295))])
        put("$", [S(arc(2, 4.52, 1.85, 1.48, 28, 270), arc(2, 1.52, 2, 1.52, 90, -148)), L(2, -0.6, 2, 6.6)])
        put("^", [L(0, 4, 1.6, 6, 3.2, 4)])
        return m
    }()

    // MARK: - Builders

    private static func P(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x, y: y) }

    /// Polyline from a flat list of x, y coordinates.
    private static func L(_ c: CGFloat...) -> [CGPoint] {
        var pts: [CGPoint] = []
        pts.reserveCapacity(c.count / 2)
        var i = 0
        while i + 1 < c.count { pts.append(CGPoint(x: c[i], y: c[i + 1])); i += 2 }
        return pts
    }

    /// Joins polyline pieces into one stroke.
    private static func S(_ parts: [CGPoint]...) -> [CGPoint] { parts.flatMap { $0 } }

    /// Elliptical arc from angle a0 to a1 (degrees, CCW positive; a1 < a0 runs clockwise).
    private static func arc(_ cx: CGFloat, _ cy: CGFloat, _ rx: CGFloat, _ ry: CGFloat,
                            _ a0: CGFloat, _ a1: CGFloat, steps: Int? = nil) -> [CGPoint] {
        let n = steps ?? max(2, Int((abs(a1 - a0) / 9).rounded(.up)))
        return (0...n).map { i in
            let a = (a0 + (a1 - a0) * CGFloat(i) / CGFloat(n)) * .pi / 180
            return CGPoint(x: cx + rx * cos(a), y: cy + ry * sin(a))
        }
    }

    private static func ell(_ cx: CGFloat, _ cy: CGFloat, _ rx: CGFloat, _ ry: CGFloat, steps: Int? = nil) -> [CGPoint] {
        arc(cx, cy, rx, ry, 90, 450, steps: steps)
    }

    private static func xf(_ strokes: [[CGPoint]], _ f: (CGPoint) -> CGPoint) -> [[CGPoint]] {
        strokes.map { $0.map(f) }
    }
}
