import XCTest
@testable import Clicker

final class RecordedEventCodableTests: XCTestCase {
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    func test_mouseMove_roundTrip() throws {
        let original = RecordedEvent.mouseMove(t: 0.123, x: 100.5, y: 200.25)
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(RecordedEvent.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    func test_mouseDown_roundTrip() throws {
        let original = RecordedEvent.mouseDown(t: 1.0, button: .left, x: 10, y: 20, clickCount: 2)
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(RecordedEvent.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    func test_keyDown_roundTrip() throws {
        let original = RecordedEvent.keyDown(t: 2.5, keyCode: 0x24, flags: 0x20000)
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(RecordedEvent.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    func test_allCases_roundTrip() throws {
        let cases: [RecordedEvent] = [
            .mouseMove(t: 0.1, x: 1, y: 2),
            .mouseDown(t: 0.2, button: .right, x: 3, y: 4, clickCount: 1),
            .mouseUp(t: 0.3, button: .right, x: 3, y: 4, clickCount: 1),
            .mouseDrag(t: 0.4, button: .left, x: 5, y: 6),
            .scroll(t: 0.5, dx: 0, dy: 3),
            .keyDown(t: 0.6, keyCode: 0x00, flags: 0),
            .keyUp(t: 0.7, keyCode: 0x00, flags: 0),
            .flagsChanged(t: 0.8, flags: 0x20000)
        ]
        for c in cases {
            let data = try encoder.encode(c)
            XCTAssertEqual(try decoder.decode(RecordedEvent.self, from: data), c)
        }
    }
}
