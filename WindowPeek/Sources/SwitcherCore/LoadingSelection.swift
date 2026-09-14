/// Retains input while the accessibility window list is being read.
public struct LoadingSelection {
    private var actions: [ShortcutState.Effect] = []
    public private(set) var confirmationPending = false
    public init() {}
    public mutating func append(_ action: ShortcutState.Effect) { actions.append(action) }
    public mutating func confirm() { confirmationPending = true }
    public func resolve(count: Int) -> (index: Int, shouldCommit: Bool) {
        var index = 0
        for action in actions {
            switch action {
            case .move(let delta): index = WindowSelection.moved(index, by: delta, count: count)
            case .select(let target): if (0..<count).contains(target) { index = target }
            default: break
            }
        }
        return (index, count > 0 && confirmationPending)
    }
}
