import XCTest
@testable import SwitcherCore

final class WindowTitleMatchTests: XCTestCase {
    func testChromeOverlappingWindowsWithAccessibilitySuffix() {
        let titles: [String?] = ["Dashboard", "New Tab"]
        XCTAssertEqual(WindowTitleMatch.index(axTitle: "New Tab - Google Chrome",
            candidateTitles: titles, applicationSuffix: " - Google Chrome"), 1)
        XCTAssertNil(WindowTitleMatch.index(axTitle: "New Tab - Google Chrome", candidateTitles: titles))
    }

    func testPageTitleContainingBrowserNameDoesNotCauseWrongMatch() {
        XCTAssertNil(WindowTitleMatch.index(axTitle: "Page - Google Chrome",
            candidateTitles: ["Page", "Page - Google Chrome"], applicationSuffix: " - Google Chrome"))
        XCTAssertEqual(WindowTitleMatch.index(axTitle: "Page - Google Chrome - Google Chrome",
            candidateTitles: ["Page", "Page - Google Chrome"], applicationSuffix: " - Google Chrome"), 1)
    }

    func testDuplicateAndMissingTitlesRemainAmbiguous() {
        XCTAssertNil(WindowTitleMatch.index(axTitle: "New Tab - Google Chrome",
            candidateTitles: ["New Tab", "New Tab"], applicationSuffix: " - Google Chrome"))
        XCTAssertNil(WindowTitleMatch.index(axTitle: "Page", candidateTitles: [nil, nil]))
        XCTAssertNil(WindowTitleMatch.index(axTitle: "Page", candidateTitles: ["Page", "Page"]))
    }

    func testSingleGeometryCandidateStillWorksWithChangingTitle() {
        XCTAssertEqual(WindowTitleMatch.index(axTitle: "Updated page", candidateTitles: ["Old page"]), 0)
        XCTAssertNil(WindowTitleMatch.index(axTitle: "Updated page", candidateTitles: []))
    }
}
