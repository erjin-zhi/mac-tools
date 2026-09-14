import Foundation
import XCTest
@testable import SwitcherCore

final class AsyncRegressionTests: XCTestCase {
    func testQuickReleaseKeepsQueuedSelection() {
        var pending = LoadingSelection()
        pending.append(.move(1))
        pending.append(.select(2))
        pending.append(.move(1))
        pending.confirm()
        let result = pending.resolve(count: 5)
        XCTAssertEqual(result.index, 3)
        XCTAssertTrue(result.shouldCommit)
    }

    func testEmptyListAndCancelledIntentNeverCommit() {
        var pending = LoadingSelection()
        pending.append(.select(8))
        pending.confirm()
        XCTAssertFalse(pending.resolve(count: 0).shouldCommit)
        XCTAssertEqual(pending.resolve(count: 2).index, 0)
        pending = LoadingSelection()
        XCTAssertFalse(pending.resolve(count: 5).shouldCommit)
        XCTAssertEqual(pending.resolve(count: 5).index, 0)
    }

    func testWorkerReceivesOuterTaskCancellation() async {
        let started = expectation(description: "worker started")
        let stopped = expectation(description: "worker stopped")
        let task = Task {
            try await cancellableWorker {
                started.fulfill()
                defer { stopped.fulfill() }
                let deadline = Date().addingTimeInterval(2)
                while Date() < deadline {
                    try Task.checkCancellation()
                    Thread.sleep(forTimeInterval: 0.001)
                }
                return 1
            }
        }
        await fulfillment(of: [started], timeout: 1)
        task.cancel()
        do { _ = try await task.value; XCTFail("Cancelled work must not return a result") }
        catch { XCTAssertTrue(error is CancellationError) }
        await fulfillment(of: [stopped], timeout: 0.5)
    }

    @MainActor
    func testPreviewConcurrencyAndChangedSelectionPriority() async {
        let gate = PreviewGate()
        var results: [Int] = []
        let scheduler = PreviewScheduler<Int, Int>(limit: 2, load: { await gate.load($0) }, deliver: { id, _ in results.append(id) })
        scheduler.prioritize([1, 2, 3, 4])
        await settle { gate.started.count == 2 }
        XCTAssertEqual(gate.started, [1, 2])
        scheduler.prioritize([9, 2, 1])
        gate.finish(1)
        await settle { gate.started.count == 3 }
        XCTAssertEqual(gate.started, [1, 2, 9])
        XCTAssertEqual(gate.peak, 2)
        scheduler.cancel()
        gate.finishAll()
        for _ in 0..<10 { await Task.yield() }
        XCTAssertEqual(results, [1])
        XCTAssertFalse(gate.started.contains(3))
    }

    @MainActor
    func testPreviewCancellationDiscardsLateResultsAndDeduplicates() async {
        let gate = PreviewGate()
        var deliveries = 0
        let scheduler = PreviewScheduler<Int, Int>(load: { await gate.load($0) }, deliver: { _, _ in deliveries += 1 })
        scheduler.prioritize([1, 1, 2, 3])
        await settle { gate.started.count == 2 }
        scheduler.cancel()
        scheduler.prioritize([4])
        gate.finishAll()
        for _ in 0..<10 { await Task.yield() }
        XCTAssertEqual(deliveries, 0)
        XCTAssertEqual(gate.started, [1, 2])
    }

    func testFreshPermissionDistinguishesRestartFromDenial() throws {
        let granted = PermissionSnapshot(accessibility: true, screenRecording: true)
        XCTAssertTrue(granted.requiresRestart(localScreenAccess: false))
        XCTAssertFalse(granted.requiresRestart(localScreenAccess: true))
        let denied = PermissionSnapshot(accessibility: true, screenRecording: false)
        XCTAssertFalse(denied.requiresRestart(localScreenAccess: false))
        XCTAssertFalse(denied.requiresRestart(localScreenAccess: true))
        let roundTrip = try JSONDecoder().decode(PermissionSnapshot.self, from: JSONEncoder().encode(granted))
        XCTAssertEqual(roundTrip, granted)
    }

    @MainActor
    private func settle(_ predicate: () -> Bool) async {
        for _ in 0..<1000 {
            if predicate() { return }
            await Task.yield()
        }
        XCTFail("Async operation did not reach expected state")
    }
}

@MainActor
private final class PreviewGate {
    var started: [Int] = []
    var peak = 0
    private var continuations: [Int: CheckedContinuation<Int, Never>] = [:]
    func load(_ id: Int) async -> Int {
        await withCheckedContinuation { continuation in
            started.append(id)
            continuations[id] = continuation
            peak = max(peak, continuations.count)
        }
    }
    func finish(_ id: Int) { continuations.removeValue(forKey: id)?.resume(returning: id) }
    func finishAll() { for id in Array(continuations.keys) { finish(id) } }
}
