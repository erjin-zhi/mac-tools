/// Candidates must already be restricted to the target process and unused IDs.
public enum WindowIdentityMatch {
    public static func index(windowID: UInt32?, candidateIDs: [UInt32], fallback: () -> Int?) -> Int? {
        if let windowID {
            // An explicit but stale/unavailable ID must not fall back to a different window.
            guard windowID != 0 else { return nil }
            let matches = candidateIDs.indices.filter { candidateIDs[$0] == windowID }
            return matches.count == 1 ? matches.first : nil
        }
        guard let index = fallback(), candidateIDs.indices.contains(index) else { return nil }
        return index
    }
}
