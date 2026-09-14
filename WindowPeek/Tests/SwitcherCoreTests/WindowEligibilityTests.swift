import XCTest
@testable import SwitcherCore

final class WindowEligibilityTests: XCTestCase {
    func testInactiveFloatingDialogIsExcluded() {
        XCTAssertFalse(WindowEligibility.includes(isStandard: false, isMain: false,
            isFocused: false, isModal: false, isMinimized: false, hasNormalLayerWindow: false))
    }

    func testNormalAndMinimizedWindowsSurviveMissingCaptureMatch() {
        XCTAssertTrue(WindowEligibility.includes(isStandard: true, isMain: false,
            isFocused: false, isModal: false, isMinimized: false, hasNormalLayerWindow: false))
        XCTAssertTrue(WindowEligibility.includes(isStandard: false, isMain: false,
            isFocused: false, isModal: false, isMinimized: true, hasNormalLayerWindow: false))
    }

    func testActiveAndModalDialogsAreKept() {
        XCTAssertTrue(WindowEligibility.includes(isStandard: false, isMain: true,
            isFocused: false, isModal: false, isMinimized: false, hasNormalLayerWindow: false))
        XCTAssertTrue(WindowEligibility.includes(isStandard: false, isMain: false,
            isFocused: true, isModal: false, isMinimized: false, hasNormalLayerWindow: false))
        XCTAssertTrue(WindowEligibility.includes(isStandard: false, isMain: false,
            isFocused: false, isModal: true, isMinimized: false, hasNormalLayerWindow: false))
    }

    func testOrdinaryDialogWithNormalLayerBackingIsKept() {
        XCTAssertTrue(WindowEligibility.includes(isStandard: false, isMain: false,
            isFocused: false, isModal: false, isMinimized: false, hasNormalLayerWindow: true))
    }
}
