import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBarController: MenuBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.accessory) // Hides Dock icon & Cmd+Tab
        let store = QuotaStore.shared
        self.menuBarController = MenuBarController(store: store)
    }
}

@main
enum QuotaBarAppMain {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }
}
