import Carbon.HIToolbox
import Foundation

public final class HotkeyManager {
    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?
    private let onPressed: () -> Void
    private static var instances: [UInt32: HotkeyManager] = [:]
    private static var nextID: UInt32 = 1
    private let id: UInt32

    public init(onPressed: @escaping () -> Void) {
        self.onPressed = onPressed
        self.id = HotkeyManager.nextID
        HotkeyManager.nextID += 1
    }

    public func registerF8() {
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                      eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, eventRef, _ -> OSStatus in
            var hkID = EventHotKeyID()
            GetEventParameter(eventRef, EventParamName(kEventParamDirectObject),
                              EventParamType(typeEventHotKeyID), nil,
                              MemoryLayout<EventHotKeyID>.size, nil, &hkID)
            HotkeyManager.instances[hkID.id]?.onPressed()
            return noErr
        }, 1, &eventType, nil, &handlerRef)

        let hkID = EventHotKeyID(signature: OSType(0x434C4B52 /* 'CLKR' */), id: id)
        let keyCodeF8: UInt32 = 100
        RegisterEventHotKey(keyCodeF8, 0, hkID,
                            GetApplicationEventTarget(), 0, &hotKeyRef)
        HotkeyManager.instances[id] = self
    }

    public func unregister() {
        if let hk = hotKeyRef { UnregisterEventHotKey(hk); hotKeyRef = nil }
        if let h = handlerRef { RemoveEventHandler(h); handlerRef = nil }
        HotkeyManager.instances.removeValue(forKey: id)
    }

    deinit { unregister() }
}
