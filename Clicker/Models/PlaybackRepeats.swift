import Foundation

public enum PlaybackRepeats: Codable, Equatable {
    case count(Int)
    case infinite

    public var normalized: PlaybackRepeats {
        switch self {
        case .infinite: return .infinite
        case .count(let n): return .count(max(1, n))
        }
    }
}
