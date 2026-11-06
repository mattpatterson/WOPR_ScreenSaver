import Foundation
import CoreGraphics

/// Full-screen bezel used by the text-only big-board screens.
private func boardScreen(_ rc: RenderContext) -> CGRect {
    let u = rc.u
    let h = rc.size.height - 52 * u
    let w = min(rc.size.width - 52 * u, h * 1.45)
    return CGRect(x: rc.size.width / 2 - w / 2, y: 26 * u, width: w, height: h)
}

private func drawBoardBackground(_ rc: RenderContext, key: String) {
    Director.provideStatic(rc, key: key) { src in
        let s = boardScreen(src)
        src.ctx.setFillColor(Theme.screen)
        src.ctx.fill(s)
        BoardArt.drawGrid(src.ctx, s, step: 34 * src.u, u: src.u)
        BoardArt.drawBezel(src.ctx, s, u: src.u)
        BoardArt.drawNeighborBezels(src, around: s)
    }
}

/// The scoreboard the WOPR shows between scenarios:
///   STRATEGY:                 WINNER:
///   USSR FIRST STRIKE           NONE
final class StrategyTableScene: WOPRScene {
    let duration: Double
    let rows: [String]
    /// Rows already on the board when the scene starts; the rest type in one by one.
    let preShown: Int

    init(rows: [String], duration: Double, preShown: Int = 0) {
        self.rows = rows
        self.duration = duration
        self.preShown = min(preShown, rows.count)
    }

    func draw(_ rc: RenderContext, t: Double) {
        drawBoardBackground(rc, key: "table")
        let s = boardScreen(rc)
        let u = rc.u
        let size = 30 * u
        let lineH = size * 2.0
        let left = s.minX + 70 * u, right = s.maxX - 70 * u
        var y = s.maxY - 80 * u
        VectorFont.draw(rc.ctx, "STRATEGY:", x: left, baselineY: y, size: size, color: Theme.tableText, tracking: 0.25)
        VectorFont.draw(rc.ctx, "WINNER:", x: right, baselineY: y, size: size, color: Theme.tableText, align: .right, tracking: 0.25)
        y -= lineH * 1.1
        let maxRows = max(1, Int((y - s.minY - 40 * u) / lineH) + 1)
        let typing = rows.count - preShown
        let per = typing > 0 ? (duration * 0.8) / Double(typing) : 1
        let visible = preShown + min(typing, Int(t / per) + 1)
        let first = max(0, visible - maxRows)
        for i in first..<visible {
            VectorFont.draw(rc.ctx, rows[i], x: left, baselineY: y, size: size, color: Theme.tableText, tracking: 0.25)
            // "NONE" lands a beat after the strategy name.
            let shownAt = i < preShown ? -1 : Double(i - preShown) * per
            if t - shownAt > min(0.35, per * 0.5) || i < visible - 1 {
                VectorFont.draw(rc.ctx, "NONE", x: right, baselineY: y, size: size, color: Theme.tableText, align: .right, tracking: 0.25)
            }
            y -= lineH
        }
    }
}

/// WOPR brute-forcing the launch code: ten slots of spinning characters that lock one at a time.
final class LaunchCodeScene: WOPRScene {
    let duration: Double
    let code = Array("CPE1704TKS")
    private let lockAt: [Double]
    private static let alphabet = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789")

    init(duration: Double = 10, seed: UInt64 = 7) {
        self.duration = duration
        var rng = SplitMix64(seed: seed)
        // Lock order is scrambled, like the film; timing accelerates.
        let order = Array(0..<10).sorted { _, _ in rng.next() & 1 == 0 }
        var at = [Double](repeating: 0, count: 10)
        for (k, slot) in order.enumerated() {
            at[slot] = duration * (0.12 + 0.72 * pow(Double(k + 1) / 10, 0.85))
        }
        lockAt = at
    }

    func draw(_ rc: RenderContext, t: Double) {
        drawBoardBackground(rc, key: "code")
        let s = boardScreen(rc)
        let u = rc.u
        let size = 96 * u
        let slotW = VectorFont.width("W", size: size, tracking: 0) + 22 * u
        let x0 = s.midX - slotW * 5
        let base = s.midY - size / 2
        VectorFont.draw(rc.ctx, "LAUNCH CODE", x: s.midX, baselineY: s.maxY - 110 * u, size: 30 * u, color: Theme.title, align: .center)
        let frame = Int(t * 24)
        var locked = 0
        for i in 0..<10 {
            let isLocked = t >= lockAt[i]
            if isLocked { locked += 1 }
            let ch: Character = isLocked ? code[i] : LaunchCodeScene.alphabet[Int(hash01(frame, i * 31) * 36) % 36]
            let color = isLocked ? Theme.frame : Theme.with(Theme.title, alpha: 0.8)
            VectorFont.draw(rc.ctx, String(ch), x: x0 + slotW * (CGFloat(i) + 0.5), baselineY: base, size: size, color: color,
                            align: .center, tracking: 0)
        }
        let status = locked == 10 ? "CODE LOCKED" : String(format: "SEARCHING   %02d / 10", locked)
        if locked < 10 || Int(t * 3) % 2 == 0 {
            VectorFont.draw(rc.ctx, status, x: s.midX, baselineY: s.minY + 110 * u, size: 26 * u, color: Theme.title, align: .center)
        }
    }
}
