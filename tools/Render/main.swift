// Offscreen renderer for testing: renders frames of the loop to PNG and benchmarks.
//   render --out DIR --size 1920x1080 --times 10,20.5 [--scale 2]
//   render --bench --size 2560x1440 --scale 2 --frames 300 [--from 0 --to 300]
//   render --timeline         (prints the act timeline)
import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

var args = Array(CommandLine.arguments.dropFirst())
func opt(_ k: String) -> String? { if let i = args.firstIndex(of: k), i + 1 < args.count { return args[i + 1] }; return nil }
let sz = (opt("--size") ?? "1920x1080").split(separator: "x").compactMap { Double($0) }
let size = CGSize(width: sz[0], height: sz[1])
let scale = Double(opt("--scale") ?? "1") ?? 1
let director = Director()

func makeCtx() -> CGContext {
    let ctx = CGContext(data: nil, width: Int(size.width * scale), height: Int(size.height * scale), bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.scaleBy(x: scale, y: scale)
    return ctx
}

if args.contains("--timeline") {
    var last = ""
    for e in director.entries where e.name != last || e.name != "cycle" {
        print(String(format: "%7.2f  %5.2fs  %@", e.start, e.scene.duration, e.name + ((e.scene as? WarScene).map { "  " + $0.spec.title + "  missiles=\($0.missiles.count)" } ?? "")))
        last = e.name
    }
    print(String(format: "TOTAL %.1f s", director.total))
}

if let out = opt("--out"), let times = opt("--times") {
    try? FileManager.default.createDirectory(atPath: out, withIntermediateDirectories: true)
    for ts in times.split(separator: ",") {
        guard let t = Double(ts) else { continue }
        let ctx = makeCtx()
        director.draw(ctx: ctx, size: size, time: t)
        let img = ctx.makeImage()!
        let url = URL(fileURLWithPath: out).appendingPathComponent(String(format: "frame_%07.2f.png", t))
        let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(dest, img, nil)
        CGImageDestinationFinalize(dest)
        print(url.path)
    }
}

if args.contains("--bench") {
    let frames = Int(opt("--frames") ?? "300") ?? 300
    let from = Double(opt("--from") ?? "0") ?? 0
    let to = Double(opt("--to") ?? String(director.total)) ?? director.total
    let ctx = makeCtx()
    let live = args.contains("--live") ? LiveRenderer(director: director) : nil
    if let live { print("live mode: dynamic scale", live.dynamicScale(size: size, backing: CGFloat(scale))) }
    var worst = 0.0, worstT = 0.0, sum = 0.0
    var perAct: [String: (Double, Int)] = [:]
    for i in 0..<frames {
        let t = from + (to - from) * Double(i) / Double(frames)
        let s = DispatchTime.now().uptimeNanoseconds
        if let live { _ = live.render(size: size, backing: CGFloat(scale), time: t) } else { director.draw(ctx: ctx, size: size, time: t) }
        let ms = Double(DispatchTime.now().uptimeNanoseconds - s) / 1e6
        if i > 0 { sum += ms; if ms > worst { worst = ms; worstT = t } }
        let name = director.entry(at: t).0.name
        let v = perAct[name] ?? (0, 0); perAct[name] = (v.0 + ms, v.1 + 1)
    }
    print(String(format: "avg %.2f ms  worst %.2f ms at t=%.2f  (%dx%d @%.0fx)", sum / Double(frames - 1), worst, worstT, Int(size.width), Int(size.height), scale))
    for (k, v) in perAct.sorted(by: { $0.key < $1.key }) { print(String(format: "  %-10@ avg %.2f ms", k as NSString, v.0 / Double(v.1))) }
}
