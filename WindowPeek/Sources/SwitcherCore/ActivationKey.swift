import CoreGraphics

public enum ActivationKey: String, CaseIterable, Identifiable {
    case command, option, control, shift

    public var id: String { rawValue }
    public init(savedValue: String?) {
        self = savedValue.flatMap(Self.init(rawValue:)) ?? .command
    }
    public var name: String {
        switch self {
        case .command: return "Command"
        case .option: return "Option"
        case .control: return "Control"
        case .shift: return "Shift"
        }
    }
    public var symbol: String {
        switch self {
        case .command: return "⌘"
        case .option: return "⌥"
        case .control: return "⌃"
        case .shift: return "⇧"
        }
    }
    public var flag: CGEventFlags {
        switch self {
        case .command: return .maskCommand
        case .option: return .maskAlternate
        case .control: return .maskControl
        case .shift: return .maskShift
        }
    }
}
