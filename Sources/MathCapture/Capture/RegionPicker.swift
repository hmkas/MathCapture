import AppKit

final class CapturePanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

final class OverlayView: NSView {
    var onCapture: ((CGImage) -> Void)?
    var onCancel: (() -> Void)?

    private var startPoint: NSPoint?
    private var currentPoint: NSPoint?
    private var selectionRect: NSRect?

    private let selectionLayer: CAShapeLayer = {
        let layer = CAShapeLayer()
        layer.strokeColor = NSColor.white.cgColor
        layer.fillColor = NSColor.white.withAlphaComponent(0.15).cgColor
        layer.lineWidth = 2
        layer.lineDashPattern = [8, 4]
        return layer
    }()

    private let infoLayer: CATextLayer = {
        let layer = CATextLayer()
        layer.fontSize = 13
        layer.foregroundColor = NSColor.white.cgColor
        layer.string = "Click and drag to select a formula. Press Esc to cancel."
        layer.alignmentMode = .center
        layer.contentsScale = NSScreen.main?.backingScaleFactor ?? 2
        return layer
    }()

    override init(frame: NSRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        wantsLayer = true
        layer?.addSublayer(selectionLayer)
        layer?.addSublayer(infoLayer)
        infoLayer.frame = CGRect(x: 0, y: 40, width: frame.width, height: 20)
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .crosshair)
    }

    override func mouseDown(with event: NSEvent) {
        startPoint = convert(event.locationInWindow, from: nil)
        currentPoint = startPoint
        selectionRect = nil

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        selectionLayer.path = nil
        CATransaction.commit()

        infoLayer.opacity = 0
    }

    override func mouseDragged(with event: NSEvent) {
        currentPoint = convert(event.locationInWindow, from: nil)
        updateSelection()
    }

    override func mouseUp(with event: NSEvent) {
        currentPoint = convert(event.locationInWindow, from: nil)
        updateSelection()

        guard let rect = selectionRect, rect.width > 8, rect.height > 8 else {
            onCancel?()
            return
        }

        guard let screen = window?.screen else {
            onCancel?()
            return
        }

        let windowRect = convert(rect, to: nil)
        let screenRect = window!.convertToScreen(windowRect)
        let cgRect = CGRect(
            x: screenRect.minX,
            y: screen.frame.height - screenRect.maxY,
            width: screenRect.width,
            height: screenRect.height
        )

        guard let image = captureScreenRect(cgRect) else {
            onCancel?()
            return
        }

        onCapture?(image)
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {
            onCancel?()
        } else {
            super.keyDown(with: event)
        }
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        return true
    }

    override var acceptsFirstResponder: Bool {
        return true
    }

    private func updateSelection() {
        guard let start = startPoint, let current = currentPoint else { return }
        let rect = NSRect(
            x: min(start.x, current.x),
            y: min(start.y, current.y),
            width: abs(current.x - start.x),
            height: abs(current.y - start.y)
        )
        selectionRect = rect

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        selectionLayer.path = CGPath(rect: rect, transform: nil)
        CATransaction.commit()
    }

    func cleanup() {
        selectionLayer.removeFromSuperlayer()
        infoLayer.removeFromSuperlayer()
        NSCursor.arrow.set()
    }
}

private func captureScreenRect(_ rect: CGRect) -> CGImage? {
    CGWindowListCreateImage(rect, .optionOnScreenOnly, kCGNullWindowID, .nominalResolution)
}
