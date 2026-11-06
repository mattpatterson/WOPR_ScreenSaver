// WOPR Preview: hosts the screen-saver view in a normal window.
//   Space  next act      F  toggle full screen      Q / Esc  quit
//   1-6    jump to intro / main / tic-tac-toe / cycle / ending / start
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    var view: WOPRSaverView!
    var timer: Timer?

    func applicationDidFinishLaunching(_ n: Notification) {
        let frame = NSRect(x: 0, y: 0, width: 1280, height: 720)
        window = NSWindow(contentRect: frame, styleMask: [.titled, .closable, .resizable, .miniaturizable], backing: .buffered, defer: false)
        window.title = "WOPR Screen Saver Preview"
        view = WOPRSaverView(frame: frame, isPreview: false)
        view.autoresizingMask = [.width, .height]
        window.contentView = view
        window.center()
        window.makeKeyAndOrderFront(nil)
        view.jump(to: view.loopTime)
        // Drive frames ourselves too (ScreenSaverView's timer only runs inside the saver engine on some macOS versions).
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in self?.view.renderFrame() }
        NSApp.activate(ignoringOtherApps: true)
        if CommandLine.arguments.contains("--fullscreen") { window.toggleFullScreen(nil) }
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] e in self?.key(e) == true ? nil : e }
    }

    func key(_ e: NSEvent) -> Bool {
        let d = view.directorRef
        switch e.charactersIgnoringModifiers ?? "" {
        case " ":
            let t = view.loopTime.truncatingRemainder(dividingBy: d.total)
            let next = d.entries.first { $0.start > t + 0.01 && $0.name != "black" && $0.name != "cycle" } ?? d.entries[0]
            view.jump(to: next.start)
        case "1": view.jump(to: d.startOf("intro"))
        case "2": view.jump(to: d.startOf("main"))
        case "3": view.jump(to: d.startOf("tictactoe"))
        case "4": view.jump(to: d.startOf("cycle"))
        case "5": view.jump(to: d.startOf("ending"))
        case "6": view.jump(to: 0)
        case "f", "F": window.toggleFullScreen(nil)
        case "q", "Q", "\u{1b}": NSApp.terminate(nil)
        default: return false
        }
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ s: NSApplication) -> Bool { true }
}

let app = NSApplication.shared
app.setActivationPolicy(.regular)
let delegate = AppDelegate()
app.delegate = delegate
app.run()
