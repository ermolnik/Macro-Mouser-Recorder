import Foundation

public protocol EventPoster: AnyObject {
    func post(_ event: RecordedEvent)
}

import CoreGraphics

/// Marker written into CGEventField.eventSourceUserData on every synthetic event.
/// EventRecorder filters incoming events that carry this marker.
public let clickerSyntheticMarker: Int64 = 0x0000_0000_00C1_1CE0

public final class CGEventPoster: EventPoster {
    private let source: CGEventSource?

    public init() {
        self.source = CGEventSource(stateID: .privateState)
    }

    public func post(_ event: RecordedEvent) {
        guard let cg = makeCGEvent(from: event) else { return }
        cg.setIntegerValueField(.eventSourceUserData, value: clickerSyntheticMarker)
        cg.post(tap: .cghidEventTap)
    }

    private func makeCGEvent(from event: RecordedEvent) -> CGEvent? {
        switch event {
        case .mouseMove(_, let x, let y):
            return CGEvent(mouseEventSource: source, mouseType: .mouseMoved,
                           mouseCursorPosition: CGPoint(x: x, y: y),
                           mouseButton: .left)

        case .mouseDown(_, let button, let x, let y, let clickCount):
            let type: CGEventType = {
                switch button { case .left: return .leftMouseDown; case .right: return .rightMouseDown; case .other: return .otherMouseDown }
            }()
            let cg = CGEvent(mouseEventSource: source, mouseType: type,
                             mouseCursorPosition: CGPoint(x: x, y: y),
                             mouseButton: cgButton(for: button))
            cg?.setIntegerValueField(.mouseEventClickState, value: Int64(clickCount))
            return cg

        case .mouseUp(_, let button, let x, let y, let clickCount):
            let type: CGEventType = {
                switch button { case .left: return .leftMouseUp; case .right: return .rightMouseUp; case .other: return .otherMouseUp }
            }()
            let cg = CGEvent(mouseEventSource: source, mouseType: type,
                             mouseCursorPosition: CGPoint(x: x, y: y),
                             mouseButton: cgButton(for: button))
            cg?.setIntegerValueField(.mouseEventClickState, value: Int64(clickCount))
            return cg

        case .mouseDrag(_, let button, let x, let y):
            let type: CGEventType = {
                switch button { case .left: return .leftMouseDragged; case .right: return .rightMouseDragged; case .other: return .otherMouseDragged }
            }()
            return CGEvent(mouseEventSource: source, mouseType: type,
                           mouseCursorPosition: CGPoint(x: x, y: y),
                           mouseButton: cgButton(for: button))

        case .scroll(_, let dx, let dy):
            return CGEvent(scrollWheelEvent2Source: source,
                           units: .pixel, wheelCount: 2,
                           wheel1: dy, wheel2: dx, wheel3: 0)

        case .keyDown(_, let keyCode, let flags):
            let cg = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true)
            cg?.flags = CGEventFlags(rawValue: flags)
            return cg

        case .keyUp(_, let keyCode, let flags):
            let cg = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)
            cg?.flags = CGEventFlags(rawValue: flags)
            return cg

        case .flagsChanged(_, let flags):
            guard let cg = CGEvent(source: source) else { return nil }
            cg.type = .flagsChanged
            cg.flags = CGEventFlags(rawValue: flags)
            return cg
        }
    }

    private func cgButton(for button: MouseButton) -> CGMouseButton {
        switch button { case .left: return .left; case .right: return .right; case .other: return .center }
    }
}
