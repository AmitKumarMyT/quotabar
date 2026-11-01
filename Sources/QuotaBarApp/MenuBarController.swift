import AppKit
import PacingCore

final class MenuBarController: NSObject {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let popover = NSPopover()
    private let store: QuotaStore
    private var popoverVC: PopoverViewController?
    private var timer: Timer?

    init(store: QuotaStore) {
        self.store = store
        super.init()

        setupStatusButton()
        setupPopover()
        updateLabel()

        store.onUpdate = { [weak self] in
            DispatchQueue.main.async {
                self?.updateLabel()
                self?.popoverVC?.refresh()
            }
        }

        // 15-minute background timer
        timer = Timer.scheduledTimer(withTimeInterval: 15 * 60, repeats: true) { [weak self] _ in
            self?.store.refreshDaySnapshots()
        }

        // NSWorkspace wake observer
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(systemDidWake),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )
    }

    private func setupStatusButton() {
        guard let button = statusItem.button else { return }
        button.target = self
        button.action = #selector(togglePopover)
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    private func setupPopover() {
        popover.behavior = .transient
        popover.animates = true
        let vc = PopoverViewController(store: store)
        self.popoverVC = vc
        popover.contentViewController = vc
    }

    func updateLabel() {
        guard let button = statusItem.button else { return }

        if store.meters.isEmpty {
            button.title = "Quota"
            return
        }

        if store.showLowestHeadroomOnly {
            let lowest = store.meters.map { meter in
                (meter, store.plan(for: meter))
            }.min { $0.1.roomLeftToday < $1.1.roomLeftToday }

            if let (meter, plan) = lowest {
                button.title = "\(meter.config.provider.shortLabel) \(plan.roomLeftToday)%"
            }
        } else {
            // e.g. "C 13 · A 17"
            let parts = store.meters.prefix(2).map { meter in
                let plan = store.plan(for: meter)
                return "\(meter.config.provider.shortLabel) \(plan.roomLeftToday)"
            }
            button.title = parts.joined(separator: " · ")
        }
    }

    @objc private func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popoverVC?.refresh()
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    @objc private func systemDidWake() {
        store.refreshDaySnapshots()
    }

    deinit {
        timer?.invalidate()
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }
}
