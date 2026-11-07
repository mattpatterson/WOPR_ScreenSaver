import CoreGraphics
import Foundation

// MARK: - Perfect-play tic-tac-toe solver (shared, built once)

/// Board cells: 0 empty, 1 = X, 2 = O. Cell index = row*3 + col, row 0 at the top.
final class TTTSolver {
    static let shared = TTTSolver()
    static let lines: [(Int, Int, Int)] = [(0,1,2),(3,4,5),(6,7,8),(0,3,6),(1,4,7),(2,5,8),(0,4,8),(2,4,6)]

    private var memo: [Int: Int8] = [:]

    static func winner(_ b: [Int8]) -> Int8 {
        for (a, c, d) in lines where b[a] != 0 && b[a] == b[c] && b[a] == b[d] { return b[a] }
        return 0
    }

    private static func code(_ b: [Int8]) -> Int {
        var k = 0
        for v in b { k = k * 3 + Int(v) }
        return k
    }

    /// Game value for the player `p` who is about to move: +1 win, 0 draw, -1 loss.
    private func value(_ b: inout [Int8], _ p: Int8) -> Int8 {
        if TTTSolver.winner(b) != 0 { return -1 }      // previous mover just won
        if !b.contains(0) { return 0 }
        let key = TTTSolver.code(b)                     // side to move is implied by piece count
        if let v = memo[key] { return v }
        var best: Int8 = -2
        for i in 0..<9 where b[i] == 0 {
            b[i] = p
            let v = -value(&b, 3 - p)
            b[i] = 0
            if v > best { best = v; if best == 1 { break } }
        }
        memo[key] = best
        return best
    }

    /// All moves that achieve the minimax value for `p`.
    func bestMoves(_ board: [Int8], _ p: Int8) -> [Int] {
        var b = board
        var best: Int8 = -2
        var moves: [Int] = []
        for i in 0..<9 where b[i] == 0 {
            b[i] = p
            let v = -value(&b, 3 - p)
            b[i] = 0
            if v > best { best = v; moves = [i] } else if v == best { moves.append(i) }
        }
        return moves
    }
}

// MARK: - Scene

/// WOPR plays tic-tac-toe against itself: one slow game, faster games, then an
/// accelerating wall of simultaneous boards, every one ending in a draw.
final class TicTacToeScene: WOPRScene {
    let duration: Double
    /// Precomputed perfect-play games: 9 cell indices each, X moves on even plies.
    let games: [[Int]]

    private struct Single { let start: Double; let step: Double; let end: Double; let game: Int }
    private struct Grid { let start: Double; let end: Double; let rows: Int; let cols: Int; let step: Double; let hold: Double }

    private let singles: [Single]
    private let grids: [Grid]
    private let finalStart: Double
    private let seedSalt: Int

    init(duration: Double = 14, seed: UInt64) {
        self.duration = duration
        var rng = SplitMix64(seed: seed)
        let solver = TTTSolver.shared
        var gs: [[Int]] = []
        for _ in 0..<96 {
            var b = [Int8](repeating: 0, count: 9)
            var p: Int8 = 1
            var moves: [Int] = []
            while TTTSolver.winner(b) == 0 && b.contains(0) {
                let opts = solver.bestMoves(b, p)
                let m = opts[Int(rng.next() % UInt64(opts.count))]
                b[m] = p; moves.append(m); p = 3 - p
            }
            gs.append(moves)
        }
        games = gs
        seedSalt = Int(truncatingIfNeeded: rng.next() & 0xFFFF)

        let s = duration / 14.0
        singles = [
            Single(start: 0.6 * s, step: 0.5 * s, end: 5.55 * s, game: 0),
            Single(start: 5.6 * s, step: 0.17 * s, end: 7.4 * s, game: 1),
            Single(start: 7.45 * s, step: 0.07 * s, end: 8.3 * s, game: 2),
        ]
        grids = [
            Grid(start: 8.3 * s, end: 9.4 * s, rows: 2, cols: 2, step: 0.06 * s, hold: 0.16 * s),
            Grid(start: 9.4 * s, end: 10.6 * s, rows: 3, cols: 3, step: 0.04 * s, hold: 0.10 * s),
            Grid(start: 10.6 * s, end: 13.0 * s, rows: 5, cols: 0, step: 0.018 * s, hold: 0.06 * s),
        ]
        finalStart = 13.0 * s
    }

    // MARK: Timeline math (pure functions of t)

    private struct Slot { let offset: Double; let step: Double; let period: Double }

    private func slot(_ phase: Int, _ k: Int) -> Slot {
        let g = grids[phase]
        let step = g.step * (0.8 + 0.4 * hash01(k &* 31 &+ seedSalt, phase &+ 7))
        let period = step * 8 + g.hold
        return Slot(offset: hash01(k &+ seedSalt, phase &* 13 &+ 1) * period, step: step, period: period)
    }

    private func gameIndex(_ phase: Int, _ k: Int, _ gi: Int) -> Int {
        Int(hash01(k &* 131 &+ phase &* 977 &+ seedSalt, gi) * Double(games.count)) % games.count
    }

    /// Games finished (last move placed) by local slot time x.
    private func completed(_ x: Double, _ sl: Slot) -> Int {
        let firstDone = 8 * sl.step
        return x < firstDone ? 0 : Int(((x - firstDone) / sl.period).rounded(.down)) + 1
    }

    private func gridCols(_ g: Grid, _ area: CGRect) -> Int {
        if g.cols > 0 { return g.cols }
        let cell = area.height / CGFloat(g.rows)
        return max(g.rows, Int(area.width / cell))
    }

    private func gamesPlayed(_ t: Double, _ area: CGRect) -> Int {
        var n = 0
        for sg in singles where t >= sg.start + 8 * sg.step { n += 1 }
        for (pi, g) in grids.enumerated() where t >= g.start {
            let count = g.rows * gridCols(g, area)
            let local = min(t, g.end) - g.start
            for k in 0..<count {
                let sl = slot(pi, k)
                n += completed(local + sl.offset, sl) - completed(sl.offset, sl)
            }
        }
        return n
    }

    // MARK: Geometry

    private final class Paths {
        let grid = CGMutablePath(), xs = CGMutablePath(), os = CGMutablePath()
    }

    /// Adds one board. `elapsed` is time since the game's first move; marks animate in over `drawDur`.
    private func addBoard(_ p: Paths, center c: CGPoint, size S: CGFloat, game: [Int],
                          elapsed: Double, step: Double, drawDur: Double, full: Bool) {
        let h = S / 2, third = S / 3, inset = S * 0.02
        for i in [-1.0, 1.0] as [CGFloat] {
            let o = i * S / 6
            p.grid.move(to: CGPoint(x: c.x + o, y: c.y - h + inset))
            p.grid.addLine(to: CGPoint(x: c.x + o, y: c.y + h - inset))
            p.grid.move(to: CGPoint(x: c.x - h + inset, y: c.y + o))
            p.grid.addLine(to: CGPoint(x: c.x + h - inset, y: c.y + o))
        }
        let r = third * 0.29
        for (j, cell) in game.enumerated() {
            var prog = 1.0
            if !full {
                let tm = Double(j) * step
                if elapsed < tm { break }
                prog = drawDur > 0 ? min(1, (elapsed - tm) / drawDur) : 1
            }
            let row = cell / 3, col = cell % 3
            let cc = CGPoint(x: c.x + CGFloat(col - 1) * third, y: c.y + CGFloat(1 - row) * third)
            if j % 2 == 0 {
                let a = CGFloat(min(1, prog * 2)), b = CGFloat(max(0, prog * 2 - 1))
                p.xs.move(to: CGPoint(x: cc.x - r, y: cc.y + r))
                p.xs.addLine(to: CGPoint(x: cc.x - r + 2 * r * a, y: cc.y + r - 2 * r * a))
                if b > 0 {
                    p.xs.move(to: CGPoint(x: cc.x + r, y: cc.y + r))
                    p.xs.addLine(to: CGPoint(x: cc.x + r - 2 * r * b, y: cc.y + r - 2 * r * b))
                }
            } else {
                p.os.move(to: CGPoint(x: cc.x, y: cc.y + r))
                p.os.addArc(center: cc, radius: r, startAngle: .pi / 2,
                            endAngle: .pi / 2 - 2 * .pi * CGFloat(prog), clockwise: true)
            }
        }
    }

    private func stroke(_ ctx: CGContext, _ p: Paths, size S: CGFloat, alpha: CGFloat, u: CGFloat, glow: CGFloat) {
        let gw = max(S * 0.011, 0.6), mw = max(S * 0.018, 0.8)
        if !p.grid.isEmpty { Draw.glowStroke(ctx, p.grid, color: Theme.frame, width: gw, glow: glow, alpha: 0.75 * alpha) }
        if !p.xs.isEmpty { Draw.glowStroke(ctx, p.xs, color: Theme.blob, width: mw, glow: glow, alpha: alpha) }
        if !p.os.isEmpty { Draw.glowStroke(ctx, p.os, color: Theme.blob, width: mw, glow: glow, alpha: alpha) }
    }

    // MARK: Draw

    func draw(_ rc: RenderContext, t: Double) {
        let ctx = rc.ctx, u = rc.u, W = rc.size.width, H = rc.size.height
        // White vector strokes on a solid black background (no static screen art, so the
        // black root layer shows through).
        let area = CGRect(x: 70 * u, y: 70 * u, width: W - 140 * u, height: H - 70 * u - 150 * u)

        // Header + counter
        let headY = rc.top(78 * u)
        let played = gamesPlayed(min(t, finalStart), area)
        VectorFont.draw(ctx, "GAME: TIC-TAC-TOE   PLAYERS: 0", x: 60 * u, baselineY: headY, size: 20 * u, color: Theme.title, tracking: 0.3)
        VectorFont.draw(ctx, "GAMES PLAYED: \(played)", x: W - 60 * u, baselineY: headY, size: 20 * u,
                        color: Theme.title, align: .right, tracking: 0.3)
        let rule = CGMutablePath()
        rule.move(to: CGPoint(x: 60 * u, y: headY - 24 * u))
        rule.addLine(to: CGPoint(x: W - 60 * u, y: headY - 24 * u))
        Draw.glowStroke(ctx, rule, color: Theme.title, width: max(2 * u, 0.5), glow: 1.5, alpha: 1)

        // Phase 1: single large board
        if t < grids[0].start {
            let sg = singles[singles.lastIndex(where: { t >= $0.start }) ?? 0]
            let S = min(area.height - 110 * u, 600 * u)
            let c = CGPoint(x: W / 2, y: area.maxY - S / 2 - 10 * u)
            let p = Paths()
            addBoard(p, center: c, size: S, game: games[sg.game], elapsed: t - sg.start,
                     step: sg.step, drawDur: min(0.28, sg.step * 0.7), full: false)
            stroke(ctx, p, size: S, alpha: 1, u: u, glow: 2.2)
            let doneAt = sg.start + 8 * sg.step + min(0.28, sg.step * 0.7)
            if t >= doneAt && t < sg.end {
                let on = Int((t - doneAt) * 7) % 2 == 0
                if on {
                    VectorFont.draw(ctx, "WINNER: NONE", x: W / 2, baselineY: c.y - S / 2 - 70 * u,
                                    size: 34 * u, color: Theme.title, align: .center)
                }
            }
            return
        }

        // Grid phases (and the frozen final grid)
        let isFinal = t >= finalStart
        let pi = isFinal ? grids.count - 1 : (grids.lastIndex(where: { t >= $0.start }) ?? 0)
        let g = grids[pi]
        let cols = gridCols(g, area), rows = g.rows
        let cw = area.width / CGFloat(cols), ch = area.height / CGFloat(rows)
        let S = min(cw, ch) * (rows <= 3 ? 0.72 : 0.78)
        let localT = (isFinal ? g.end : t) - g.start
        let frame = Int(t * 24)
        let buckets: [CGFloat] = [1.0, 0.65, 0.3]
        let paths = [Paths(), Paths(), Paths()]
        for k in 0..<(rows * cols) {
            let sl = slot(pi, k)
            let lt = localT + sl.offset
            let gi = Int((lt / sl.period).rounded(.down))
            let within = lt - Double(gi) * sl.period
            let row = k / cols, col = k % cols
            let c = CGPoint(x: area.minX + cw * (CGFloat(col) + 0.5), y: area.maxY - ch * (CGFloat(row) + 0.5))
            var b = 0
            if !isFinal {
                let f = hash01(k &* 7 &+ pi &+ seedSalt, frame)
                b = f < 0.10 ? 2 : (f < 0.24 ? 1 : 0)
            }
            addBoard(paths[b], center: c, size: S, game: games[gameIndex(pi, k, gi)], elapsed: within,
                     step: sl.step, drawDur: sl.step * 0.8, full: isFinal)
        }
        let dim: CGFloat = isFinal ? 0.4 : 1
        for (i, p) in paths.enumerated() {
            stroke(ctx, p, size: S, alpha: buckets[i] * dim, u: u, glow: rows <= 3 ? 2.2 : 2.0)
        }

        if isFinal {
            let tf = t - finalStart
            let a = CGFloat(min(1, tf / 0.12))
            let size = 80 * u
            let tw = VectorFont.width("WINNER: NONE", size: size)
            let box = CGRect(x: W / 2 - tw / 2 - 50 * u, y: H / 2 - size * 0.9, width: tw + 100 * u, height: size * 1.8)
            ctx.setFillColor(CGColor(gray: 0, alpha: a))
            ctx.fill(box)
            let border = CGPath(rect: box, transform: nil)
            Draw.glowStroke(ctx, border, color: Theme.frame, width: max(3 * u, 0.6), glow: 2, alpha: a)
            VectorFont.draw(ctx, "WINNER: NONE", x: W / 2, baselineY: H / 2 - size * 0.5, size: size,
                            color: Theme.title, align: .center, alpha: a)
        }
    }
}
