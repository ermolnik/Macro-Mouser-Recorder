import Foundation

public enum MouseButton: String, Codable, Equatable {
    case left, right, other
}

public enum RecordedEvent: Codable, Equatable {
    case mouseMove(t: TimeInterval, x: Double, y: Double)
    case mouseDown(t: TimeInterval, button: MouseButton, x: Double, y: Double, clickCount: Int)
    case mouseUp(t: TimeInterval, button: MouseButton, x: Double, y: Double, clickCount: Int)
    case mouseDrag(t: TimeInterval, button: MouseButton, x: Double, y: Double)
    case scroll(t: TimeInterval, dx: Int32, dy: Int32)
    case keyDown(t: TimeInterval, keyCode: UInt16, flags: UInt64)
    case keyUp(t: TimeInterval, keyCode: UInt16, flags: UInt64)
    case flagsChanged(t: TimeInterval, flags: UInt64)

    public var t: TimeInterval {
        switch self {
        case .mouseMove(let t, _, _),
             .mouseDown(let t, _, _, _, _),
             .mouseUp(let t, _, _, _, _),
             .mouseDrag(let t, _, _, _),
             .scroll(let t, _, _),
             .keyDown(let t, _, _),
             .keyUp(let t, _, _),
             .flagsChanged(let t, _):
            return t
        }
    }
}
