import AppKit
import SwitcherCore

final class KeyboardMonitor {
    var onEffect: ((ShortcutState.Effect) -> Void)?
    var onUserInput: (() -> Void)?
    var holdDelay: TimeInterval = 0.25
    var activationKey: ActivationKey = .command {
        didSet {
            guard activationKey != oldValue else { return }
            timer?.invalidate()
            timer = nil
            onEffect?(.cancel)
            let flags = CGEventSource.flagsState(.combinedSessionState)
            state.resetActivation(held: flags.contains(activationKey.flag))
        }
    }
    private var state = ShortcutState()
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private var timer: Timer?
    var running: Bool { tap != nil }

    func start() -> Bool {
        if tap != nil { return true }
        let mask: CGEventMask = [CGEventType.flagsChanged, .keyDown, .keyUp, .leftMouseDown, .rightMouseDown]
            .reduce(0) { $0 | (1 << $1.rawValue) }
        guard let port = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap,
            options: .defaultTap, eventsOfInterest: mask, callback: { _, type, event, context in
                guard let context else { return Unmanaged.passUnretained(event) }
                let owner = Unmanaged<KeyboardMonitor>.fromOpaque(context).takeUnretainedValue()
                return owner.handle(type, event) ? nil : Unmanaged.passUnretained(event)
            }, userInfo: Unmanaged.passUnretained(self).toOpaque()) else { return false }
        tap = port
        source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, port, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: port, enable: true)
        return true
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        if let tap { CFMachPortInvalidate(tap) }
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        tap = nil
        source = nil
        state = ShortcutState()
        onEffect?(.cancel)
    }

    func dismiss() {
        timer?.invalidate()
        timer = nil
        state.dismiss()
    }

    private func apply(_ effects: [ShortcutState.Effect]) {
        for effect in effects {
            switch effect {
            case .arm:
                timer?.invalidate()
                timer = Timer.scheduledTimer(withTimeInterval: holdDelay, repeats: false) { [weak self] _ in
                    guard let self else { return }
                    self.apply(self.state.delayElapsed())
                }
            case .cancel, .commit, .show:
                timer?.invalidate()
                timer = nil
                onEffect?(effect)
            default: onEffect?(effect)
            }
        }
    }

    private func handle(_ type: CGEventType, _ event: CGEvent) -> Bool {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            dismiss()
            onEffect?(.cancel)
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return false
        }
        switch type {
        case .flagsChanged:
            onUserInput?()
            let flags = event.flags
            apply(state.modifiers(flags: flags, activationKey: activationKey))
        case .keyDown:
            onUserInput?()
            let result = state.keyDown(Int(event.getIntegerValueField(.keyboardEventKeycode)))
            apply(result.effects)
            return result.consume
        case .keyUp:
            return state.keyUp(Int(event.getIntegerValueField(.keyboardEventKeycode)))
        case .leftMouseDown, .rightMouseDown:
            onUserInput?()
            // Defer to the panel's click handler when the click falls inside its frame.
            if state.phase == .waiting { dismiss(); onEffect?(.cancel) }
        default: break
        }
        return false
    }
}
