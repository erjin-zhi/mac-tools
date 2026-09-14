import XCTest
@testable import SwitcherCore

final class ShortcutStateTests: XCTestCase {
    func testHoldSelectRelease() {
        var state = ShortcutState()
        XCTAssertEqual(state.modifiers(trigger: true, other: false), [.arm])
        XCTAssertEqual(state.delayElapsed(), [.show])
        XCTAssertEqual(state.keyDown(20).effects, [.select(2)])
        XCTAssertEqual(state.modifiers(trigger: false, other: false), [.commit])
        XCTAssertTrue(state.keyUp(20))
        XCTAssertFalse(state.keyUp(20))
    }
    func testOrdinaryShortcutCancelsUntilRelease() {
        var state = ShortcutState()
        _ = state.modifiers(trigger: true, other: false)
        let copy = state.keyDown(8)
        XCTAssertFalse(copy.consume)
        XCTAssertEqual(copy.effects, [.cancel])
        XCTAssertEqual(state.delayElapsed(), [])
        XCTAssertEqual(state.modifiers(trigger: true, other: false), [])
        XCTAssertFalse(state.keyUp(8))
        XCTAssertEqual(state.modifiers(trigger: false, other: false), [.cancel])
        XCTAssertEqual(state.modifiers(trigger: true, other: false), [.arm])
    }
    func testCommandTabPassesThroughEvenWhenVisible() {
        var state = ShortcutState()
        _ = state.modifiers(trigger: true, other: false)
        _ = state.delayElapsed()
        let tab = state.keyDown(48)
        XCTAssertFalse(tab.consume)
        XCTAssertEqual(tab.effects, [.cancel])
        XCTAssertEqual(state.modifiers(trigger: false, other: false), [.cancel])
    }
    func testBacktickOpensWithoutWaiting() {
        var state = ShortcutState()
        _ = state.modifiers(trigger: true, other: false)
        XCTAssertEqual(state.keyDown(50).effects, [.show, .move(1)])
        XCTAssertEqual(state.delayElapsed(), [])
        XCTAssertEqual(state.keyDown(50).effects, [.move(1)])
    }
    func testEscapeDoesNotCommitOnRelease() {
        var state = ShortcutState()
        _ = state.modifiers(trigger: true, other: false)
        _ = state.delayElapsed()
        XCTAssertEqual(state.keyDown(53).effects, [.cancel])
        XCTAssertEqual(state.modifiers(trigger: false, other: false), [.cancel])
    }
    func testAdditionalModifierCancelsAndDoesNotRearm() {
        var state = ShortcutState()
        _ = state.modifiers(trigger: true, other: false)
        _ = state.delayElapsed()
        XCTAssertEqual(state.modifiers(trigger: true, other: true), [.cancel])
        XCTAssertEqual(state.modifiers(trigger: true, other: false), [])
        XCTAssertEqual(state.delayElapsed(), [])
    }
    func testShortTapAndExternalDismiss() {
        var state = ShortcutState()
        _ = state.modifiers(trigger: true, other: false)
        XCTAssertEqual(state.modifiers(trigger: false, other: false), [.cancel])
        XCTAssertEqual(state.delayElapsed(), [])
        _ = state.modifiers(trigger: true, other: false)
        _ = state.delayElapsed()
        state.dismiss()
        XCTAssertEqual(state.modifiers(trigger: false, other: false), [.cancel])
    }
    func testSelectionWrapsIncludingEmptyList() {
        XCTAssertEqual(WindowSelection.moved(0, by: -1, count: 3), 2)
        XCTAssertEqual(WindowSelection.moved(2, by: 1, count: 3), 0)
        XCTAssertEqual(WindowSelection.moved(0, by: 10, count: 3), 1)
        XCTAssertEqual(WindowSelection.moved(0, by: -1, count: 0), 0)
    }
}
