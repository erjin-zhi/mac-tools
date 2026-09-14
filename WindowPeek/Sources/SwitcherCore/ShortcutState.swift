import CoreGraphics

/// Pure shortcut state machine. Unrelated shortcuts always pass through.
public struct ShortcutState {
    public enum Effect: Equatable {
        case arm, cancel, show, commit, move(Int), select(Int)
    }
    public enum Phase: Equatable { case idle, waiting, visible, blocked }
    public private(set) var phase: Phase = .idle
    private var triggerHeld = false
    private var consumedKeys: Set<Int> = []
    public init() {}

    public mutating func modifiers(flags: CGEventFlags, activationKey: ActivationKey) -> [Effect] {
        let modifiers: CGEventFlags = [.maskCommand, .maskAlternate, .maskControl, .maskShift, .maskSecondaryFn]
        return self.modifiers(trigger: flags.contains(activationKey.flag),
            other: !flags.intersection(modifiers.subtracting(activationKey.flag)).isEmpty)
    }

    /// Changing settings cancels the current gesture without losing suppressed key-up events.
    public mutating func resetActivation(held: Bool) {
        triggerHeld = held
        phase = held ? .blocked : .idle
    }

    public mutating func modifiers(trigger: Bool, other: Bool) -> [Effect] {
        let wasHeld = triggerHeld
        triggerHeld = trigger
        if !trigger {
            let previous = phase
            phase = .idle
            return previous == .visible ? [.commit] : [.cancel]
        }
        if other {
            let needsCancel = phase == .waiting || phase == .visible
            phase = .blocked
            return needsCancel ? [.cancel] : []
        }
        if !wasHeld {
            phase = .waiting
            return [.arm]
        }
        return []
    }

    public mutating func delayElapsed() -> [Effect] {
        guard phase == .waiting else { return [] }
        phase = .visible
        return [.show]
    }

    public mutating func keyDown(_ key: Int) -> (consume: Bool, effects: [Effect]) {
        guard triggerHeld else { return (false, []) }
        if (phase == .waiting || phase == .visible), key == 50 {
            let needsShow = phase == .waiting
            phase = .visible
            consumedKeys.insert(key)
            return (true, (needsShow ? [.show] : []) + [.move(1)])
        }
        if phase == .visible {
            let digits = [18: 0, 19: 1, 20: 2, 21: 3, 23: 4, 22: 5, 26: 6, 28: 7, 25: 8]
            let effect: Effect?
            if let index = digits[key] { effect = .select(index) }
            else if key == 123 { effect = .move(-1) }
            else if key == 124 { effect = .move(1) }
            else if key == 53 { effect = .cancel; phase = .blocked }
            else if key == 36 { effect = .commit; phase = .blocked }
            else { effect = nil }
            if let effect {
                consumedKeys.insert(key)
                return (true, [effect])
            }
        }
        let shouldCancel = phase == .visible || phase == .waiting
        phase = .blocked
        return (false, shouldCancel ? [.cancel] : [])
    }

    public mutating func keyUp(_ key: Int) -> Bool {
        consumedKeys.remove(key) != nil
    }

    public mutating func dismiss() {
        phase = triggerHeld ? .blocked : .idle
    }
}

public enum WindowSelection {
    public static func moved(_ current: Int, by delta: Int, count: Int) -> Int {
        guard count > 0 else { return 0 }
        return ((current + delta) % count + count) % count
    }
}
