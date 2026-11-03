import AppKit
import SwiftUI

final class ScreenCoordinatePicker {

    static func pickPoint(completion: @escaping (CGPoint) -> Void) {
        let picker = CoordinatePickerWindow(mode: .singleClick) { result in
            switch result {
            case .point(let p):
                completion(p)
            default:
                break
            }
        }
        picker.beginPicking()
    }

    static func pickDrag(completion: @escaping (CGPoint, CGPoint) -> Void) {
        let picker = CoordinatePickerWindow(mode: .drag) { result in
            switch result {
            case .drag(let start, let end):
                completion(start, end)
            default:
                break
            }
        }
        picker.beginPicking()
    }
}

private enum PickerMode {
    case singleClick
    case drag
}

private enum PickerResult {
    case point(CGPoint)
    case drag(CGPoint, CGPoint)
}

private final class CoordinatePickerWindow: NSPanel {
    private let mode: PickerMode
    private let onComplete: (PickerResult) -> Void
    private var instructionWindow: NSWindow?
    private var overlayView: PickerOverlayView?

    private var dragStart: CGPoint?
    private var isDragging = false

    init(mode: PickerMode, onComplete: @escaping (PickerResult) -> Void) {
        self.mode = mode
        self.onComplete = onComplete

        let screenFrame = NSScreen.main?.frame ?? NSRect(x: 0, y: 0, width: 1920, height: 1080)

        super.init(
            contentRect: screenFrame,
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )

        self.level = .screenSaver
        self.isOpaque = false
        self.hasShadow = false
        self.backgroundColor = NSColor.black.withAlphaComponent(0.01)
        self.ignoresMouseEvents = false
        self.acceptsMouseMovedEvents = true
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let overlay = PickerOverlayView(frame: screenFrame)
        overlay.autoresizingMask = [.width, .height]
        self.contentView = overlay
        self.overlayView = overlay
    }

    func beginPicking() {
        makeKeyAndOrderFront(nil)
        NSCursor.crosshair.push()
        showInstruction()
    }

    private func showInstruction() {
        instructionWindow?.orderOut(nil)

        let message: String
        switch mode {
        case .singleClick:
            message = "Clique na posição desejada · Esc para cancelar"
        case .drag:
            if isDragging {
                message = "Arraste até o destino e solte · Esc para cancelar"
            } else {
                message = "Clique e segure no ponto de início, depois arraste · Esc para cancelar"
            }
        }

        let label = NSTextField(labelWithString: message)
        label.font = NSFont.systemFont(ofSize: 15, weight: .medium)
        label.textColor = .white
        label.alignment = .center
        label.sizeToFit()

        let padding: CGFloat = 24
        let width = label.frame.width + padding * 2
        let height: CGFloat = 44

        let screenFrame = NSScreen.main?.frame ?? .zero
        let x = screenFrame.midX - width / 2
        let y = screenFrame.maxY - 80

        let win = NSPanel(
            contentRect: NSRect(x: x, y: y, width: width, height: height),
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )
        win.level = .screenSaver + 1
        win.isOpaque = false
        win.hasShadow = true
        win.backgroundColor = .clear

        let bg = NSVisualEffectView(frame: NSRect(x: 0, y: 0, width: width, height: height))
        bg.material = .hudWindow
        bg.state = .active
        bg.wantsLayer = true
        bg.layer?.cornerRadius = 10
        bg.layer?.masksToBounds = true

        label.frame = NSRect(x: padding, y: (height - label.frame.height) / 2, width: label.frame.width, height: label.frame.height)
        bg.addSubview(label)
        win.contentView = bg
        win.orderFront(nil)

        instructionWindow = win
    }

    override func mouseDown(with event: NSEvent) {
        let screenPoint = NSEvent.mouseLocation

        switch mode {
        case .singleClick:
            overlayView?.addMarker(at: convertPoint(fromScreen: screenPoint), label: "●")
            finishPicking(result: .point(screenPoint))

        case .drag:
            dragStart = screenPoint
            isDragging = true
            overlayView?.addMarker(at: convertPoint(fromScreen: screenPoint), label: "A")
            showInstruction()
        }
    }

    override func mouseDragged(with event: NSEvent) {
        guard mode == .drag, isDragging else { return }
        let current = NSEvent.mouseLocation
        if let start = dragStart {
            overlayView?.updateDragLine(
                from: convertPoint(fromScreen: start),
                to: convertPoint(fromScreen: current)
            )
        }
    }

    override func mouseUp(with event: NSEvent) {
        guard mode == .drag, isDragging, let start = dragStart else { return }
        let endPoint = NSEvent.mouseLocation
        overlayView?.addMarker(at: convertPoint(fromScreen: endPoint), label: "B")
        finishPicking(result: .drag(start, endPoint))
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {
            cancelPicking()
        }
    }

    override var canBecomeKey: Bool { true }

    private func finishPicking(result: PickerResult) {
        NSCursor.pop()
        instructionWindow?.orderOut(nil)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [self] in
            orderOut(nil)
            onComplete(result)
        }
    }

    private func cancelPicking() {
        NSCursor.pop()
        instructionWindow?.orderOut(nil)
        orderOut(nil)
    }
}

private final class PickerOverlayView: NSView {

    private var dragLine: (from: NSPoint, to: NSPoint)?

    override func draw(_ dirtyRect: NSRect) {
        NSColor.black.withAlphaComponent(0.01).setFill()
        dirtyRect.fill()

        if let line = dragLine {
            let path = NSBezierPath()
            path.move(to: line.from)
            path.line(to: line.to)

            NSColor.systemBlue.withAlphaComponent(0.6).setStroke()
            path.lineWidth = 2
            path.setLineDash([6, 4], count: 2, phase: 0)
            path.stroke()
        }
    }

    func addMarker(at point: NSPoint, label: String) {
        let size: CGFloat = 28
        let markerFrame = NSRect(
            x: point.x - size / 2,
            y: point.y - size / 2,
            width: size,
            height: size
        )

        let marker = MarkerView(frame: markerFrame, label: label)
        addSubview(marker)
    }

    func updateDragLine(from: NSPoint, to: NSPoint) {
        dragLine = (from, to)
        needsDisplay = true
    }
}

private final class MarkerView: NSView {
    private let label: String

    init(frame: NSRect, label: String) {
        self.label = label
        super.init(frame: frame)
        wantsLayer = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }

        let circleRect = bounds.insetBy(dx: 2, dy: 2)
        ctx.setFillColor(NSColor.systemBlue.withAlphaComponent(0.8).cgColor)
        ctx.fillEllipse(in: circleRect)

        ctx.setStrokeColor(NSColor.white.cgColor)
        ctx.setLineWidth(2)
        ctx.strokeEllipse(in: circleRect)

        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12, weight: .bold),
            .foregroundColor: NSColor.white
        ]
        let str = NSAttributedString(string: label, attributes: attrs)
        let strSize = str.size()
        let strOrigin = NSPoint(
            x: bounds.midX - strSize.width / 2,
            y: bounds.midY - strSize.height / 2
        )
        str.draw(at: strOrigin)
    }
}
