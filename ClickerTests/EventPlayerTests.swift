import XCTest
@testable import Clicker

final class MockPoster: EventPoster {
    var posted: [(event: RecordedEvent, at: TimeInterval)] = []
    var clock: TimeInterval = 0
    func post(_ event: RecordedEvent) {
        posted.append((event, clock))
    }
}

final class MockSleeper: Sleeper {
    var sleeps: [TimeInterval] = []
    var clock: TimeInterval = 0
    var onSleep: ((TimeInterval) -> Void)?
    func sleep(seconds: TimeInterval) async throws {
        sleeps.append(seconds)
        clock += seconds
        onSleep?(seconds)
        try Task.checkCancellation()
    }
}

final class EventPlayerTests: XCTestCase {
    func test_playsAllEvents_inOrder_atX1() async throws {
        let events: [RecordedEvent] = [
            .mouseDown(t: 0.0, button: .left, x: 1, y: 1, clickCount: 1),
            .mouseUp(t: 0.5, button: .left, x: 1, y: 1, clickCount: 1),
            .mouseDown(t: 1.0, button: .left, x: 2, y: 2, clickCount: 1)
        ]
        let poster = MockPoster()
        let sleeper = MockSleeper()
        sleeper.onSleep = { _ in poster.clock = sleeper.clock }
        let player = EventPlayer(poster: poster, sleeper: sleeper)
        try await player.play(events: events, repeats: .count(1), speed: 1.0)
        XCTAssertEqual(poster.posted.map(\.event), events)
        XCTAssertEqual(sleeper.sleeps, [0.0, 0.5, 0.5])
    }

    func test_speedDouble_halvesDelays() async throws {
        let events: [RecordedEvent] = [
            .mouseDown(t: 0.0, button: .left, x: 0, y: 0, clickCount: 1),
            .mouseUp(t: 2.0, button: .left, x: 0, y: 0, clickCount: 1)
        ]
        let poster = MockPoster()
        let sleeper = MockSleeper()
        let player = EventPlayer(poster: poster, sleeper: sleeper)
        try await player.play(events: events, repeats: .count(1), speed: 2.0)
        XCTAssertEqual(sleeper.sleeps, [0.0, 1.0])
    }

    func test_repeats_countN_replaysN() async throws {
        let events: [RecordedEvent] = [
            .mouseDown(t: 0.0, button: .left, x: 0, y: 0, clickCount: 1)
        ]
        let poster = MockPoster()
        let player = EventPlayer(poster: poster, sleeper: MockSleeper())
        try await player.play(events: events, repeats: .count(3), speed: 1.0)
        XCTAssertEqual(poster.posted.count, 3)
    }

    func test_onIteration_firesOncePerRepeat() async throws {
        let events: [RecordedEvent] = [
            .mouseDown(t: 0.0, button: .left, x: 0, y: 0, clickCount: 1)
        ]
        let poster = MockPoster()
        let player = EventPlayer(poster: poster, sleeper: MockSleeper())
        var iterations: [Int] = []
        try await player.play(events: events,
                              repeats: .count(3),
                              speed: 1.0,
                              onIteration: { iterations.append($0) })
        XCTAssertEqual(iterations, [1, 2, 3])
    }

    func test_interval_sleepsBetweenIterations_butNotAfterLast() async throws {
        let events: [RecordedEvent] = [
            .mouseDown(t: 0.0, button: .left, x: 0, y: 0, clickCount: 1)
        ]
        let poster = MockPoster()
        let sleeper = MockSleeper()
        let player = EventPlayer(poster: poster, sleeper: sleeper)
        try await player.play(events: events,
                              repeats: .count(3),
                              speed: 1.0,
                              intervalBetweenRepeats: 0.75)
        XCTAssertEqual(poster.posted.count, 3)
        let intervalSleeps = sleeper.sleeps.filter { $0 == 0.75 }
        XCTAssertEqual(intervalSleeps.count, 2)
    }

    func test_interval_zero_doesNotInsertExtraSleep() async throws {
        let events: [RecordedEvent] = [
            .mouseDown(t: 0.0, button: .left, x: 0, y: 0, clickCount: 1)
        ]
        let sleeper = MockSleeper()
        let player = EventPlayer(poster: MockPoster(), sleeper: sleeper)
        try await player.play(events: events,
                              repeats: .count(2),
                              speed: 1.0,
                              intervalBetweenRepeats: 0)
        XCTAssertEqual(sleeper.sleeps, [0.0, 0.0])
    }

    func test_cancel_stopsBeforeNextEvent() async throws {
        let events: [RecordedEvent] = [
            .mouseDown(t: 0.0, button: .left, x: 0, y: 0, clickCount: 1),
            .mouseDown(t: 0.5, button: .left, x: 0, y: 0, clickCount: 1),
            .mouseDown(t: 1.0, button: .left, x: 0, y: 0, clickCount: 1)
        ]
        let poster = MockPoster()
        let sleeper = MockSleeper()
        let player = EventPlayer(poster: poster, sleeper: sleeper)
        sleeper.onSleep = { _ in
            if poster.posted.count == 1 { player.cancel() }
        }
        do {
            try await player.play(events: events, repeats: .infinite, speed: 1.0)
            XCTFail("expected cancellation")
        } catch is CancellationError {
            // expected
        }
        XCTAssertEqual(poster.posted.count, 1)
    }
}
