/// Auxiliary AX windows can outlive their panels or belong to floating UI layers.
/// Missing capture data alone must never remove a normal or minimized window.
public enum WindowEligibility {
    public static func includes(isStandard: Bool, isMain: Bool, isFocused: Bool,
                                isModal: Bool, isMinimized: Bool,
                                hasNormalLayerWindow: Bool) -> Bool {
        isStandard || isMain || isFocused || isModal || isMinimized || hasNormalLayerWindow
    }
}
