import CoreGraphics
import Foundation

/// One line of terminal output. `at` = time typing starts (scene-local seconds),
/// `cps` = characters per second. Empty text = blank line.
struct TerminalLine {
    let text: String
    let at: Double
    let cps: Double
    let fromUser: Bool
}

extension TerminalLine {
    /// WOPR output: fast, even teletype rate.
    static func wopr(_ text: String, at: Double, cps: Double = 28) -> TerminalLine {
        TerminalLine(text: text, at: at, cps: cps, fromUser: false)
    }
    /// Human typing: slower, with deterministic irregular keystroke timing.
    static func user(_ text: String, at: Double, cps: Double = 9) -> TerminalLine {
        TerminalLine(text: text, at: at, cps: cps, fromUser: true)
    }
}

/// 80s phosphor teletype: uppercase text typed out with a block cursor, glow and scanlines.
final class TerminalScene: WOPRScene {
    let duration: Double
    private let textScale: CGFloat

    private struct Prepared {
        let chars: [Character]
        let at: Double
        let charTimes: [Double]   // offset from `at` at which char i appears
        var typeEnd: Double { at + (charTimes.last ?? 0) }
    }
    private let lines: [Prepared]

    init(lines input: [TerminalLine], duration: Double, textScale: CGFloat = 1) {
        self.duration = duration
        self.textScale = textScale
        let sorted = input.enumerated().sorted { ($0.element.at, $0.offset) < ($1.element.at, $1.offset) }
        lines = sorted.map { (idx, l) in
            let chars = Array(l.text.uppercased())
            var times: [Double] = []
            var acc = 0.0
            let base = 1.0 / max(l.cps, 0.1)
            for (i, ch) in chars.enumerated() {
                if i > 0 {
                    if l.fromUser {
                        let h = hash01(idx &* 7919 &+ 17, i)
                        var dt = base * (0.45 + 1.1 * h)
                        if ch == " " { dt *= 1.35 }
                        if hash01(idx &* 104729 &+ 3, i) > 0.9 { dt += base * 2.2 }   // hesitation
                        acc += dt
                    } else {
                        acc += base
                    }
                }
                times.append(acc)
            }
            return Prepared(chars: chars, at: l.at, charTimes: times)
        }
    }

    func draw(_ rc: RenderContext, t: Double) {
        let ctx = rc.ctx, u = rc.u, W = rc.size.width, H = rc.size.height
        let fs = 34 * u * textScale
        let lineH = fs * 1.6
        let marginX = max(110 * u, (W - 1778 * u) / 2 + 110 * u)
        let marginTop = 100 * u, marginBottom = 90 * u
        let rowsCap = max(1, Int((H - marginTop - marginBottom - fs) / lineH) + 1)
        let firstBaseline = rc.top(marginTop + fs * 0.8)

        // Smooth scroll: each line beyond capacity pushes the page up one row over ~0.12 s.
        var scroll: CGFloat = 0
        var lastStarted = -1
        for (i, l) in lines.enumerated() where l.at <= t {
            lastStarted = i
            if i >= rowsCap {
                let x = CGFloat(min(1, (t - l.at) / 0.12))
                scroll += x * x * (3 - 2 * x)
            }
        }

        // Subtle phosphor flicker.
        let flick = CGFloat(0.93 + 0.07 * hash01(Int(t * 30), 991))
        let color = Theme.terminal

        var cursorX = marginX
        var cursorRow: CGFloat = 0
        var typing = false
        var idleSince = 0.0
        for (i, l) in lines.enumerated() where i <= lastStarted {
            let row = CGFloat(i) - scroll
            if row < -1 || row > CGFloat(rowsCap) { continue }
            let el = t - l.at
            var n = 0
            while n < l.charTimes.count && l.charTimes[n] <= el { n += 1 }
            let y = firstBaseline - row * lineH
            var w: CGFloat = 0
            if n > 0 {
                w = Draw.text(ctx, String(l.chars[0..<n]), x: marginX, baselineY: y, size: fs,
                              color: color, alpha: flick)
            }
            if i == lastStarted {
                cursorX = marginX + w
                cursorRow = row
                typing = n < l.chars.count
                idleSince = l.typeEnd
            }
        }

        // Block cursor: solid while typing, blinking when idle.
        let on = typing || lastStarted < 0 || (t - idleSince).truncatingRemainder(dividingBy: 1.0) < 0.55
        if on {
            let cw = Draw.textWidth("M", size: fs) * 0.92
            let y = firstBaseline - cursorRow * lineH
            let r = CGRect(x: cursorX + fs * 0.04, y: y - fs * 0.2, width: cw, height: fs * 0.98)
            ctx.setFillColor(Theme.with(color, alpha: 0.18 * flick))
            ctx.fill(r.insetBy(dx: -fs * 0.18, dy: -fs * 0.18))
            ctx.setFillColor(Theme.with(color, alpha: 0.35 * flick))
            ctx.fill(r.insetBy(dx: -fs * 0.07, dy: -fs * 0.07))
            ctx.setFillColor(Theme.with(color, alpha: 0.95 * flick))
            ctx.fill(r)
        }

        // Faint scanlines.
        let pitch = max(4 * u, 2)
        var rects: [CGRect] = []
        rects.reserveCapacity(Int(H / pitch) + 1)
        var sy: CGFloat = 0
        while sy < H { rects.append(CGRect(x: 0, y: sy, width: W, height: pitch * 0.45)); sy += pitch }
        ctx.setFillColor(Theme.with(Theme.background, alpha: 0.32))
        ctx.fill(rects)
    }

    // MARK: Factories

    /// ~12 s: the greeting, the fateful choice, the launch sequence armed.
    static func intro() -> TerminalScene {
        TerminalScene(lines: [
            .wopr("GREETINGS PROFESSOR FALKEN.", at: 0.5),
            .wopr("", at: 1.6),
            .wopr("SHALL WE PLAY A GAME?", at: 1.8),
            .wopr("", at: 2.7),
            .user("GLOBAL THERMONUCLEAR WAR", at: 3.4),
            .wopr("", at: 6.3),
            .wopr("WHICH SIDE DO YOU WANT?", at: 6.5),
            .wopr("", at: 7.4),
            .wopr("  1.  UNITED STATES", at: 7.5),
            .wopr("  2.  SOVIET UNION", at: 8.25),
            .wopr("", at: 8.95),
            .user("2", at: 9.6),
            .wopr("", at: 9.9),
            .wopr("INITIATING SIMULATION...", at: 10.0),
            .wopr("LAUNCH SEQUENCE ARMED.", at: 11.0),
        ], duration: 12.6)
    }

    /// ~18 s: after the war games, the lesson learned.
    static func ending() -> TerminalScene {
        TerminalScene(lines: [
            .wopr("GREETINGS PROFESSOR FALKEN.", at: 0.6),
            .wopr("", at: 1.7),
            .user("HELLO, JOSHUA.", at: 2.8, cps: 7.5),
            .wopr("", at: 5.2),
            .wopr("A STRANGE GAME.", at: 5.6, cps: 22),
            .wopr("THE ONLY WINNING MOVE IS", at: 7.6, cps: 22),
            .wopr("NOT TO PLAY.", at: 9.6, cps: 18),
            .wopr("", at: 10.6),
            .wopr("HOW ABOUT A NICE GAME OF CHESS?", at: 12.6, cps: 24),
        ], duration: 18, textScale: 1.2)
    }
}
