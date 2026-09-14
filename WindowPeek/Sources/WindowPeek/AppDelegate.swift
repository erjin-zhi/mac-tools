import AppKit
import SwiftUI
import ScreenCaptureKit
import SwitcherCore

@main
enum WindowPeekApp {
    @MainActor
    static func main() {
        if CommandLine.arguments.contains("--permission-probe") {
            if let data = try? JSONEncoder().encode(PermissionService.current()) {
                FileHandle.standardOutput.write(data)
            }
            return
        }
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        withExtendedLifetime(delegate) { app.run() }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate, NSMenuDelegate {
    private let keyboard = KeyboardMonitor()
    private let model = SwitcherModel()
    private let settings = SettingsModel()
    private let updates = UpdateService()
    private let panel = SwitcherPanel()
    private var statusItem: NSStatusItem!
    private let enabledMenuItem = NSMenuItem()
    private var settingsWindow: NSWindow?
    private var refreshTimer: Timer?
    private var loadTask: Task<Void, Never>?
    private var presentationTask: Task<Void, Never>?
    private var initialPreviewIDs: Set<UUID> = []
    private var session: UUID?
    private var targetPID: pid_t?
    private var pendingSelection = LoadingSelection()
    private var confirmationTimeout: Timer?
    private var previewLoader: PreviewScheduler<UUID, CaptureResult>?
    private var visibleWindows: Set<UUID> = []
    private var localMonitor: Any?
    private var permissionTask: Task<Void, Never>?
    private var freshPermissions: PermissionSnapshot?
    private var lastLocalPermissions: PermissionSnapshot?
    private var captureError: String?
    private var actionError: String?
    private var observers: [NSObjectProtocol] = []
    private var clickMonitor: Any?
    private var demoMode = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        if UserDefaults.standard.object(forKey: "enabled") != nil {
            settings.enabled = UserDefaults.standard.bool(forKey: "enabled")
        }
        // Shift existing selections to the corresponding faster tier once.
        if UserDefaults.standard.integer(forKey: "holdDelayOptionsVersion") < 1 {
            let previous = UserDefaults.standard.double(forKey: "holdDelay")
            let migrated = [0.25: 0.15, 0.4: 0.25, 0.6: 0.4, 0.8: 0.6][previous]
            if let migrated { UserDefaults.standard.set(migrated, forKey: "holdDelay") }
            UserDefaults.standard.set(1, forKey: "holdDelayOptionsVersion")
        }
        if UserDefaults.standard.double(forKey: "holdDelay") > 0 {
            settings.delay = UserDefaults.standard.double(forKey: "holdDelay")
        }
        keyboard.holdDelay = settings.delay
        settings.activationKey = ActivationKey(savedValue: UserDefaults.standard.string(forKey: "activationKey"))
        keyboard.activationKey = settings.activationKey
        model.activationKey = settings.activationKey
        keyboard.onEffect = { [weak self] effect in self?.handle(effect) }
        keyboard.onUserInput = { [weak self] in
            guard let self, self.pendingSelection.confirmationPending else { return }
            self.cancel()
        }
        model.select = { [weak self] index in self?.changeSelection(.select(index)) }
        model.confirm = { [weak self] in self?.commit() }
        model.visibleWindowsChanged = { [weak self] visible in
            guard let self, self.visibleWindows != visible else { return }
            self.visibleWindows = visible
            self.prioritizePreviews()
        }
        let hostingView = NSHostingView(rootView: SwitcherView(model: model))
        // The panel owns its size; image intrinsic sizes must never resize the window.
        hostingView.sizingOptions = []
        panel.contentView = hostingView
        configureSettings()
        if !CommandLine.arguments.contains("--demo") {
            updates.start()
            settings.updates = updates
        }
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.image = IconArtwork.menuImage()
        let menu = NSMenu()
        menu.delegate = self
        enabledMenuItem.title = "启用窗口切换"
        enabledMenuItem.action = #selector(toggleEnabled)
        enabledMenuItem.target = self
        enabledMenuItem.state = settings.enabled ? .on : .off
        menu.addItem(enabledMenuItem)
        menu.addItem(.separator())
        menu.addItem(withTitle: "Window Peek 设置…", action: #selector(showSettings), keyEquivalent: ",").target = self
        menu.addItem(updates.menuItem())
        menu.addItem(withTitle: "查看演示", action: #selector(showDemo), keyEquivalent: "").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "退出 Window Peek", action: #selector(quit), keyEquivalent: "q").target = self
        statusItem.menu = menu

        observers.append(NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] note in
            MainActor.assumeIsolated {
                guard let self, self.session != nil, !self.demoMode,
                      let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                      app.processIdentifier != self.targetPID else { return }
                self.cancel()
            }
        })
        observers.append(NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self] _ in MainActor.assumeIsolated { self?.cancel() } })
        observers.append(NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in MainActor.assumeIsolated { self?.cancel() } })
        clickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            guard let self, self.session != nil,
                  !self.panel.isVisible || !self.panel.frame.contains(NSEvent.mouseLocation) else { return }
            self.cancel()
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self else { return event }
            if event.type != .keyDown {
                if self.session != nil && (!self.panel.isVisible || event.window !== self.panel) { self.cancel() }
                return event
            }
            guard self.demoMode, self.panel.isKeyWindow else { return event }
            switch event.keyCode {
            case 53: self.cancel()
            case 36: self.commit()
            case 123: self.changeSelection(.move(-1))
            case 124: self.changeSelection(.move(1))
            default: return event
            }
            return nil
        }
        if CommandLine.arguments.contains("--demo") {
            showDemo()
        } else {
            refreshPermissions()
            if !settings.accessibility || !settings.screenRecording { showSettings() }
        }
    }

    private func configureSettings() {
        settings.refresh = { [weak self] in self?.refreshPermissions(fresh: true) }
        settings.requestAccessibility = { [weak self] in
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
            _ = AXIsProcessTrustedWithOptions(options)
            self?.openPrivacy("Privacy_Accessibility")
        }
        settings.requestRecording = { [weak self] in
            let granted = CGRequestScreenCaptureAccess()
            if granted { self?.freshPermissions = PermissionService.current() }
            self?.refreshPermissions(fresh: true)
            self?.openPrivacy("Privacy_ScreenCapture")
        }
        settings.restart = { [weak self] in self?.restart() }
        settings.demo = { [weak self] in self?.showDemo() }
        settings.toggle = { [weak self] enabled in
            self?.setEnabled(enabled)
        }
        settings.changeDelay = { [weak self] delay in
            self?.settings.delay = delay
            self?.keyboard.holdDelay = delay
            UserDefaults.standard.set(delay, forKey: "holdDelay")
        }
        settings.changeActivationKey = { [weak self] key in
            guard let self else { return }
            self.settings.activationKey = key
            self.model.activationKey = key
            self.keyboard.activationKey = key
            UserDefaults.standard.set(key.rawValue, forKey: "activationKey")
            self.refreshPermissions()
        }
    }

    @objc private func toggleEnabled() {
        setEnabled(!settings.enabled)
    }

    private func setEnabled(_ enabled: Bool) {
        settings.enabled = enabled
        enabledMenuItem.state = enabled ? .on : .off
        UserDefaults.standard.set(enabled, forKey: "enabled")
        if !enabled { cancel() }
        refreshPermissions()
    }

    private func openPrivacy(_ anchor: String) {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(anchor)") { NSWorkspace.shared.open(url) }
    }

    private func refreshPermissions(fresh: Bool = false) {
        let local = PermissionService.current()
        if local != lastLocalPermissions {
            freshPermissions = local
            lastLocalPermissions = local
        }
        applyPermissions(local: local)
        guard fresh, permissionTask == nil else { return }
        settings.update(\.checkingPermissions, true)
        permissionTask = Task { @MainActor [weak self] in
            do {
                let snapshot = try await PermissionService.fresh()
                guard let self, !Task.isCancelled else { return }
                self.freshPermissions = snapshot
                self.actionError = nil
                self.applyPermissions(local: PermissionService.current())
            } catch {
                guard let self, !Task.isCancelled else { return }
                self.actionError = "权限复查未完成，请重试或重新启动应用"
                self.applyPermissions(local: PermissionService.current())
            }
            self?.settings.update(\.checkingPermissions, false)
            self?.permissionTask = nil
        }
    }

    private func applyPermissions(local: PermissionSnapshot) {
        let permissions = freshPermissions ?? local
        settings.update(\.accessibility, permissions.accessibility)
        settings.update(\.screenRecording, permissions.screenRecording)
        settings.update(\.needsRestart, permissions.requiresRestart(localScreenAccess: local.screenRecording))
        if settings.enabled && permissions.accessibility {
            settings.update(\.running, keyboard.start())
        } else {
            if keyboard.running { keyboard.stop() }
            settings.update(\.running, false)
        }
        updateStatus()
    }

    private func updateStatus() {
        let status: String
        if !settings.enabled { status = "已暂停" }
        else if !settings.accessibility { status = "等待辅助功能权限" }
        else if !settings.running { status = "监听未启动，请重新启动应用" }
        else if settings.needsRestart { status = "录屏已授权，重新启动后生效" }
        else if let actionError { status = actionError }
        else if let captureError { status = captureError }
        else if !settings.screenRecording { status = "切换已就绪 · 开启录屏后可预览" }
        else { status = "已就绪 · 长按 \(settings.activationKey.name)" }
        settings.update(\.status, status)
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        if !CommandLine.arguments.contains("--demo") { refreshPermissions(fresh: true) }
    }

    func menuWillOpen(_ menu: NSMenu) { refreshPermissions(fresh: true) }

    func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow, window === settingsWindow else { return }
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    private func restart() {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(at: Bundle.main.bundleURL, configuration: configuration) { _, error in
            DispatchQueue.main.async {
                if error == nil { NSApp.terminate(nil) }
                else { self.actionError = "重新启动失败，请退出后手动打开"; self.updateStatus() }
            }
        }
    }

    @objc private func showSettings() {
        cancel()
        if settingsWindow == nil {
            let host = NSHostingController(rootView: SettingsView(model: settings))
            let window = NSWindow(contentViewController: host)
            window.title = "Window Peek"
            window.styleMask = [.titled, .closable, .miniaturizable]
            window.isReleasedWhenClosed = false
            window.delegate = self
            window.center()
            settingsWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
        refreshPermissions(fresh: true)
        if refreshTimer == nil {
            let timer = Timer(timeInterval: 2, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated { self?.refreshPermissions() }
            }
            timer.tolerance = 0.5
            RunLoop.main.add(timer, forMode: .common)
            refreshTimer = timer
        }
    }

    private func handle(_ effect: ShortcutState.Effect) {
        switch effect {
        case .show: begin()
        case .cancel: cancel()
        case .commit: commit()
        case .move, .select:
            guard session != nil else { return }
            if model.loading { pendingSelection.append(effect) }
            else { changeSelection(effect) }
        case .arm:
            if pendingSelection.confirmationPending { cancel() }
        }
    }

    private func changeSelection(_ effect: ShortcutState.Effect) {
        switch effect {
        case .move(let delta): model.selection = WindowSelection.moved(model.selection, by: delta, count: model.windows.count)
        case .select(let index): if model.windows.indices.contains(index) { model.selection = index }
        default: break
        }
        prioritizePreviews()
    }

    private func begin() {
        guard let app = NSWorkspace.shared.frontmostApplication, app.processIdentifier != ProcessInfo.processInfo.processIdentifier else {
            keyboard.dismiss()
            return
        }
        cancel(resetKeyboard: false)
        let token = UUID()
        session = token
        targetPID = app.processIdentifier
        model.appName = app.localizedName ?? "当前应用"
        model.appIcon = app.icon
        model.windows = []
        model.selection = 0
        model.loading = true
        // Fast reads and screenshots should appear as one complete panel.
        schedulePresentation(after: 250_000_000)
        let pid = app.processIdentifier
        loadTask = Task { @MainActor [weak self] in
            do {
                let entries = try await cancellableWorker { try WindowService.windows(pid: pid) }
                guard let self, self.session == token, !Task.isCancelled else { return }
                self.model.windows = entries
                self.model.loading = false
                let resolved = self.pendingSelection.resolve(count: entries.count)
                let wasConfirmed = self.pendingSelection.confirmationPending
                self.model.selection = resolved.index
                self.pendingSelection = LoadingSelection()
                self.confirmationTimeout?.invalidate()
                self.confirmationTimeout = nil
                if resolved.shouldCommit { self.commit(); return }
                if wasConfirmed { self.cancel(); return }
                self.presentPanel(count: entries.count, reveal: false)
                let visibleCount = max(1, Int(ceil((self.panel.frame.width - 54) / (self.model.cardWidth + 12))))
                self.initialPreviewIDs = Set(entries.prefix(visibleCount).map(\.id))
                if entries.indices.contains(self.model.selection) {
                    self.initialPreviewIDs.insert(entries[self.model.selection].id)
                }
                self.schedulePresentation(after: 120_000_000)
                guard !entries.isEmpty else { self.revealPanel(); return }
                guard CGPreflightScreenCaptureAccess() else {
                    self.markMissingPreviews()
                    self.revealPanel()
                    self.refreshPermissions(fresh: true)
                    return
                }
                let content = try await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: false)
                guard self.session == token, !Task.isCancelled else { return }
                let windows = Dictionary(content.windows.filter { $0.owningApplication?.processID == pid }
                    .map { ($0.windowID, $0) }, uniquingKeysWith: { first, _ in first })
                let matches = Dictionary(uniqueKeysWithValues: entries.compactMap { item -> (UUID, SCWindow)? in
                    guard let id = item.windowID, let window = windows[id] else { return nil }
                    return (item.id, window)
                })
                WindowService.previewLog.notice("Preview session: pid=\(pid) axWindows=\(entries.count) cgMatched=\(entries.filter { $0.windowID != nil }.count) scWindows=\(windows.count) captureMatched=\(matches.count)")
                self.previewLoader = PreviewScheduler(load: { id in
                    guard let window = matches[id] else { return .unavailable }
                    do {
                        let image = try await WindowService.capture(window)
                        WindowService.previewLog.debug("Capture succeeded: window=\(window.windowID)")
                        return .image(image)
                    }
                    catch {
                        let error = error as NSError
                        if !Task.isCancelled {
                            WindowService.previewLog.error("Capture failed: window=\(window.windowID) domain=\(error.domain, privacy: .public) code=\(error.code) size=\(window.frame.width)x\(window.frame.height)")
                        }
                        if error.domain == SCStreamErrorDomain && error.code == SCStreamError.Code.userDeclined.rawValue {
                            return .denied
                        }
                        return .unavailable
                    }
                }, deliver: { [weak self] id, result in
                    guard let self, self.session == token,
                          let index = self.model.windows.firstIndex(where: { $0.id == id }) else { return }
                    switch result {
                    case .image(let image):
                        self.model.windows[index].image = image
                        self.captureError = nil
                        self.updateStatus()
                    case .unavailable: self.model.windows[index].previewUnavailable = true
                    case .denied:
                        self.captureError = "录屏权限不可用，请检查授权"
                        self.markMissingPreviews()
                        self.previewLoader?.cancel()
                        self.refreshPermissions(fresh: true)
                    }
                    self.revealIfPreviewsReady()
                })
                self.captureError = nil
                self.updateStatus()
                self.prioritizePreviews()
            } catch is CancellationError {
                return
            } catch {
                guard let self, self.session == token, !Task.isCancelled else { return }
                self.model.loading = false
                self.markMissingPreviews()
                self.revealPanel()
                let error = error as NSError
                WindowService.previewLog.error("Preview session failed: domain=\(error.domain, privacy: .public) code=\(error.code)")
                self.captureError = error.domain == SCStreamErrorDomain && error.code == SCStreamError.Code.userDeclined.rawValue
                    ? "录屏权限不可用，请检查授权" : "本次预览读取失败，请重试"
                self.updateStatus()
                self.refreshPermissions(fresh: true)
            }
        }
    }

    private func prioritizePreviews() {
        guard model.windows.indices.contains(model.selection) else { return }
        let selected = model.windows[model.selection].id
        let visible = model.windows.filter {
            visibleWindows.contains($0.id) || (!panel.isVisible && initialPreviewIDs.contains($0.id))
        }.map(\.id)
        previewLoader?.prioritize([selected] + visible)
    }

    private func schedulePresentation(after delay: UInt64) {
        presentationTask?.cancel()
        guard !panel.isVisible else { return }
        let token = session
        presentationTask = Task { @MainActor [weak self] in
            do { try await Task.sleep(nanoseconds: delay) } catch { return }
            guard let self, self.session == token, !Task.isCancelled else { return }
            self.revealPanel()
        }
    }

    private func revealIfPreviewsReady() {
        guard !panel.isVisible, !model.loading,
              model.windows.filter({ initialPreviewIDs.contains($0.id) })
                .allSatisfy({ $0.image != nil || $0.previewUnavailable }) else { return }
        revealPanel()
    }

    private func revealPanel() {
        guard session != nil, !panel.isVisible else { return }
        presentationTask?.cancel()
        presentationTask = nil
        presentPanel(count: model.loading ? 3 : model.windows.count)
    }

    private func markMissingPreviews() {
        for index in model.windows.indices { model.windows[index].previewUnavailable = true }
    }

    private func presentPanel(count: Int, reveal: Bool = true) {
        let screen = NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) } ?? NSScreen.main
        let frame = screen?.visibleFrame ?? CGRect(x: 0, y: 0, width: 1440, height: 900)
        let width = min(frame.width - 48, max(600, CGFloat(min(count, 5)) * 236 + 42))
        let layoutWidth = panel.isVisible ? panel.frame.width : width
        let cardWidth = min(224, max(160, (layoutWidth - 72) / CGFloat(min(max(count, 1), 3))))
        if model.cardWidth != cardWidth { model.cardWidth = cardWidth }
        // A slow enumeration may already have revealed the loading panel. Keep its
        // geometry for this session instead of visibly shrinking/expanding it.
        if !panel.isVisible {
            panel.setFrame(CGRect(x: frame.midX - width / 2, y: frame.midY - 183, width: width, height: 366), display: false, animate: false)
        }
        if reveal {
            panel.contentView?.layoutSubtreeIfNeeded()
            panel.orderFrontRegardless()
        }
    }

    private func commit() {
        guard session != nil else { return }
        if demoMode { cancel(); return }
        if model.loading {
            pendingSelection.confirm()
            if confirmationTimeout == nil {
                confirmationTimeout = Timer.scheduledTimer(withTimeInterval: 1.2, repeats: false) { [weak self] _ in MainActor.assumeIsolated { self?.cancel() } }
            }
            return
        }
        guard model.windows.indices.contains(model.selection), let pid = targetPID,
              NSWorkspace.shared.frontmostApplication?.processIdentifier == pid else { cancel(); return }
        let selected = model.windows[model.selection]
        cancel()
        Task { @MainActor [weak self] in
            if !(await WindowService.raise(selected, pid: pid)) {
                self?.actionError = "窗口未能切换，可能已关闭或不支持辅助功能"
                self?.updateStatus()
                NSSound.beep()
            } else {
                self?.actionError = nil
                self?.updateStatus()
            }
        }
    }

    private func cancel(resetKeyboard: Bool = true) {
        presentationTask?.cancel()
        presentationTask = nil
        initialPreviewIDs.removeAll()
        loadTask?.cancel()
        loadTask = nil
        session = nil
        targetPID = nil
        pendingSelection = LoadingSelection()
        confirmationTimeout?.invalidate()
        confirmationTimeout = nil
        previewLoader?.cancel()
        previewLoader = nil
        visibleWindows.removeAll()
        panel.orderOut(nil)
        panel.acceptsKeyboard = false
        model.windows = [] // Release window snapshots as soon as the switcher closes.
        demoMode = false
        if resetKeyboard { keyboard.dismiss() }
    }

    @objc private func showDemo() {
        cancel()
        demoMode = true
        session = UUID()
        model.appName = "Window Peek · 界面演示"
        model.appIcon = NSImage(systemSymbolName: "macwindow.on.rectangle", accessibilityDescription: nil)
        model.loading = false
        model.selection = 1
        model.windows = ["工作台 — 项目概览", "设计稿 — 窗口预览", "文档 — 快捷键说明", "终端 — 构建结果"].enumerated().map { index, title in
            WindowItem(id: UUID(), element: nil, windowID: nil, title: title, minimized: false, image: DemoImage.make(index: index))
        }
        presentPanel(count: 4)
        panel.acceptsKeyboard = true
        panel.makeKeyAndOrderFront(nil)
    }

    @objc private func quit() { NSApp.terminate(nil) }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showSettings()
        return true
    }
    func applicationWillTerminate(_ notification: Notification) {
        keyboard.stop()
        refreshTimer?.invalidate()
        cancel()
        permissionTask?.cancel()
        for observer in observers {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
            NotificationCenter.default.removeObserver(observer)
        }
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
        if let clickMonitor { NSEvent.removeMonitor(clickMonitor) }
    }
}


private enum CaptureResult {
    case image(NSImage), unavailable, denied
}
