import AppKit
import Combine
import Sparkle

@MainActor
final class UpdateService: NSObject, ObservableObject, SPUStandardUserDriverDelegate {
    @Published private(set) var canCheck = false
    @Published private(set) var automaticallyChecks = false
    private var controller: SPUStandardUpdaterController?

    // Sparkle shows scheduled alerts without stealing focus from the current app.
    nonisolated var supportsGentleScheduledUpdateReminders: Bool { true }

    func start() {
        guard controller == nil, Bundle.main.object(forInfoDictionaryKey: "SUFeedURL") != nil else { return }
        let controller = SPUStandardUpdaterController(startingUpdater: false,
            updaterDelegate: nil, userDriverDelegate: self)
        self.controller = controller
        controller.updater.publisher(for: \.canCheckForUpdates)
            .receive(on: RunLoop.main).assign(to: &$canCheck)
        controller.updater.publisher(for: \.automaticallyChecksForUpdates)
            .receive(on: RunLoop.main).assign(to: &$automaticallyChecks)
        controller.startUpdater()
    }

    func menuItem() -> NSMenuItem {
        let item = NSMenuItem(title: "检查更新…", action: #selector(SPUStandardUpdaterController.checkForUpdates(_:)), keyEquivalent: "")
        item.target = controller
        item.isEnabled = controller != nil
        return item
    }

    func check() { controller?.checkForUpdates(nil) }
    func setAutomaticallyChecks(_ enabled: Bool) {
        controller?.updater.automaticallyChecksForUpdates = enabled
    }
}
