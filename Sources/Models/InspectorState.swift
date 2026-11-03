import AppKit
import Foundation

@Observable
final class InspectorState {
    var isActive = false
    var mouseX: Double = 0
    var mouseY: Double = 0

    private var monitor: Any?
    private var timer: Timer?

    func start() {
        guard !isActive else { return }
        isActive = true
        updatePosition()

        monitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged]) { [weak self] _ in
            self?.updatePosition()
        }

        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            self?.updatePosition()
        }
    }

    func stop() {
        isActive = false
        if let monitor = monitor {
            NSEvent.removeMonitor(monitor)
        }
        monitor = nil
        timer?.invalidate()
        timer = nil
    }

    func toggle() {
        if isActive { stop() } else { start() }
    }

    private func updatePosition() {
        let location = NSEvent.mouseLocation
        let screenHeight = NSScreen.main?.frame.height ?? 0
        mouseX = location.x
        mouseY = screenHeight - location.y
    }
}
