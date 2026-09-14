import AppKit
import SwitcherCore

enum PermissionService {
    static func current() -> PermissionSnapshot {
        PermissionSnapshot(accessibility: AXIsProcessTrusted(), screenRecording: CGPreflightScreenCaptureAccess())
    }

    // The same signed executable checks in a fresh process, without asking for access or
    // capturing content. This avoids treating this process's cached denial as a fresh result.
    static func fresh() async throws -> PermissionSnapshot {
        guard let executable = Bundle.main.executableURL else { throw CocoaError(.fileNoSuchFile) }
        return try await cancellableWorker {
            let process = Process()
            let output = Pipe()
            process.executableURL = executable
            process.arguments = ["--permission-probe"]
            process.standardOutput = output
            process.standardError = FileHandle.nullDevice
            try process.run()
            let deadline = Date().addingTimeInterval(4)
            while process.isRunning {
                if Task.isCancelled || Date() > deadline {
                    process.terminate()
                    throw CancellationError()
                }
                Thread.sleep(forTimeInterval: 0.025)
            }
            guard process.terminationStatus == 0 else { throw CocoaError(.executableRuntimeMismatch) }
            let data = output.fileHandleForReading.readDataToEndOfFile()
            return try JSONDecoder().decode(PermissionSnapshot.self, from: data)
        }
    }
}
