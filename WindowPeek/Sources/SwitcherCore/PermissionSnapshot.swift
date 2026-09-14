public struct PermissionSnapshot: Codable, Equatable {
    public let accessibility: Bool
    public let screenRecording: Bool
    public init(accessibility: Bool, screenRecording: Bool) {
        self.accessibility = accessibility
        self.screenRecording = screenRecording
    }
    public func requiresRestart(localScreenAccess: Bool) -> Bool {
        screenRecording && !localScreenAccess
    }
}
