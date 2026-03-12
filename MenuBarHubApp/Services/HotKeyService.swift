import Carbon.HIToolbox
import Foundation

/// 全局快捷键服务，使用 Carbon API 注册 ⌥Space
///
/// 触发时通过 NotificationCenter 发送 .togglePopover 通知，
/// 由 AppDelegate 接收并 toggle popover。
class HotKeyService {
    private var hotKeyRef: EventHotKeyRef?

    /// 注册 ⌥Space 全局快捷键
    func register() {
        var eventType = EventTypeSpec(
            eventClass: UInt32(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, _, _ -> OSStatus in
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: .togglePopover, object: nil)
                }
                return noErr
            },
            1, &eventType, nil, nil
        )

        let hotKeyID = EventHotKeyID(signature: OSType(0x4D484241), id: 1)  // "MHBA"
        var ref: EventHotKeyRef?
        RegisterEventHotKey(
            UInt32(kVK_Space), UInt32(optionKey), hotKeyID,
            GetApplicationEventTarget(), 0, &ref
        )
        hotKeyRef = ref
    }

    /// 注销快捷键（app 退出时调用）
    func unregister() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
    }
}

extension Notification.Name {
    static let togglePopover = Notification.Name("TogglePopover")
}
