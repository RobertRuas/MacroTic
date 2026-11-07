import AppKit

final class UpdateProgressWindow {
    private let panel: NSPanel
    private let iconView: NSImageView
    private let statusLabel: NSTextField
    private let progressBar: NSProgressIndicator

    init() {
        let size = NSSize(width: 320, height: 148)
        panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isMovableByWindowBackground = true
        panel.level = .floating
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false

        let background = NSVisualEffectView(frame: NSRect(origin: .zero, size: size))
        background.material = .hudWindow
        background.blendingMode = .behindWindow
        background.state = .active
        background.wantsLayer = true
        background.layer?.cornerRadius = 16
        background.layer?.masksToBounds = true

        iconView = NSImageView(frame: NSRect(x: (size.width - 52) / 2, y: 78, width: 52, height: 52))
        iconView.image = NSApp.applicationIconImage
        iconView.imageScaling = .scaleProportionallyUpOrDown

        statusLabel = NSTextField(labelWithString: "Verificando atualizações…")
        statusLabel.font = .systemFont(ofSize: 13, weight: .medium)
        statusLabel.alignment = .center
        statusLabel.textColor = .labelColor
        statusLabel.frame = NSRect(x: 20, y: 48, width: size.width - 40, height: 20)

        progressBar = NSProgressIndicator(frame: NSRect(x: 40, y: 28, width: size.width - 80, height: 6))
        progressBar.style = .bar
        progressBar.isIndeterminate = true
        progressBar.minValue = 0
        progressBar.maxValue = 1
        progressBar.startAnimation(nil)

        background.addSubview(iconView)
        background.addSubview(statusLabel)
        background.addSubview(progressBar)
        panel.contentView = background
        panel.center()
    }

    func show() {
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.25
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1
        }
    }

    func close() {
        fadeOutAndClose()
    }

    func fadeOutAndClose() {
        let panel = self.panel
        let bar = self.progressBar
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.3
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().alphaValue = 0
        }, completionHandler: {
            bar.stopAnimation(nil)
            panel.orderOut(nil)
        })
    }

    func setStatus(_ text: String) {
        statusLabel.stringValue = text
    }

    func setIndeterminate(_ indeterminate: Bool) {
        guard progressBar.isIndeterminate != indeterminate else { return }
        progressBar.isIndeterminate = indeterminate
        if indeterminate {
            progressBar.startAnimation(nil)
        } else {
            progressBar.stopAnimation(nil)
        }
    }

    func setProgress(_ fraction: Double) {
        let clamped = min(max(fraction, 0), 1)
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.25
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            progressBar.animator().doubleValue = clamped
        }
    }
}
