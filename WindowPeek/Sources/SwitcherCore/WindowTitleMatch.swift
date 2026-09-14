/// Disambiguates windows whose geometry already matches. Never guesses between duplicate titles.
public enum WindowTitleMatch {
    public static func index(axTitle: String, candidateTitles: [String?], applicationSuffix: String? = nil) -> Int? {
        guard !axTitle.isEmpty else { return candidateTitles.count == 1 ? 0 : nil }
        var matching = Set(candidateTitles.indices.filter { candidateTitles[$0] == axTitle })
        if let suffix = applicationSuffix, !suffix.isEmpty {
            let suffixed = candidateTitles.indices.filter { index in
                guard let title = candidateTitles[index], !title.isEmpty else { return false }
                return axTitle == title + suffix
            }
            matching.formUnion(suffixed)
        }
        if !matching.isEmpty { return matching.count == 1 ? matching.first : nil }
        return candidateTitles.count == 1 ? 0 : nil
    }
}
