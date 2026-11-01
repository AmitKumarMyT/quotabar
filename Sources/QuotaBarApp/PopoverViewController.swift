import AppKit
import PacingCore

final class PopoverViewController: NSViewController {
    let store: QuotaStore
    private var cardViews: [MeterCardNSView] = []
    private let footerTimeLabel = NSTextField(labelWithString: "")

    init(store: QuotaStore) {
        self.store = store
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func loadView() {
        let width: CGFloat = 320
        let cardHeight: CGFloat = 140
        let cardSpacing: CGFloat = 12
        let topBarHeight: CGFloat = 40
        let footerHeight: CGFloat = 36

        let contentHeight = topBarHeight + CGFloat(store.meters.count) * (cardHeight + cardSpacing) + footerHeight

        // macOS 27: Native Liquid Glass / Visual Effect View container
        let effectView = NSVisualEffectView(frame: NSRect(x: 0, y: 0, width: width, height: contentHeight))
        effectView.material = .hudWindow
        effectView.blendingMode = .behindWindow
        effectView.state = .active

        // Contrast scrim
        let scrim = NSView(frame: effectView.bounds)
        scrim.wantsLayer = true
        scrim.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.20).cgColor
        effectView.addSubview(scrim)

        // Header Title
        let headerLabel = NSTextField(labelWithString: "AI Quota Monitor")
        headerLabel.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        headerLabel.frame = NSRect(x: 16, y: contentHeight - 30, width: 140, height: 20)
        effectView.addSubview(headerLabel)

        // "Scan Image" Button in Top Bar
        let scanButton = NSButton(title: "Scan Screenshot", target: self, action: #selector(scanScreenshotTapped))
        scanButton.bezelStyle = .rounded
        scanButton.controlSize = .small
        scanButton.font = NSFont.systemFont(ofSize: 10, weight: .medium)
        scanButton.frame = NSRect(x: width - 125, y: contentHeight - 32, width: 110, height: 22)
        effectView.addSubview(scanButton)

        // Stacked Cards
        cardViews.removeAll()
        var currentY = contentHeight - topBarHeight - cardHeight

        for meter in store.meters {
            let plan = store.plan(for: meter)
            let card = MeterCardNSView(meterID: meter.config.id, plan: plan) { [weak self] weekly, fiveHour, resetDate in
                self?.store.addReading(
                    for: meter.config.id,
                    weeklyPercent: weekly,
                    fiveHourPercent: fiveHour,
                    weeklyResetDate: resetDate
                )
            }
            card.frame = NSRect(x: 15, y: currentY, width: 290, height: cardHeight)
            card.update(meter: meter, plan: plan)
            effectView.addSubview(card)
            cardViews.append(card)

            currentY -= (cardHeight + cardSpacing)
        }

        // Footer
        footerTimeLabel.font = NSFont.systemFont(ofSize: 10, weight: .regular)
        footerTimeLabel.textColor = .secondaryLabelColor
        footerTimeLabel.frame = NSRect(x: 16, y: 10, width: 200, height: 16)
        effectView.addSubview(footerTimeLabel)

        let quitButton = NSButton(title: "Quit", target: self, action: #selector(quitApp))
        quitButton.isBordered = false
        quitButton.font = NSFont.systemFont(ofSize: 11)
        quitButton.contentTintColor = .secondaryLabelColor
        quitButton.frame = NSRect(x: width - 55, y: 8, width: 40, height: 20)
        effectView.addSubview(quitButton)

        self.view = effectView
        updateFooterTime()
    }

    func refresh() {
        for card in cardViews {
            if let freshMeter = store.meters.first(where: { $0.config.id == card.meterID }) {
                let freshPlan = store.plan(for: freshMeter)
                card.update(meter: freshMeter, plan: freshPlan)
            }
        }
        updateFooterTime()
    }

    private func updateFooterTime() {
        if let latestDate = store.meters.compactMap({ $0.readings.last?.timestamp }).max() {
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .short
            footerTimeLabel.stringValue = "Updated " + formatter.localizedString(for: latestDate, relativeTo: Date())
        } else {
            footerTimeLabel.stringValue = "No readings"
        }
    }

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }

    @objc private func scanScreenshotTapped() {
        let openPanel = NSOpenPanel()
        openPanel.title = "Select Usage Screenshot (Claude or Antigravity)"
        openPanel.allowedContentTypes = [.png, .jpeg, .tiff]
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseDirectories = false

        if openPanel.runModal() == .OK, let url = openPanel.url {
            VisionUsageParser.shared.parseImage(at: url) { [weak self] results in
                guard let self = self else { return }
                for result in results {
                    if let meter = self.store.meters.first(where: { $0.config.provider == result.provider }) {
                        let reset = result.resetDate ?? meter.readings.last?.weeklyResetDate ?? Date().addingTimeInterval(4 * 86400)
                        self.store.addReading(
                            for: meter.config.id,
                            weeklyPercent: result.weeklyPercentUsed,
                            fiveHourPercent: result.fiveHourPercentUsed,
                            weeklyResetDate: reset
                        )
                    }
                }
            }
        }
    }
}
