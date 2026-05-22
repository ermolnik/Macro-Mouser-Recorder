import CoreGraphics
import Foundation
import os

public final class EventRecorder {
    public enum RecorderError: Error { case tapCreationFailed }

    private let logger = Logger(subsystem: "app.clicker", category: "EventRecorder")
    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var startTime: CFAbsoluteTime = 0
    private var buffer: [RecordedEvent] = []
    private let bufferLock = NSLock()

    public init() {}

    public func start() throws {
        guard tap == nil else { return }
        bufferLock.lock(); buffer.removeAll(); bufferLock.unlock()
        startTime = CFAbsoluteTimeGetCurrent()

        var mask: CGEventMask = 0
        mask |= (1 << CGEventType.mouseMoved.rawValue)
        mask |= (1 << CGEventType.leftMouseDown.rawValue)
        mask |= (1 << CGEventType.leftMouseUp.rawValue)
        mask |= (1 << CGEventType.rightMouseDown.rawValue)
        mask |= (1 << CGEventType.rightMouseUp.rawValue)
        mask |= (1 << CGEventType.otherMouseDown.rawValue)
        mask |= (1 << CGEventType.otherMouseUp.rawValue)
        mask |= (1 << CGEventType.leftMouseDragged.rawValue)
        mask |= (1 << CGEventType.rightMouseDragged.rawValue)
        mask |= (1 << CGEventType.otherMouseDragged.rawValue)
        mask |= (1 << CGEventType.scrollWheel.rawValue)
        mask |= (1 << CGEventType.keyDown.rawValue)
        mask |= (1 << CGEventType.keyUp.rawValue)
        mask |= (1 << CGEventType.flagsChanged.rawValue)

        let userInfo = Unmanaged.passUnretained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: { _, type, event, refcon in
                guard let refcon = refcon else { return Unmanaged.passUnretained(event) }
                let recorder = Unmanaged<EventRecorder>.fromOpaque(refcon).takeUnretainedValue()
                recorder.handle(event: event, type: type)
                return Unmanaged.passUnretained(event)
            },
            userInfo: userInfo
        ) else {
            throw RecorderError.tapCreationFailed
        }

        let src = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), src, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        self.tap = tap
        self.runLoopSource = src
    }

    public func stop() -> [RecordedEvent] {
        if let tap = tap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let src = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), src, .commonModes)
        }
        tap = nil
        runLoopSource = nil
        bufferLock.lock(); let out = buffer; buffer.removeAll(); bufferLock.unlock()
        return out
    }

    private func handle(event: CGEvent, type: CGEventType) {
        let marker = event.getIntegerValueField(.eventSourceUserData)
        if marker == clickerSyntheticMarker { return }
        let t = CFAbsoluteTimeGetCurrent() - startTime
        guard let recorded = RecordedEvent.from(cgEvent: event, type: type, relativeTime: t) else { return }
        bufferLock.lock(); buffer.append(recorded); bufferLock.unlock()
    }
}
