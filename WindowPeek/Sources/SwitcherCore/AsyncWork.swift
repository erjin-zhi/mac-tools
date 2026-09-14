/// Cancellation reaches the worker; synchronous operations cooperate at checkpoints.
public func cancellableWorker<T>(_ operation: @escaping @Sendable () throws -> T) async throws -> T {
    let worker = Task.detached(priority: .userInitiated) {
        try Task.checkCancellation()
        return try operation()
    }
    return try await withTaskCancellationHandler {
        let result = try await worker.value
        try Task.checkCancellation()
        return result
    } onCancel: {
        worker.cancel()
    }
}

/// Only requested items are loaded; pending work follows the latest visible/selected order.
@MainActor
public final class PreviewScheduler<ID: Hashable, Output> {
    private let limit: Int
    private let load: (ID) async -> Output
    private let deliver: (ID, Output) -> Void
    private var order: [ID] = []
    private var tasks: [ID: Task<Void, Never>] = [:]
    private var completed: Set<ID> = []
    private var stopped = false

    public init(limit: Int = 2, load: @escaping (ID) async -> Output, deliver: @escaping (ID, Output) -> Void) {
        self.limit = max(1, limit)
        self.load = load
        self.deliver = deliver
    }

    public func prioritize(_ ids: [ID]) {
        guard !stopped else { return }
        var seen: Set<ID> = []
        order = ids.filter { seen.insert($0).inserted }
        pump()
    }

    public func cancel() {
        stopped = true
        tasks.values.forEach { $0.cancel() }
        tasks.removeAll()
        order.removeAll()
    }

    private func pump() {
        while !stopped && tasks.count < limit,
              let id = order.first(where: { !completed.contains($0) && tasks[$0] == nil }) {
            let load = self.load
            tasks[id] = Task { [weak self] in
                let output = await load(id)
                guard !Task.isCancelled, let self, !self.stopped else { return }
                self.tasks[id] = nil
                self.completed.insert(id)
                self.deliver(id, output)
                self.pump()
            }
        }
    }
}
