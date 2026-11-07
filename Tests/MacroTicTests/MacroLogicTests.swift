import XCTest
@testable import MacroTic

/// Unit tests for the pure, side-effect-free domain logic.
/// These intentionally avoid MacroStore (which reads/writes the real ~/Library macros.json).
final class MacroLogicTests: XCTestCase {

    // MARK: - ShortcutKeyMap.parse

    func testParseSymbolShortcut() {
        let parsed = ShortcutKeyMap.parse("⌘⇧C")
        XCTAssertNotNil(parsed)
        XCTAssertEqual(parsed?.keyCode, 8) // C
        XCTAssertTrue(parsed!.flags.contains(.maskCommand))
        XCTAssertTrue(parsed!.flags.contains(.maskShift))
    }

    func testParseLegacyWordShortcut() {
        let parsed = ShortcutKeyMap.parse("cmd+Return")
        XCTAssertEqual(parsed?.keyCode, 36)
        XCTAssertTrue(parsed!.flags.contains(.maskCommand))
    }

    func testParsePlusSeparatedSingleLetter() {
        let parsed = ShortcutKeyMap.parse("⌘+c")
        XCTAssertEqual(parsed?.keyCode, 8)
        XCTAssertTrue(parsed!.flags.contains(.maskCommand))
    }

    func testParseRawKeyCodeFallback() {
        XCTAssertEqual(ShortcutKeyMap.parse("Key99")?.keyCode, 99)
    }

    func testParseEmptyIsNil() {
        XCTAssertNil(ShortcutKeyMap.parse(""))
        XCTAssertNil(ShortcutKeyMap.parse("   "))
    }

    func testShortcutStringRoundTrips() {
        let s = ShortcutKeyMap.shortcutString(keyCode: 8, flags: [.maskCommand, .maskShift])
        let parsed = ShortcutKeyMap.parse(s)
        XCTAssertEqual(parsed?.keyCode, 8)
        XCTAssertTrue(parsed!.flags.contains(.maskCommand))
        XCTAssertTrue(parsed!.flags.contains(.maskShift))
    }

    // MARK: - MacroStep.configurationIssue

    func testClickWithoutCoordinatesIsUnconfigured() {
        let step = MacroStep(kind: .click)
        XCTAssertFalse(step.isConfigured)
        XCTAssertNotNil(step.configurationIssue)
    }

    func testClickWithCoordinatesIsConfigured() {
        var step = MacroStep(kind: .click)
        step.clickX = 100
        step.clickY = 200
        XCTAssertTrue(step.isConfigured)
    }

    func testEmptyShortcutAndTextAreUnconfigured() {
        XCTAssertFalse(MacroStep(kind: .keyShortcut).isConfigured)
        XCTAssertFalse(MacroStep(kind: .typeText).isConfigured)
        XCTAssertFalse(MacroStep(kind: .launchApp).isConfigured)
    }

    func testDelayAndScrollAreAlwaysConfigured() {
        XCTAssertTrue(MacroStep(kind: .delay).isConfigured)
        XCTAssertTrue(MacroStep(kind: .scroll).isConfigured)
    }

    // MARK: - Codable backward compatibility

    func testMacroDecodesWithMissingOptionalFields() throws {
        let json = """
        {"id":"\(UUID().uuidString)","name":"M","details":"","iconName":"x","steps":[],"createdAt":"2024-01-01T00:00:00Z","executionCount":0}
        """.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let macro = try decoder.decode(Macro.self, from: json)
        XCTAssertEqual(macro.intervalBetweenSteps, 0.5) // default
        XCTAssertEqual(macro.repeatCount, 1)            // default
        XCTAssertFalse(macro.isFavorite)
        XCTAssertFalse(macro.isLocked)
    }

    func testMacroDropsUnknownStepKindsLossily() throws {
        let json = """
        {"id":"\(UUID().uuidString)","name":"M","details":"","iconName":"x","createdAt":"2024-01-01T00:00:00Z","executionCount":0,
        "steps":[{"id":"\(UUID().uuidString)","kind":"openURL","value":"https://x"},
                 {"id":"\(UUID().uuidString)","kind":"click","clickX":10,"clickY":20}]}
        """.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let macro = try decoder.decode(Macro.self, from: json)
        XCTAssertEqual(macro.steps.count, 1) // unknown "openURL" dropped, "click" kept
        XCTAssertEqual(macro.steps.first?.kind, .click)
    }

    func testRepeatCountClampedToAtLeastOne() throws {
        let json = """
        {"id":"\(UUID().uuidString)","name":"M","details":"","iconName":"x","steps":[],"repeatCount":0,"createdAt":"2024-01-01T00:00:00Z","executionCount":0}
        """.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let macro = try decoder.decode(Macro.self, from: json)
        XCTAssertEqual(macro.repeatCount, 1)
    }

    // MARK: - MacroDraft selection & reordering

    private func draftWithSteps(_ n: Int) -> (MacroDraft, [UUID]) {
        let draft = MacroDraft()
        var ids: [UUID] = []
        for _ in 0..<n {
            let step = MacroStep(kind: .delay)
            draft.steps.append(step)
            ids.append(step.id)
        }
        return (draft, ids)
    }

    func testMoveSelectedUpShiftsContiguousBlock() {
        let (draft, ids) = draftWithSteps(4) // [0,1,2,3]
        draft.selectedStepIDs = [ids[2], ids[3]]
        draft.moveSelectedUp()
        XCTAssertEqual(draft.steps.map(\.id), [ids[0], ids[2], ids[3], ids[1]])
    }

    func testMoveSelectedDownShiftsContiguousBlock() {
        let (draft, ids) = draftWithSteps(4) // [0,1,2,3]
        draft.selectedStepIDs = [ids[0], ids[1]]
        draft.moveSelectedDown()
        XCTAssertEqual(draft.steps.map(\.id), [ids[2], ids[0], ids[1], ids[3]])
    }

    func testMoveBeforeReordersStep() {
        let (draft, ids) = draftWithSteps(3) // [0,1,2]
        draft.move(ids[2], before: ids[0])
        XCTAssertEqual(draft.steps.map(\.id), [ids[2], ids[0], ids[1]])
    }

    func testRemoveSelectedClearsSelection() {
        let (draft, ids) = draftWithSteps(3)
        draft.selectedStepIDs = [ids[0], ids[1]]
        draft.removeSelected()
        XCTAssertEqual(draft.steps.count, 1)
        XCTAssertTrue(draft.selectedStepIDs.isEmpty)
    }

    func testSelectAllAndToggle() {
        let (draft, ids) = draftWithSteps(3)
        draft.selectAll()
        XCTAssertTrue(draft.allSelected)
        draft.toggleSelection(ids[0])
        XCTAssertFalse(draft.allSelected)
        XCTAssertEqual(draft.selectedStepIDs.count, 2)
    }

    func testDraftValidity() {
        let draft = MacroDraft()
        XCTAssertFalse(draft.isValid) // no name, no steps
        draft.name = "Teste"
        XCTAssertFalse(draft.isValid) // still no steps
        draft.steps.append(MacroStep(kind: .delay))
        XCTAssertTrue(draft.isValid)
    }
}
