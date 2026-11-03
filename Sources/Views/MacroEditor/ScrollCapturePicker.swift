import AppKit

final class ScrollCapturePicker {
    struct Result {
        let point: CGPoint
        let direction: ScrollDirection
        let amount: Double
    }

    private static var current: ScrollCapturePicker?

    static func pickScroll(completion: @escaping (Result) -> Void) {
        current?.finish(deliver: false)
        let picker = ScrollCapturePicker(completion: completion)
        current = picker
        picker.begin()
    }

    private let completion: (Result) -> Void
    private var panel: NSPanel?
    private let label = NSTextField(labelWithString: "")
    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var idleTimer: Timer?
    private var firstPoint: CGPoint?
    private var sumY: Int64 = 0
    private var sumX: Int64 = 0

    private init(completion: @escaping (Result) -> Void) {
        self.completion = completion
    }

    private func begin() {
        showPanel()
        let mask = CGEventMask(1 << CGEventType.scrollWheel.rawValue) | CGEventMask(1 << CGEventType.keyDown.rawValue)
        let callback: CGEventTapCallBack = { _, type, event, refcon in
            guard let refcon else { return Unmanaged.passUnretained(event) }
            let picker = Unmanaged<ScrollCapturePicker>.fromOpaque(refcon).takeUnretainedValue()
            if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                if let tap = picker.tap { CGEvent.tapEnable(tap: tap, enable: true) }
                return Unmanaged.passUnretained(event)
            }
            if type == .keyDown {
                if event.getIntegerValueField(.keyboardEventKeycode) == 53 {
                    DispatchQueue.main.async { picker.finish(deliver: false) }
                }
            } else {
                let dy = event.getIntegerValueField(.scrollWheelEventDeltaAxis1)
                let dx = event.getIntegerValueField(.scrollWheelEventDeltaAxis2)
                let location = event.location
                DispatchQueue.main.async { picker.record(dx: dx, dy: dy, at: location) }
            }
            return Unmanaged.passUnretained(event)
        }

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .tailAppendEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            label.stringValue = "Sem permissão de Acessibilidade"
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in self?.finish(deliver: false) }
            return
        }

        self.tap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    private func record(dx: Int64, dy: Int64, at location: CGPoint) {
        guard dx != 0 || dy != 0 else { return }
        if firstPoint == nil { firstPoint = location }
        sumX += dx
        sumY += dy

        label.stringValue = summary()

        idleTimer?.invalidate()
        idleTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { [weak self] _ in
            self?.finish(deliver: true)
        }
    }

    private func result() -> Result? {
        guard let point = firstPoint else { return nil }
        let direction: ScrollDirection
        let amount: Double
        if abs(sumY) >= abs(sumX) {
            direction = sumY > 0 ? .up : .down
            amount = Double(abs(sumY))
        } else {
            direction = sumX > 0 ? .left : .right
            amount = Double(abs(sumX))
        }
        return Result(point: point, direction: direction, amount: min(max(amount, 1), 50))
    }

    private func summary() -> String {
        guard let r = result() else { return "…" }
        return "\(r.direction.title) ×\(Int(r.amount))  ·  (\(Int(r.point.x)), \(Int(r.point.y)))"
    }

    private func showPanel() {
        let width: CGFloat = 440
        let height: CGFloat = 96
        let screen = NSScreen.main?.frame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)

        let win = NSPanel(
            contentRect: NSRect(x: screen.midX - width / 2, y: screen.maxY - 160, width: width, height: height),
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )
        win.level = .screenSaver + 1
        win.isOpaque = false
        win.hasShadow = true
        win.backgroundColor = .clear
        win.ignoresMouseEvents = true
        win.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let bg = NSVisualEffectView(frame: NSRect(x: 0, y: 0, width: width, height: height))
        bg.material = .hudWindow
        bg.state = .active
        bg.wantsLayer = true
        bg.layer?.cornerRadius = 14
        bg.layer?.masksToBounds = true

        let title = NSTextField(labelWithString: "Posicione o mouse e role · termina após 1 s parado · Esc cancela")
        title.font = .systemFont(ofSize: 12, weight: .medium)
        title.textColor = .secondaryLabelColor
        title.alignment = .center
        title.frame = NSRect(x: 12, y: height - 30, width: width - 24, height: 18)

        label.font = .systemFont(ofSize: 22, weight: .semibold)
        label.textColor = .white
        label.alignment = .center
        label.stringValue = "Aguardando scroll…"
        label.frame = NSRect(x: 12, y: 18, width: width - 24, height: 32)

        bg.addSubview(title)
        bg.addSubview(label)
        win.contentView = bg
        win.orderFrontRegardless()
        panel = win
    }

    private func finish(deliver: Bool) {
        idleTimer?.invalidate()
        idleTimer = nil
        if let tap { CGEvent.tapEnable(tap: tap, enable: false) }
        if let runLoopSource { CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes) }
        tap = nil
        runLoopSource = nil
        panel?.orderOut(nil)
        panel = nil
        if Self.current === self { Self.current = nil }
        if deliver, let r = result() { completion(r) }
    }
}
