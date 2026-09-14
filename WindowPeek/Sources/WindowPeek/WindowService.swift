import AppKit
import ApplicationServices
import ScreenCaptureKit
import SwitcherCore
import OSLog

struct WindowItem: Identifiable {
    let id: UUID
    let element: AXUIElement?
    let windowID: CGWindowID?
    let title: String
    let minimized: Bool
    var image: NSImage?
    var previewUnavailable = false
}

enum WindowService {
    static let previewLog = Logger(subsystem: "local.windowpeek.app", category: "Preview")
    static func attribute(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else { return nil }
        return value
    }

    static func frame(of element: AXUIElement) -> CGRect {
        var point = CGPoint.zero
        var size = CGSize.zero
        if let raw = attribute(element, kAXPositionAttribute), CFGetTypeID(raw) == AXValueGetTypeID() {
            AXValueGetValue(raw as! AXValue, .cgPoint, &point)
        }
        if let raw = attribute(element, kAXSizeAttribute), CFGetTypeID(raw) == AXValueGetTypeID() {
            AXValueGetValue(raw as! AXValue, .cgSize, &size)
        }
        return CGRect(origin: point, size: size)
    }

    /// Read on a worker thread: a slow accessibility client must not stall the keyboard tap.
    static func windows(pid: pid_t) throws -> [WindowItem] {
        try Task.checkCancellation()
        let app = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(app, 0.35)
        guard let elements = attribute(app, kAXWindowsAttribute) as? [AXUIElement] else { return [] }
        try Task.checkCancellation()
        let info = (CGWindowListCopyWindowInfo(.optionAll, kCGNullWindowID) as? [[String: Any]] ?? [])
            .filter { ($0[kCGWindowOwnerPID as String] as? Int) == Int(pid)
                && ($0[kCGWindowLayer as String] as? Int) == 0 }
        let focused = attribute(app, kAXFocusedWindowAttribute)
        let bundleID = NSRunningApplication(processIdentifier: pid)?.bundleIdentifier
        let titleSuffix = bundleID == "com.google.Chrome" ? " - Google Chrome" : nil
        var entries: [(Int, WindowItem)] = []
        var usedIDs = Set<CGWindowID>()
        for element in elements {
            try Task.checkCancellation()
            AXUIElementSetMessagingTimeout(element, 0.35)
            guard attribute(element, kAXRoleAttribute) as? String == kAXWindowRole else { continue }
            let rect = frame(of: element)
            try Task.checkCancellation()
            guard rect.width > 40, rect.height > 40 else { continue }
            let title = attribute(element, kAXTitleAttribute) as? String ?? ""
            let minimized = attribute(element, kAXMinimizedAttribute) as? Bool ?? false
            try Task.checkCancellation()
            let candidates = info.enumerated().filter { _, record in
                guard let id = record[kCGWindowNumber as String] as? UInt32, !usedIDs.contains(id),
                      let bounds = record[kCGWindowBounds as String] as? NSDictionary,
                      let other = CGRect(dictionaryRepresentation: bounds) else { return false }
                return abs(rect.minX - other.minX) < 3 && abs(rect.minY - other.minY) < 3
                    && abs(rect.width - other.width) < 3 && abs(rect.height - other.height) < 3
            }
            // Ambiguous geometry is intentionally left without an image; focus uses the exact AX object.
            let matchIndex = WindowTitleMatch.index(axTitle: title,
                candidateTitles: candidates.map { $0.element[kCGWindowName as String] as? String },
                applicationSuffix: titleSuffix)
            let match = matchIndex.map { candidates[$0] }
            let windowID = match?.element[kCGWindowNumber as String] as? UInt32
            if windowID == nil {
                previewLog.notice("AX match missing: pid=\(pid) geometryCandidates=\(candidates.count) minimized=\(minimized)")
            }
            if let windowID { usedIDs.insert(windowID) }
            let isFocused = focused.map { CFEqual($0, element) } ?? false
            entries.append((isFocused ? -1 : (match?.offset ?? 10000 + entries.count), WindowItem(
                id: UUID(), element: element, windowID: windowID,
                title: title.isEmpty ? "未命名窗口" : title, minimized: minimized
            )))
        }
        return entries.sorted { $0.0 < $1.0 }.map(\.1)
    }

    static func capture(_ window: SCWindow) async throws -> NSImage {
        let filter = SCContentFilter(desktopIndependentWindow: window)
        let config = SCStreamConfiguration()
        let ratio = min(1.0, 672 / max(window.frame.width, 1), 426 / max(window.frame.height, 1))
        config.width = max(2, Int(window.frame.width * ratio))
        config.height = max(2, Int(window.frame.height * ratio))
        config.showsCursor = false
        config.capturesAudio = false
        config.ignoreShadowsSingleWindow = true
        let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
        try Task.checkCancellation()
        return NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
    }

    static func raise(_ item: WindowItem, pid: pid_t) async -> Bool {
        guard let element = item.element, let app = NSRunningApplication(processIdentifier: pid) else { return false }
        let ready = await Task.detached {
            if attribute(element, kAXMinimizedAttribute) as? Bool == true {
                return AXUIElementSetAttributeValue(element, kAXMinimizedAttribute as CFString, kCFBooleanFalse) == .success
            }
            return true
        }.value
        guard ready else { return false }
        await MainActor.run { _ = app.activate(options: []) }
        return await Task.detached {
            let result = AXUIElementPerformAction(element, kAXRaiseAction as CFString)
            _ = AXUIElementSetAttributeValue(element, kAXMainAttribute as CFString, kCFBooleanTrue)
            _ = AXUIElementSetAttributeValue(element, kAXFocusedAttribute as CFString, kCFBooleanTrue)
            return result == .success
        }.value
    }
}
