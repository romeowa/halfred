import Carbon
import AppKit

final class HotkeyManager {
    private var hotKeyRefs: [UInt32: EventHotKeyRef] = [:]
    private static var handlers: [UInt32: () -> Void] = [:]
    private static var installed = false

    func register(id: UInt32, keyCode: UInt32, modifiers: UInt32, handler: @escaping () -> Void) {
        HotkeyManager.handlers[id] = handler

        if !HotkeyManager.installed {
            var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))

            InstallEventHandler(GetApplicationEventTarget(), { _, event, _ -> OSStatus in
                var hotkeyID = EventHotKeyID()
                GetEventParameter(event, EventParamName(kEventParamDirectObject),
                                  EventParamType(typeEventHotKeyID), nil,
                                  MemoryLayout<EventHotKeyID>.size, nil, &hotkeyID)
                HotkeyManager.handlers[hotkeyID.id]?()
                return noErr
            }, 1, &eventType, nil, nil)

            HotkeyManager.installed = true
        }

        let hotkeyID = EventHotKeyID(signature: OSType(0x484C4652), id: id)
        var ref: EventHotKeyRef?
        RegisterEventHotKey(keyCode, modifiers, hotkeyID, GetApplicationEventTarget(), 0, &ref)
        if let ref = ref {
            hotKeyRefs[id] = ref
        }
    }

    deinit {
        for ref in hotKeyRefs.values {
            UnregisterEventHotKey(ref)
        }
    }
}
