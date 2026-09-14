import XCTest
@testable import SwitcherCore

final class WindowIdentityMatchTests: XCTestCase {
    func testSameTitleAndGeometryMatchInEveryForegroundOrder() {
        for order: [UInt32] in [[11, 22, 33], [22, 11, 33], [33, 22, 11]] {
            for id: UInt32 in [11, 22, 33] {
                let index = WindowIdentityMatch.index(windowID: id, candidateIDs: order) {
                    XCTFail("Exact ID must not depend on title or foreground order")
                    return nil
                }
                XCTAssertEqual(index.map { order[$0] }, id)
            }
        }
    }

    func testMissingBridgeUsesUniqueTitleFallback() {
        XCTAssertEqual(WindowIdentityMatch.index(windowID: nil, candidateIDs: [11, 22]) {
            WindowTitleMatch.index(axTitle: "Page - Google Chrome",
                candidateTitles: ["Other", "Page"], applicationSuffix: " - Google Chrome")
        }, 1)
        XCTAssertNil(WindowIdentityMatch.index(windowID: nil, candidateIDs: [11, 22]) {
            WindowTitleMatch.index(axTitle: "Page", candidateTitles: ["Page", "Page"])
        })
    }

    func testStaleForeignOrAlreadyUsedIDDoesNotSelectAnotherWindow() {
        for id: UInt32 in [0, 33] {
            XCTAssertNil(WindowIdentityMatch.index(windowID: id, candidateIDs: [11, 22]) {
                XCTFail("Known ID must not fall back to another window")
                return 0
            })
        }
    }

    func testInvalidCandidatesAndFallbackAreRejected() {
        XCTAssertNil(WindowIdentityMatch.index(windowID: 11, candidateIDs: [11, 11]) { 0 })
        XCTAssertNil(WindowIdentityMatch.index(windowID: nil, candidateIDs: [11]) { 3 })
        XCTAssertNil(WindowIdentityMatch.index(windowID: nil, candidateIDs: []) { 0 })
    }
}
