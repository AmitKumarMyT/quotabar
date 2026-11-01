import AppKit
import PacingCore

final class CapsuleProgressBarView: NSView {
    var plan: DayPacingPlan? {
        didSet { needsDisplay = true }
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let plan = plan else { return }

        let bounds = self.bounds
        let trackHeight: CGFloat = 8.0
        let trackY = (bounds.height - trackHeight) / 2.0
        let trackRect = NSRect(x: 0, y: trackY, width: bounds.width, height: trackHeight)

        // Track background
        let trackPath = NSBezierPath(roundedRect: trackRect, xRadius: 4, yRadius: 4)
        NSColor.labelColor.withAlphaComponent(0.12).setFill()
        trackPath.fill()

        let totalWidth = bounds.width
        let usedFraction = min(1.0, max(0.0, CGFloat(plan.currentUsed) / 100.0))
        let goalFraction = min(1.0, max(0.0, CGFloat(plan.goal) / 100.0))
        let safeFraction = min(1.0, max(0.0, CGFloat(plan.safeMark) / 100.0))
        let easeFraction = min(1.0, max(0.0, CGFloat(plan.easeOffMark) / 100.0))

        // Tomorrow's room tail
        if goalFraction > usedFraction {
            let tailRect = NSRect(x: 0, y: trackY, width: goalFraction * totalWidth, height: trackHeight)
            let tailPath = NSBezierPath(roundedRect: tailRect, xRadius: 4, yRadius: 4)
            NSColor.controlAccentColor.withAlphaComponent(0.20).setFill()
            tailPath.fill()
        }

        // Current used fill
        if usedFraction > 0 {
            let fillRect = NSRect(x: 0, y: trackY, width: usedFraction * totalWidth, height: trackHeight)
            let fillPath = NSBezierPath(roundedRect: fillRect, xRadius: 4, yRadius: 4)
            fillColor(for: plan.status).setFill()
            fillPath.fill()
        }

        // Safe tick (70%)
        let safeX = safeFraction * totalWidth - 0.75
        let safeTick = NSRect(x: safeX, y: trackY - 2, width: 1.5, height: trackHeight + 4)
        NSColor.labelColor.withAlphaComponent(0.4).setFill()
        NSBezierPath(rect: safeTick).fill()

        // Ease tick (87.5%)
        let easeX = easeFraction * totalWidth - 0.75
        let easeTick = NSRect(x: easeX, y: trackY - 2, width: 1.5, height: trackHeight + 4)
        NSColor.systemOrange.withAlphaComponent(0.9).setFill()
        NSBezierPath(rect: easeTick).fill()

        // Goal tick (100%)
        let goalX = goalFraction * totalWidth - 1.0
        let goalTick = NSRect(x: goalX, y: trackY - 3, width: 2.0, height: trackHeight + 6)
        NSColor.labelColor.setFill()
        NSBezierPath(rect: goalTick).fill()
    }

    private func fillColor(for status: PacingStatus) -> NSColor {
        switch status {
        case .onPace, .pastSafe:
            return NSColor.systemBlue
        case .easeOff:
            return NSColor.systemOrange
        case .overGoal, .stranded:
            return NSColor.systemRed
        case .oldData:
            return NSColor.systemGray
        }
    }
}
