import AppKit
import PacingCore

final class InlineEntrySheet: NSViewController {
    let meterConfig: MeterConfig
    let onSave: (Double, Double?, Date) -> Void
    let onCancel: () -> Void

    private let weeklyField = NSTextField()
    private let fiveHourField = NSTextField()
    private let datePicker = NSDatePicker()

    init(
        meterConfig: MeterConfig,
        currentWeekly: Double,
        current5h: Double?,
        currentReset: Date?,
        onSave: @escaping (Double, Double?, Date) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.meterConfig = meterConfig
        self.onSave = onSave
        self.onCancel = onCancel
        super.init(nibName: nil, bundle: nil)

        weeklyField.stringValue = currentWeekly > 0 ? "\(Int(round(currentWeekly)))" : ""
        if let current5h {
            fiveHourField.stringValue = "\(Int(round(current5h)))"
        }
        if let currentReset {
            datePicker.dateValue = currentReset
        } else {
            datePicker.dateValue = Calendar.current.date(byAdding: .day, value: 4, to: Date()) ?? Date()
        }
    }

    required init?(coder: NSCoder) { fatalError() }

    override func loadView() {
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 290, height: 160))
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor.controlBackgroundColor.withAlphaComponent(0.9).cgColor
        container.layer?.cornerRadius = 10
        container.layer?.borderColor = NSColor.controlAccentColor.withAlphaComponent(0.4).cgColor
        container.layer?.borderWidth = 1.0

        let titleLabel = NSTextField(labelWithString: "Update \(meterConfig.name)")
        titleLabel.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        titleLabel.frame = NSRect(x: 12, y: 130, width: 260, height: 20)
        container.addSubview(titleLabel)

        let weeklyLabel = NSTextField(labelWithString: "Weekly %:")
        weeklyLabel.font = NSFont.systemFont(ofSize: 11)
        weeklyLabel.textColor = .secondaryLabelColor
        weeklyLabel.frame = NSRect(x: 12, y: 98, width: 70, height: 18)
        container.addSubview(weeklyLabel)

        weeklyField.frame = NSRect(x: 85, y: 96, width: 55, height: 22)
        weeklyField.font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium)
        container.addSubview(weeklyField)

        if meterConfig.hasFiveHourWindow {
            let fiveHourLabel = NSTextField(labelWithString: "5h %:")
            fiveHourLabel.font = NSFont.systemFont(ofSize: 11)
            fiveHourLabel.textColor = .secondaryLabelColor
            fiveHourLabel.frame = NSRect(x: 155, y: 98, width: 50, height: 18)
            container.addSubview(fiveHourLabel)

            fiveHourField.frame = NSRect(x: 210, y: 96, width: 55, height: 22)
            fiveHourField.font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium)
            container.addSubview(fiveHourField)
        }

        let resetLabel = NSTextField(labelWithString: "Reset Date:")
        resetLabel.font = NSFont.systemFont(ofSize: 11)
        resetLabel.textColor = .secondaryLabelColor
        resetLabel.frame = NSRect(x: 12, y: 64, width: 70, height: 18)
        container.addSubview(resetLabel)

        datePicker.datePickerStyle = .textFieldAndStepper
        datePicker.datePickerElements = [.yearMonthDay, .hourMinute]
        datePicker.frame = NSRect(x: 85, y: 62, width: 180, height: 24)
        container.addSubview(datePicker)

        let cancelButton = NSButton(title: "Cancel", target: self, action: #selector(cancelTapped))
        cancelButton.bezelStyle = .rounded
        cancelButton.controlSize = .small
        cancelButton.frame = NSRect(x: 120, y: 12, width: 70, height: 24)
        cancelButton.keyEquivalent = "\u{1b}" // ESC
        container.addSubview(cancelButton)

        let saveButton = NSButton(title: "Save", target: self, action: #selector(saveTapped))
        saveButton.bezelStyle = .rounded
        saveButton.controlSize = .small
        saveButton.frame = NSRect(x: 200, y: 12, width: 75, height: 24)
        saveButton.keyEquivalent = "\r" // Enter
        container.addSubview(saveButton)

        self.view = container
    }

    @objc private func cancelTapped() {
        onCancel()
    }

    @objc private func saveTapped() {
        guard let weekly = Double(weeklyField.stringValue), weekly >= 0, weekly <= 100 else { return }
        var fiveHour: Double? = nil
        if meterConfig.hasFiveHourWindow && !fiveHourField.stringValue.isEmpty {
            fiveHour = Double(fiveHourField.stringValue)
        }
        onSave(weekly, fiveHour, datePicker.dateValue)
    }
}
