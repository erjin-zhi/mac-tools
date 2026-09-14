import AppKit
import ApplicationServices
import ScreenCaptureKit
import SwiftUI
import SwitcherCore

/// Explicit developer check: no window titles, URLs or screenshots are written to disk.
@main
struct PreviewCheck {
    struct Failure: Error, CustomStringConvertible {
        let description: String
        init(_ description: String) { self.description = description }
    }

    @MainActor
    static func main() async {
        do {
            NSApplication.shared.setActivationPolicy(.accessory)
            try checkLayout()
            if CommandLine.arguments.contains("--chrome") { try await checkChrome() }
        } catch {
            FileHandle.standardError.write(Data("Preview check failed: \(error)\n".utf8))
            exit(1)
        }
    }

    @MainActor
    private static func checkLayout() throws {
        for (count, width) in [(1, 600.0), (3, 750.0), (9, 1222.0)] {
            let model = SwitcherModel()
            let panel = SwitcherPanel()
            let host = NSHostingView(rootView: SwitcherView(model: model))
            host.sizingOptions = []
            panel.contentView = host
            let expected = CGRect(x: 100, y: 100, width: width, height: 330)
            panel.setFrame(expected, display: false, animate: false)
            func settle() throws {
                RunLoop.main.run(until: Date().addingTimeInterval(0.1))
                host.layoutSubtreeIfNeeded()
                guard panel.frame == expected else { throw Failure("Panel resized during content delivery") }
            }
            try settle()
            model.loading = false
            model.windows = (0..<count).map {
                WindowItem(id: UUID(), element: nil, windowID: nil, title: "Window \($0 + 1)", minimized: false)
            }
            try settle()
            for index in model.windows.indices {
                model.windows[index].image = DemoImage.make(index: index % 4)
                try settle()
            }
            model.windows = []
            try settle()
            print("Layout: \(count) windows, loading/cards/images/empty, stable frame")
        }
    }

    @MainActor
    private static func checkChrome() async throws {
        guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: "com.google.Chrome").first else {
            throw Failure("Open Chrome with at least two normal windows first")
        }
        let pid = app.processIdentifier
        let previousApp = NSWorkspace.shared.frontmostApplication
        let initial = try WindowService.windows(pid: pid)
        guard initial.count >= 2, initial.allSatisfy({ $0.windowID != nil && $0.element != nil && !$0.minimized }) else {
            throw Failure("Use at least two non-minimized Chrome windows with resolvable IDs")
        }
        func validateIdentity(_ entries: [WindowItem], requireAll: Bool) throws {
            guard entries.count == initial.count else { throw Failure("Window count changed") }
            for entry in entries {
                guard let element = entry.element,
                      let original = initial.first(where: { CFEqual($0.element!, element) }) else {
                    throw Failure("AX window identity changed")
                }
                if requireAll || entry.windowID != nil {
                    guard entry.windowID == original.windowID else { throw Failure("Preview ID belongs to another AX window") }
                }
            }
        }
        // A missing bridge must never turn ambiguity into a wrong preview.
        try validateIdentity(WindowService.windows(pid: pid, identify: { _ in nil }), requireAll: false)
        for target in initial {
            let mixed = try WindowService.windows(pid: pid, identify: { element in
                CFEqual(element, target.element!) ? nil : WindowIdentityBridge.windowID(of: element)
            })
            try validateIdentity(mixed, requireAll: true)
        }
        print("Chrome fallback: unavailable bridge and mixed exact/fallback IDs verified")

        func restore() async {
            for window in initial.reversed() { _ = await WindowService.raise(window, pid: pid) }
            if let previousApp { _ = previousApp.activate(options: []) }
        }
        do {
            for (index, target) in initial.enumerated() {
                guard await WindowService.raise(target, pid: pid) else { throw Failure("Could not focus target window") }
                try await Task.sleep(nanoseconds: 350_000_000)
                let entries = try WindowService.windows(pid: pid)
                guard entries.first?.windowID == target.windowID else { throw Failure("Target did not become focused") }
                try validateIdentity(entries, requireAll: true)
                let content = try await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: false)
                for entry in entries {
                    guard let window = content.windows.first(where: {
                        $0.windowID == entry.windowID && $0.owningApplication?.processID == pid
                    }) else { throw Failure("Window is missing from capture content") }
                    let image = try await WindowService.capture(window)
                    guard image.size.width > 0, image.size.height > 0 else { throw Failure("Empty capture") }
                }
                print("Chrome focus \(index + 1)/\(initial.count): all \(entries.count) captures succeeded, AX identities stable")
            }
            await restore()
        } catch {
            await restore()
            throw error
        }
    }
}
