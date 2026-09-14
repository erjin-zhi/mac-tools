import CoreGraphics
import XCTest
@testable import SwitcherCore

final class ActivationKeyTests: XCTestCase {
    func testDefaultAndSavedChoices() {
        XCTAssertEqual(ActivationKey(savedValue: nil), .command)
        XCTAssertEqual(ActivationKey(savedValue: "removed-option"), .command)
        for key in ActivationKey.allCases {
            XCTAssertEqual(ActivationKey(savedValue: key.rawValue), key)
        }
    }

    func testEachActivationKeySelectsAndCommits() {
        for key in ActivationKey.allCases {
            var state = ShortcutState()
            XCTAssertEqual(state.modifiers(flags: key.flag, activationKey: key), [.arm], key.name)
            XCTAssertEqual(state.delayElapsed(), [.show])
            let selection = state.keyDown(19)
            XCTAssertTrue(selection.consume)
            XCTAssertEqual(selection.effects, [.select(1)])
            XCTAssertEqual(state.modifiers(flags: [], activationKey: key), [.commit])
            XCTAssertTrue(state.keyUp(19))
        }
    }

    func testNonSelectedModifiersDoNotActivate() {
        for selected in ActivationKey.allCases {
            for pressed in ActivationKey.allCases where pressed != selected {
                var state = ShortcutState()
                XCTAssertEqual(state.modifiers(flags: pressed.flag, activationKey: selected), [.cancel])
                XCTAssertEqual(state.delayElapsed(), [])
                XCTAssertFalse(state.keyDown(19).consume)
            }
        }
    }

    func testAdditionalModifiersCancelForEveryChoice() {
        for selected in ActivationKey.allCases {
            for extra in ActivationKey.allCases where extra != selected {
                var state = ShortcutState()
                _ = state.modifiers(flags: selected.flag, activationKey: selected)
                _ = state.delayElapsed()
                XCTAssertEqual(state.modifiers(flags: selected.flag.union(extra.flag), activationKey: selected), [.cancel])
                XCTAssertFalse(state.keyDown(19).consume)
                XCTAssertEqual(state.modifiers(flags: selected.flag, activationKey: selected), [])
                XCTAssertEqual(state.delayElapsed(), [])
            }
        }
    }

    func testChangingActivationWhileHeldRequiresReleaseAndPreservesKeyUp() {
        var state = ShortcutState()
        _ = state.modifiers(flags: .maskCommand, activationKey: .command)
        _ = state.delayElapsed()
        XCTAssertTrue(state.keyDown(19).consume)
        state.resetActivation(held: true)
        XCTAssertEqual(state.delayElapsed(), [])
        XCTAssertEqual(state.modifiers(flags: .maskAlternate, activationKey: .option), [])
        XCTAssertTrue(state.keyUp(19))
        XCTAssertEqual(state.modifiers(flags: [], activationKey: .option), [.cancel])
        XCTAssertEqual(state.modifiers(flags: .maskAlternate, activationKey: .option), [.arm])
    }

    func testTypingDuringDelayStillPassesThroughForEveryChoice() {
        for key in ActivationKey.allCases {
            var state = ShortcutState()
            _ = state.modifiers(flags: key.flag, activationKey: key)
            XCTAssertFalse(state.keyDown(8).consume)
            XCTAssertEqual(state.delayElapsed(), [])
            XCTAssertEqual(state.modifiers(flags: [], activationKey: key), [.cancel])
        }
    }
}
