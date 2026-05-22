import XCTest
import CoreGraphics
@testable import Clicker

final class CGEventMappingTests: XCTestCase {
    func test_mouseMove_isMapped() throws {
        let cg = try XCTUnwrap(CGEvent(mouseEventSource: nil, mouseType: .mouseMoved,
                                       mouseCursorPosition: CGPoint(x: 50, y: 60),
                                       mouseButton: .left))
        let mapped = try XCTUnwrap(RecordedEvent.from(cgEvent: cg, type: .mouseMoved, relativeTime: 0.123))
        guard case .mouseMove(let t, let x, let y) = mapped else { return XCTFail("wrong case") }
        XCTAssertEqual(t, 0.123, accuracy: 1e-9)
        XCTAssertEqual(x, 50)
        XCTAssertEqual(y, 60)
    }

    func test_leftMouseDown_isMapped() throws {
        let cg = try XCTUnwrap(CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown,
                                       mouseCursorPosition: CGPoint(x: 5, y: 6),
                                       mouseButton: .left))
        cg.setIntegerValueField(.mouseEventClickState, value: 2)
        let mapped = try XCTUnwrap(RecordedEvent.from(cgEvent: cg, type: .leftMouseDown, relativeTime: 1.0))
        guard case .mouseDown(_, let btn, _, _, let clicks) = mapped else { return XCTFail("wrong case") }
        XCTAssertEqual(btn, .left)
        XCTAssertEqual(clicks, 2)
    }

    func test_keyDown_isMapped() throws {
        let cg = try XCTUnwrap(CGEvent(keyboardEventSource: nil, virtualKey: 0x24, keyDown: true))
        let mapped = try XCTUnwrap(RecordedEvent.from(cgEvent: cg, type: .keyDown, relativeTime: 2.0))
        guard case .keyDown(_, let code, _) = mapped else { return XCTFail("wrong case") }
        XCTAssertEqual(code, 0x24)
    }

    func test_unknownType_returnsNil() throws {
        let cg = try XCTUnwrap(CGEvent(source: nil))
        XCTAssertNil(RecordedEvent.from(cgEvent: cg, type: .tapDisabledByTimeout, relativeTime: 0))
    }
}
