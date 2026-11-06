import AppKit
import CoreGraphics
import CoreText

// MARK: - Shared rendering contract
//
// Every scene is a deterministic function of (seed, local time). The Director
// owns the timeline and hands each scene its local time `t` in [0, duration).
// All drawing uses CoreGraphics' native bottom-left origin. Use `rc.top(y)` to
// convert a top-down y (in points) into CG coordinates.

struct RenderContext {
    let ctx: CGContext
    let size: CGSize          // view size in points
    /// Layout unit: 1/1000 of the shorter of (height, width*9/16). Size everything with `u`
    /// so the saver looks identical in the tiny System Settings preview and on a 5K display.
    var u: CGFloat { min(size.height, size.width * 9.0 / 16.0) / 1000.0 }
    func top(_ y: CGFloat) -> CGFloat { size.height - y }
}

protocol WOPRScene: AnyObject {
    /// Total length of this scene in seconds.
    var duration: Double { get }
    /// Draw the frame at local time t (0 <= t < duration). The background is already
    /// cleared to Theme.background before this is called.
    func draw(_ rc: RenderContext, t: Double)
}

// MARK: - Theme

enum Theme {
    static let background = CGColor(red: 0.0, green: 0.0, blue: 0.015, alpha: 1)
    /// Continent outlines.
    static let map = CGColor(red: 0.25, green: 0.55, blue: 1.0, alpha: 1)
    static let mapGrid = CGColor(red: 0.12, green: 0.25, blue: 0.55, alpha: 0.35)
    /// US / NATO launches.
    static let usa = CGColor(red: 0.45, green: 0.85, blue: 1.0, alpha: 1)
    /// USSR / Warsaw Pact launches.
    static let ussr = CGColor(red: 1.0, green: 0.25, blue: 0.2, alpha: 1)
    /// Neutral bright text on the big board.
    static let text = CGColor(red: 0.85, green: 0.95, blue: 1.0, alpha: 1)
    static let amber = CGColor(red: 1.0, green: 0.72, blue: 0.2, alpha: 1)
    /// WOPR terminal phosphor.
    static let terminal = CGColor(red: 0.35, green: 0.85, blue: 1.0, alpha: 1)
    static let impact = CGColor(red: 1.0, green: 0.95, blue: 0.8, alpha: 1)

    // Film big-board palette (sampled from the NORAD screens in the reference clip).
    /// Screen interior: very dark navy.
    static let screen = CGColor(red: 0.015, green: 0.03, blue: 0.08, alpha: 1)
    static let grid = CGColor(red: 0.10, green: 0.17, blue: 0.38, alpha: 0.30)
    /// Non-aligned coastlines.
    static let teal = CGColor(red: 0.22, green: 0.78, blue: 0.62, alpha: 1)
    static let usBlue = CGColor(red: 0.30, green: 0.58, blue: 1.0, alpha: 1)
    static let ussrRed = CGColor(red: 1.0, green: 0.20, blue: 0.27, alpha: 1)
    /// Missile streaks and detonations (same for every side, as in the film).
    static let missile = CGColor(red: 0.48, green: 0.70, blue: 1.0, alpha: 1)
    static let blob = CGColor(red: 0.86, green: 0.92, blue: 1.0, alpha: 1)
    /// Bright white bezel around each rear-projection screen.
    static let frame = CGColor(red: 0.92, green: 0.95, blue: 1.0, alpha: 1)
    /// Big-board lettering ("U.S. FIRST STRIKE", "WINNER: NONE").
    static let title = CGColor(red: 0.45, green: 0.65, blue: 1.0, alpha: 1)
    static let tableText = CGColor(red: 0.62, green: 0.88, blue: 1.0, alpha: 1)

    static func with(_ c: CGColor, alpha: CGFloat) -> CGColor { c.copy(alpha: alpha) ?? c }
}

// MARK: - Drawing helpers

enum Draw {
    /// Stroke `path` with a cheap two-pass glow (wide translucent + thin bright core).
    static func glowStroke(_ ctx: CGContext, _ path: CGPath, color: CGColor, width: CGFloat, glow: CGFloat = 3.0, alpha: CGFloat = 1) {
        ctx.saveGState()
        ctx.setLineCap(.round)
        ctx.setLineJoin(.round)
        ctx.addPath(path)
        ctx.setStrokeColor(Theme.with(color, alpha: 0.18 * alpha))
        ctx.setLineWidth(width * glow * 2)
        ctx.strokePath()
        ctx.addPath(path)
        ctx.setStrokeColor(Theme.with(color, alpha: 0.35 * alpha))
        ctx.setLineWidth(width * glow)
        ctx.strokePath()
        ctx.addPath(path)
        ctx.setStrokeColor(Theme.with(color, alpha: alpha))
        ctx.setLineWidth(width)
        ctx.strokePath()
        ctx.restoreGState()
    }

    static func glowDot(_ ctx: CGContext, _ p: CGPoint, r: CGFloat, color: CGColor, alpha: CGFloat = 1) {
        ctx.saveGState()
        ctx.setFillColor(Theme.with(color, alpha: 0.15 * alpha))
        ctx.fillEllipse(in: CGRect(x: p.x - r * 3, y: p.y - r * 3, width: r * 6, height: r * 6))
        ctx.setFillColor(Theme.with(color, alpha: 0.35 * alpha))
        ctx.fillEllipse(in: CGRect(x: p.x - r * 1.8, y: p.y - r * 1.8, width: r * 3.6, height: r * 3.6))
        ctx.setFillColor(Theme.with(color, alpha: alpha))
        ctx.fillEllipse(in: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2))
        ctx.restoreGState()
    }

    enum Align { case left, center, right }

    private static var fontCache: [CGFloat: CTFont] = [:]
    static func font(_ size: CGFloat) -> CTFont {
        let key = (size * 4).rounded() / 4
        if let f = fontCache[key] { return f }
        let f = CTFontCreateWithName("Menlo-Bold" as CFString, key, nil)
        fontCache[key] = f
        return f
    }

    /// Draw a single line of monospaced text. `baselineY` is in CG coordinates.
    /// Returns the drawn width.
    @discardableResult
    static func text(_ ctx: CGContext, _ s: String, x: CGFloat, baselineY: CGFloat, size: CGFloat,
                     color: CGColor, align: Align = .left, glow: Bool = true, alpha: CGFloat = 1,
                     tracking: CGFloat = 0.08) -> CGFloat {
        let attrs: [NSAttributedString.Key: Any] = [
            NSAttributedString.Key(kCTFontAttributeName as String): font(size),
            NSAttributedString.Key(kCTForegroundColorAttributeName as String): Theme.with(color, alpha: alpha),
            NSAttributedString.Key(kCTKernAttributeName as String): size * tracking,
        ]
        let line = CTLineCreateWithAttributedString(NSAttributedString(string: s, attributes: attrs))
        let w = CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil))
        var ox = x
        switch align {
        case .left: break
        case .center: ox -= w / 2
        case .right: ox -= w
        }
        ctx.saveGState()
        ctx.textMatrix = .identity
        if glow {
            ctx.setShadow(offset: .zero, blur: size * 0.45, color: Theme.with(color, alpha: 0.9 * alpha))
        }
        ctx.textPosition = CGPoint(x: ox, y: baselineY)
        CTLineDraw(line, ctx)
        ctx.restoreGState()
        return w
    }

    static func textWidth(_ s: String, size: CGFloat, tracking: CGFloat = 0.08) -> CGFloat {
        let attrs: [NSAttributedString.Key: Any] = [
            NSAttributedString.Key(kCTFontAttributeName as String): font(size),
            NSAttributedString.Key(kCTKernAttributeName as String): size * tracking,
        ]
        let line = CTLineCreateWithAttributedString(NSAttributedString(string: s, attributes: attrs))
        return CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil))
    }
}

// MARK: - Deterministic RNG

struct SplitMix64: RandomNumberGenerator {
    var state: UInt64
    init(seed: UInt64) { state = seed &+ 0x9E3779B97F4A7C15 }
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
    mutating func unit() -> Double { Double(next() >> 11) / Double(1 << 53) }
    mutating func range(_ a: Double, _ b: Double) -> Double { a + (b - a) * unit() }
}

/// Cheap hash for per-frame flicker that stays deterministic in t.
func hash01(_ a: Int, _ b: Int = 0) -> Double {
    var r = SplitMix64(seed: UInt64(bitPattern: Int64(a &* 73856093 ^ b &* 19349663)))
    return r.unit()
}
