import Foundation

public protocol Sleeper {
    func sleep(seconds: TimeInterval) async throws
}

public struct RealSleeper: Sleeper {
    public init() {}
    public func sleep(seconds: TimeInterval) async throws {
        if seconds <= 0 { try Task.checkCancellation(); return }
        try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
    }
}

public final class EventPlayer {
    private let poster: EventPoster
    private let sleeper: Sleeper
    private var cancelled = false
    private let lock = NSLock()

    public init(poster: EventPoster, sleeper: Sleeper = RealSleeper()) {
        self.poster = poster
        self.sleeper = sleeper
    }

    public func cancel() {
        lock.lock(); cancelled = true; lock.unlock()
    }

    public func play(events: [RecordedEvent],
                     repeats: PlaybackRepeats,
                     speed: Double,
                     intervalBetweenRepeats: TimeInterval = 0,
                     onIteration: ((Int) -> Void)? = nil) async throws {
        lock.lock(); cancelled = false; lock.unlock()
        guard !events.isEmpty else { return }
        let safeSpeed = max(0.01, speed)
        let interval = max(0, intervalBetweenRepeats)

        var iteration = 0
        while !shouldStop(repeats: repeats, iteration: iteration) {
            onIteration?(iteration + 1)
            try await playOnce(events: events, speed: safeSpeed)
            iteration += 1
            if interval > 0, !shouldStop(repeats: repeats, iteration: iteration) {
                try await sleeper.sleep(seconds: interval)
                try checkCancel()
            }
        }
    }

    private func playOnce(events: [RecordedEvent], speed: Double) async throws {
        var lastT: TimeInterval = 0
        for event in events {
            let delta = max(0, event.t - lastT) / speed
            try await sleeper.sleep(seconds: delta)
            try checkCancel()
            poster.post(event)
            lastT = event.t
        }
    }

    private func shouldStop(repeats: PlaybackRepeats, iteration: Int) -> Bool {
        lock.lock(); let c = cancelled; lock.unlock()
        if c { return true }
        switch repeats.normalized {
        case .infinite: return false
        case .count(let n): return iteration >= n
        }
    }

    private func checkCancel() throws {
        lock.lock(); let c = cancelled; lock.unlock()
        if c { throw CancellationError() }
    }
}
