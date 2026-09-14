import ApplicationServices
import Darwin

/// macOS does not expose a public AX-window-to-CGWindowID bridge. Resolve this SPI
/// at runtime so an OS without the symbol can still use title/geometry matching.
/// The caller must validate the returned ID against the target process's windows.
enum WindowIdentityBridge {
    private typealias GetWindow = @convention(c) (AXUIElement, UnsafeMutablePointer<CGWindowID>) -> AXError
    // Retain the framework handle for the lifetime of the cached function pointer.
    private static let framework = dlopen(
        "/System/Library/Frameworks/ApplicationServices.framework/ApplicationServices", RTLD_LAZY | RTLD_LOCAL)
    private static let getWindow: GetWindow? = {
        guard let framework, let symbol = dlsym(framework, "_AXUIElementGetWindow") else { return nil }
        return unsafeBitCast(symbol, to: GetWindow.self)
    }()

    static func windowID(of element: AXUIElement) -> CGWindowID? {
        guard let getWindow else { return nil }
        var id: CGWindowID = 0
        guard getWindow(element, &id) == .success, id != kCGNullWindowID else { return nil }
        return id
    }
}
