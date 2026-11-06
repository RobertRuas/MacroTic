import AppKit

/// Full-screen, click-through overlay that visualizes what a macro step does,
/// shown while the user hovers a step row with debug mode enabled.
final class DebugPreviewOverlay {
    static let shared = DebugPreviewOverlay()

    private var panel: NSPanel?
    private var overlay: DebugOverlayView?

    private func ensurePanel() {
        guard panel == nil else { return }
        let frame = NSScreen.main?.frame ?? NSRect(x: 0, y: 0, width: 1920, height: 1080)
        let p = NSPanel(
            contentRect: frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        p.level = .screenSaver
        p.isOpaque = false
        p.backgroundColor = .clear
        p.hasShadow = false
        p.ignoresMouseEvents = true
        p.hidesOnDeactivate = false
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle, .stationary]
        let view = DebugOverlayView(frame: NSRect(origin: .zero, size: frame.size))
        view.autoresizingMask = [.width, .height]
        p.contentView = view
        panel = p
        overlay = view
    }

    func show(for step: MacroStep) {
        DispatchQueue.main.async {
            self.ensurePanel()
            guard let panel = self.panel, let overlay = self.overlay else { return }
            if overlay.configure(for: step) {
                panel.orderFrontRegardless()
            } else {
                overlay.clear()
                panel.orderOut(nil)
            }
        }
    }

    func hide() {
        DispatchQueue.main.async {
            self.overlay?.clear()
            self.panel?.orderOut(nil)
        }
    }
}

final class DebugOverlayView: NSView {
    private enum Mode {
        case click(CGPoint)
        case drag(CGPoint, CGPoint)
        case scroll(CGPoint, ScrollDirection)
        case window(CGRect)
    }

    private var mode: Mode?
    private var timer: Timer?
    private var phase: CGFloat = 0

    func configure(for step: MacroStep) -> Bool {
        switch step.kind {
        case .click:
            guard step.hasCoordinates else { return false }
            mode = .click(CGPoint(x: step.clickX, y: step.clickY))
        case .dragAndDrop:
            guard step.hasDragCoordinates else { return false }
            mode = .drag(
                CGPoint(x: step.dragStartX, y: step.dragStartY),
                CGPoint(x: step.dragEndX, y: step.dragEndY)
            )
        case .scroll:
            let point: CGPoint
            if step.scrollMovesMouse && step.hasScrollPosition {
                point = CGPoint(x: step.scrollX, y: step.scrollY)
            } else {
                point = CGPoint(x: bounds.midX, y: bounds.midY)
            }
            mode = .scroll(point, step.scrollDirection)
        case .launchApp:
            guard !step.value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  let rect = WindowCatalog.frame(forTitle: step.value) else { return false }
            mode = .window(rect)
        default:
            return false
        }
        startAnimating()
        needsDisplay = true
        return true
    }

    func clear() {
        mode = nil
        stopAnimating()
        needsDisplay = true
    }

    private func startAnimating() {
        guard timer == nil else { return }
        let t = Timer(timeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.phase += (1.0 / 30.0) / 1.1
            if self.phase > 1 { self.phase -= 1 }
            self.needsDisplay = true
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func stopAnimating() {
        timer?.invalidate()
        timer = nil
    }

    deinit { stopAnimating() }

    // CG (top-left origin) → this view's coordinates (bottom-left origin).
    private func toView(_ p: CGPoint) -> NSPoint {
        NSPoint(x: p.x, y: bounds.height - p.y)
    }

    private func toView(_ r: CGRect) -> NSRect {
        NSRect(x: r.minX, y: bounds.height - r.maxY, width: r.width, height: r.height)
    }

    private func eased(_ t: CGFloat) -> CGFloat { t * t * (3 - 2 * t) }

    override func draw(_ dirtyRect: NSRect) {
        guard let mode = mode else { return }
        switch mode {
        case .click(let p):
            drawClick(at: toView(p))
        case .drag(let a, let b):
            drawDrag(from: toView(a), to: toView(b))
        case .scroll(let p, let dir):
            drawScroll(at: toView(p), direction: dir)
        case .window(let r):
            drawWindow(toView(r))
        }
    }

    private func drawClick(at p: NSPoint) {
        for offset in [CGFloat(0), 0.5] {
            var pp = phase + offset
            if pp > 1 { pp -= 1 }
            let r = 12 + pp * 44
            NSColor.systemRed.withAlphaComponent((1 - pp) * 0.85).setStroke()
            let ring = NSBezierPath(ovalIn: NSRect(x: p.x - r, y: p.y - r, width: 2 * r, height: 2 * r))
            ring.lineWidth = 3
            ring.stroke()
        }
        let dot = NSBezierPath(ovalIn: NSRect(x: p.x - 6, y: p.y - 6, width: 12, height: 12))
        NSColor.systemRed.setFill()
        dot.fill()
        NSColor.white.setStroke()
        dot.lineWidth = 2
        dot.stroke()
    }

    private func drawDrag(from a: NSPoint, to b: NSPoint) {
        let line = NSBezierPath()
        line.move(to: a)
        line.line(to: b)
        NSColor.systemBlue.withAlphaComponent(0.85).setStroke()
        line.lineWidth = 3
        line.setLineDash([9, 6], count: 2, phase: phase * 15)
        line.stroke()

        let t = eased(phase)
        let pos = NSPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t)
        let travel = NSBezierPath(ovalIn: NSRect(x: pos.x - 8, y: pos.y - 8, width: 16, height: 16))
        NSColor.systemBlue.setFill()
        travel.fill()
        NSColor.white.setStroke()
        travel.lineWidth = 2
        travel.stroke()

        drawMarker(at: a, color: .systemGreen, label: "A")
        drawMarker(at: b, color: .systemRed, label: "B")
    }

    private func drawScroll(at p: NSPoint, direction: ScrollDirection) {
        let base = NSBezierPath(ovalIn: NSRect(x: p.x - 28, y: p.y - 28, width: 56, height: 56))
        NSColor.systemTeal.withAlphaComponent(0.18).setFill()
        base.fill()
        NSColor.systemTeal.withAlphaComponent(0.9).setStroke()
        base.lineWidth = 2
        base.stroke()

        let (dx, dy, symbol): (CGFloat, CGFloat, String)
        switch direction {
        case .up: (dx, dy, symbol) = (0, 1, "▲")
        case .down: (dx, dy, symbol) = (0, -1, "▼")
        case .left: (dx, dy, symbol) = (-1, 0, "◀")
        case .right: (dx, dy, symbol) = (1, 0, "▶")
        }

        for offset in [CGFloat(0), 0.5] {
            var pp = phase + offset
            if pp > 1 { pp -= 1 }
            let dist = pp * 26
            let alpha = 1 - pp
            let origin = NSPoint(x: p.x + dx * dist, y: p.y + dy * dist)
            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 22, weight: .heavy),
                .foregroundColor: NSColor.systemTeal.withAlphaComponent(alpha)
            ]
            let str = NSAttributedString(string: symbol, attributes: attrs)
            let size = str.size()
            str.draw(at: NSPoint(x: origin.x - size.width / 2, y: origin.y - size.height / 2))
        }
    }

    private func drawWindow(_ r: NSRect) {
        let pulse = 0.45 + 0.4 * abs(sin(phase * .pi * 2))
        let path = NSBezierPath(roundedRect: r, xRadius: 10, yRadius: 10)
        NSColor.systemGreen.withAlphaComponent(0.10).setFill()
        path.fill()
        NSColor.systemGreen.withAlphaComponent(pulse).setStroke()
        path.lineWidth = 4
        path.stroke()
    }

    private func drawMarker(at p: NSPoint, color: NSColor, label: String) {
        let radius: CGFloat = 13
        let rect = NSRect(x: p.x - radius, y: p.y - radius, width: 2 * radius, height: 2 * radius)
        let circle = NSBezierPath(ovalIn: rect)
        color.withAlphaComponent(0.92).setFill()
        circle.fill()
        NSColor.white.setStroke()
        circle.lineWidth = 2
        circle.stroke()
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13, weight: .bold),
            .foregroundColor: NSColor.white
        ]
        let str = NSAttributedString(string: label, attributes: attrs)
        let size = str.size()
        str.draw(at: NSPoint(x: p.x - size.width / 2, y: p.y - size.height / 2))
    }
}
