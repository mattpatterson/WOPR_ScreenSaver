import ScreenSaver
import AppKit
import QuartzCore

@objc(WOPRSaverView)
final class WOPRSaverView: ScreenSaverView {
    private let director = Director()
    private lazy var renderer = LiveRenderer(director: director)
    private var startDate = Date()
    private var offset: Double = 0
    private var stopObserver: NSObjectProtocol?

    // Layer stack (bottom to top): black root, static map, dynamic frame, CRT scanlines.
    private let root = CALayer()
    private let mapLayer = CALayer()
    private let dynLayer = CALayer()
    private let crtLayer = CALayer()
    private var crtSize: CGSize = .zero
    private var crtScale: CGFloat = 0
    private var currentStaticKey: String?
    private var mapScale: CGFloat = 0

    override init?(frame: NSRect, isPreview: Bool) {
        super.init(frame: frame, isPreview: isPreview)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        animationTimeInterval = 1.0 / 30.0
        root.backgroundColor = Theme.background
        for l in [mapLayer, dynLayer, crtLayer] {
            l.actions = ["contents": NSNull(), "bounds": NSNull(), "position": NSNull(), "hidden": NSNull(), "frame": NSNull()]
            l.contentsGravity = .resize
            root.addSublayer(l)
        }
        dynLayer.magnificationFilter = .linear
        layer = root
        wantsLayer = true
        // The thumbnail in System Settings should show the map, not a black terminal.
        if isPreview { offset = director.startOf("main") + 22 }
        if let s = ProcessInfo.processInfo.environment["WOPR_START"], let v = Double(s) { offset = v }
        // macOS 14+ never calls stopAnimation on legacy savers; quit cleanly when the saver ends.
        stopObserver = DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("com.apple.screensaver.willstop"), object: nil, queue: .main) { [weak self] _ in
            guard let self, !self.isPreview else { return }
            self.stopAnimation()
            if Bundle.main.bundleIdentifier?.contains("legacyScreenSaver") == true {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) { exit(0) }
            }
        }
    }

    deinit {
        if let o = stopObserver { DistributedNotificationCenter.default().removeObserver(o) }
    }

    var directorRef: Director { director }

    /// Seconds into the loop.
    var loopTime: Double { offset + Date().timeIntervalSince(startDate) }

    func jump(to t: Double) { offset = t; startDate = Date(); renderFrame() }

    override func startAnimation() {
        super.startAnimation()
        startDate = Date()
        renderFrame()
    }

    override func animateOneFrame() {
        renderFrame()
    }

    private var backing: CGFloat { window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2 }

    func renderFrame() {
        let size = bounds.size
        guard size.width > 1, size.height > 1 else { return }
        let scale = backing
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        let full = CGRect(origin: .zero, size: size)
        for l in [mapLayer, dynLayer, crtLayer] where l.frame != full { l.frame = full }
        if crtSize != size || crtScale != scale {
            crtSize = size
            crtScale = scale
            crtLayer.contents = Director.crtImage(size: size, scale: scale)
        }
        let f = renderer.render(size: size, backing: scale, time: loopTime)
        dynLayer.contents = f.image
        if let key = f.staticKey, let render = f.staticRender {
            if currentStaticKey != key || mapLayer.contents == nil || mapScale != scale {
                currentStaticKey = key
                mapScale = scale
                mapLayer.contents = renderer.staticImage(size: size, key: key, backing: scale, render: render)
            }
            mapLayer.isHidden = false
        } else {
            mapLayer.isHidden = true
        }
        CATransaction.commit()
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        currentStaticKey = nil
        renderFrame()
    }

    override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        for l in [mapLayer, dynLayer, crtLayer] { l.contentsScale = backing }
        renderFrame()
    }

    override func draw(_ rect: NSRect) {}

    override var hasConfigureSheet: Bool { false }
    override var configureSheet: NSWindow? { nil }
}
