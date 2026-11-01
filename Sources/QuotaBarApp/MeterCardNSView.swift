import AppKit
import PacingCore

final class MeterCardNSView: NSView {
    let meterData: PersistedMeterData
    var plan: DayPacingPlan
    let onSave: (Double, Double?, Date) -> Void

    private let titleLabel = NSTextField(labelWithString: "")
    private let statusLabel = NSTextField(labelWithString: "")
    private let goalLabel = NSTextField(labelWithString: "")
    private let goalSubLabel = NSTextField(labelWithString: "")
    private let roomLeftLabel = NSTextField(labelWithString: "")
    private let progressBar = CapsuleProgressBarView()
    private let statsLabel = NSTextField(labelWithString: "")
    private let guardLabel = NSTextField(labelWithString: "")
    private let updateButton = NSButton()

    private var entrySheet: InlineEntrySheet?

    init(
        meterData: PersistedMeterData,
        plan: DayPacingPlan,
        onSave: @escaping (Double, Double?, Date) -> Void
    ) {
        self.meterData = meterData
        self.plan = plan
        self.onSave = onSave
        super.init(frame: NSRect(x: 0, y: 0, width: 290, height: 140))

        wantsLayer = true
        layer?.cornerRadius = 12
        // macOS 27: navigation layer rule (flat translucent surface inside glass)
        layer?.backgroundColor = NSColor.controlBackgroundColor.withAlphaComponent(0.65).cgColor
        layer?.borderColor = NSColor.white.withAlphaComponent(0.08).cgColor
        layer?.borderWidth = 1.0

        setupViews()
        render()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setupViews() {
        titleLabel.frame = NSRect(x: 14, y: 110, width: 170, height: 20)
        titleLabel.font = NSFont.systemFont(ofSize: 14, weight: .semibold)
        addSubview(titleLabel)

        statusLabel.frame = NSRect(x: 180, y: 110, width: 96, height: 20)
        statusLabel.alignment = .right
        statusLabel.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        addSubview(statusLabel)

        goalLabel.frame = NSRect(x: 14, y: 64, width: 100, height: 44)
        goalLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 38, weight: .bold)
        addSubview(goalLabel)

        goalSubLabel.frame = NSRect(x: 114, y: 84, width: 100, height: 16)
        goalSubLabel.stringValue = "today's goal"
        goalSubLabel.font = NSFont.systemFont(ofSize: 10, weight: .regular)
        goalSubLabel.textColor = .secondaryLabelColor
        addSubview(goalSubLabel)

        roomLeftLabel.frame = NSRect(x: 114, y: 66, width: 120, height: 16)
        roomLeftLabel.font = NSFont.systemFont(ofSize: 11, weight: .semibold)
        addSubview(roomLeftLabel)

        updateButton.frame = NSRect(x: 224, y: 72, width: 54, height: 24)
        updateButton.title = "Update"
        updateButton.bezelStyle = .rounded
        updateButton.controlSize = .small
        updateButton.target = self
        updateButton.action = #selector(updateTapped)
        addSubview(updateButton)

        progressBar.frame = NSRect(x: 14, y: 46, width: 262, height: 14)
        addSubview(progressBar)

        statsLabel.frame = NSRect(x: 14, y: 26, width: 262, height: 14)
        statsLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 10, weight: .regular)
        statsLabel.textColor = .secondaryLabelColor
        addSubview(statsLabel)

        guardLabel.frame = NSRect(x: 14, y: 8, width: 262, height: 14)
        guardLabel.font = NSFont.systemFont(ofSize: 9, weight: .regular)
        guardLabel.textColor = .secondaryLabelColor
        addSubview(guardLabel)
    }

    func render() {
        titleLabel.stringValue = meterData.config.name
        statusLabel.stringValue = "\(plan.status.rawValue)"
        statusLabel.textColor = statusColor(for: plan.status)

        goalLabel.stringValue = "\(plan.goal)%"
        roomLeftLabel.stringValue = "\(plan.roomLeftToday)% left today"
        roomLeftLabel.textColor = plan.roomLeftToday > 0 ? NSColor.controlAccentColor : NSColor.systemRed

        progressBar.plan = plan

        statsLabel.stringValue = "\(plan.currentUsed)% used  ·  Safe: \(plan.safeMark)%  ·  Ease: \(plan.easeOffMark)%"

        if let guardText = plan.guardStatusText {
            guardLabel.stringValue = guardText
            guardLabel.textColor = plan.status == .stranded ? NSColor.systemRed : NSColor.secondaryLabelColor
            guardLabel.isHidden = false
        } else {
            guardLabel.isHidden = true
        }
    }

    @objc private func updateTapped() {
        let sheet = InlineEntrySheet(
            meterConfig: meterData.config,
            currentWeekly: Double(plan.currentUsed),
            current5h: meterData.readings.last?.fiveHourPercentUsed,
            currentReset: meterData.readings.last?.weeklyResetDate,
            onSave: { [weak self] weekly, fiveHour, resetDate in
                self?.onSave(weekly, fiveHour, resetDate)
                self?.entrySheet?.view.removeFromSuperview()
                self?.entrySheet = nil
            },
            onCancel: { [weak self] in
                self?.entrySheet?.view.removeFromSuperview()
                self?.entrySheet = nil
            }
        )
        self.entrySheet = sheet
        sheet.view.frame = self.bounds
        addSubview(sheet.view)
    }

    private func statusColor(for status: PacingStatus) -> NSColor {
        switch status {
        case .onPace, .pastSafe:
            return .systemGreen
        case .easeOff:
            return .systemOrange
        case .overGoal, .stranded:
            return .systemRed
        case .oldData:
            return .secondaryLabelColor
        }
    }
}
