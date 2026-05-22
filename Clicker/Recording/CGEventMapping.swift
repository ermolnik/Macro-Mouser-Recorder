import CoreGraphics
import Foundation

extension RecordedEvent {
    static func from(cgEvent: CGEvent, type: CGEventType, relativeTime t: TimeInterval) -> RecordedEvent? {
        let loc = cgEvent.location
        let flags = cgEvent.flags.rawValue
        switch type {
        case .mouseMoved:
            return .mouseMove(t: t, x: Double(loc.x), y: Double(loc.y))

        case .leftMouseDown:
            return .mouseDown(t: t, button: .left, x: Double(loc.x), y: Double(loc.y),
                              clickCount: Int(cgEvent.getIntegerValueField(.mouseEventClickState)))
        case .leftMouseUp:
            return .mouseUp(t: t, button: .left, x: Double(loc.x), y: Double(loc.y),
                            clickCount: Int(cgEvent.getIntegerValueField(.mouseEventClickState)))
        case .rightMouseDown:
            return .mouseDown(t: t, button: .right, x: Double(loc.x), y: Double(loc.y),
                              clickCount: Int(cgEvent.getIntegerValueField(.mouseEventClickState)))
        case .rightMouseUp:
            return .mouseUp(t: t, button: .right, x: Double(loc.x), y: Double(loc.y),
                            clickCount: Int(cgEvent.getIntegerValueField(.mouseEventClickState)))
        case .otherMouseDown:
            return .mouseDown(t: t, button: .other, x: Double(loc.x), y: Double(loc.y),
                              clickCount: Int(cgEvent.getIntegerValueField(.mouseEventClickState)))
        case .otherMouseUp:
            return .mouseUp(t: t, button: .other, x: Double(loc.x), y: Double(loc.y),
                            clickCount: Int(cgEvent.getIntegerValueField(.mouseEventClickState)))

        case .leftMouseDragged:
            return .mouseDrag(t: t, button: .left, x: Double(loc.x), y: Double(loc.y))
        case .rightMouseDragged:
            return .mouseDrag(t: t, button: .right, x: Double(loc.x), y: Double(loc.y))
        case .otherMouseDragged:
            return .mouseDrag(t: t, button: .other, x: Double(loc.x), y: Double(loc.y))

        case .scrollWheel:
            let dy = Int32(cgEvent.getIntegerValueField(.scrollWheelEventDeltaAxis1))
            let dx = Int32(cgEvent.getIntegerValueField(.scrollWheelEventDeltaAxis2))
            return .scroll(t: t, dx: dx, dy: dy)

        case .keyDown:
            let code = UInt16(cgEvent.getIntegerValueField(.keyboardEventKeycode))
            return .keyDown(t: t, keyCode: code, flags: flags)
        case .keyUp:
            let code = UInt16(cgEvent.getIntegerValueField(.keyboardEventKeycode))
            return .keyUp(t: t, keyCode: code, flags: flags)
        case .flagsChanged:
            return .flagsChanged(t: t, flags: flags)

        default:
            return nil
        }
    }
}
