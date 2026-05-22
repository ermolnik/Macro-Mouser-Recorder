import XCTest
@testable import Clicker

final class PlaybackRepeatsCodableTests: XCTestCase {
    func test_count_roundTrip() throws {
        let original = PlaybackRepeats.count(5)
        let data = try JSONEncoder().encode(original)
        XCTAssertEqual(try JSONDecoder().decode(PlaybackRepeats.self, from: data), original)
    }

    func test_infinite_roundTrip() throws {
        let original = PlaybackRepeats.infinite
        let data = try JSONEncoder().encode(original)
        XCTAssertEqual(try JSONDecoder().decode(PlaybackRepeats.self, from: data), original)
    }

    func test_count_mustBePositive() {
        XCTAssertEqual(PlaybackRepeats.count(0).normalized, .count(1))
        XCTAssertEqual(PlaybackRepeats.count(-3).normalized, .count(1))
        XCTAssertEqual(PlaybackRepeats.count(7).normalized, .count(7))
        XCTAssertEqual(PlaybackRepeats.infinite.normalized, .infinite)
    }
}
