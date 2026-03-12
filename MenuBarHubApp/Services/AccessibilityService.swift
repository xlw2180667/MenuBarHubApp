import AppKit
internal import ApplicationServices

/// 封装所有 AXUIElement 操作：点击状态栏图标、权限检查
struct AccessibilityService {

    // MARK: - 权限

    /// 检查是否有辅助功能权限
    static func isTrusted() -> Bool {
        AXIsProcessTrusted()
    }

    /// 检查权限，如果没有则弹出系统授权提示
    static func checkAndRequestPermission() {
        if !AXIsProcessTrusted() {
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
            AXIsProcessTrustedWithOptions(options)
        }
    }

    // MARK: - 点击状态栏图标

    /// 点击指定 app 的菜单栏状态栏图标
    ///
    /// 尝试顺序：
    /// 1. AXPress 给定 PID 的 AXExtrasMenuBar children
    /// 2. CGEvent 模拟点击该元素的屏幕位置
    /// 3. 搜索同名/同 bundle 前缀的相关进程重试（某些 app 状态栏图标属于子进程）
    /// 4. 最终回退到 app.activate()
    static func pressStatusItem(pid: pid_t) {
        guard isTrusted() else {
            checkAndRequestPermission()
            return
        }

        // 1) 尝试给定 PID
        if tryAXClick(pid: pid) { return }

        // 2) 搜索相关进程（如 Docker 的状态栏图标可能属于另一个子进程）
        if let app = NSRunningApplication(processIdentifier: pid) {
            let baseName = (app.localizedName ?? "").lowercased()
            let bundlePrefix = app.bundleIdentifier?
                .components(separatedBy: ".").prefix(2).joined(separator: ".") ?? ""

            for candidate in NSWorkspace.shared.runningApplications {
                guard candidate.processIdentifier != pid else { continue }
                let cName = (candidate.localizedName ?? "").lowercased()
                let cBID = candidate.bundleIdentifier ?? ""
                let nameMatch = !baseName.isEmpty
                    && (cName.contains(baseName) || baseName.contains(cName))
                let bidMatch = !bundlePrefix.isEmpty && cBID.hasPrefix(bundlePrefix)
                if nameMatch || bidMatch {
                    if tryAXClick(pid: candidate.processIdentifier) { return }
                }
            }

            // 3) 最终回退：普通激活
            app.activate(options: [.activateAllWindows])
        }
    }

    // MARK: - 内部实现

    /// 尝试通过 AX API 点击指定进程的状态栏图标
    @discardableResult
    private static func tryAXClick(pid: pid_t) -> Bool {
        let appElement = AXUIElementCreateApplication(pid)
        var menuBarRef: CFTypeRef?
        let err = AXUIElementCopyAttributeValue(
            appElement, "AXExtrasMenuBar" as CFString, &menuBarRef
        )
        guard err == .success else { return false }

        let menuBar = menuBarRef as! AXUIElement
        var childrenRef: CFTypeRef?
        let childErr = AXUIElementCopyAttributeValue(
            menuBar, kAXChildrenAttribute as CFString, &childrenRef
        )
        guard childErr == .success,
              let children = childrenRef as? [AXUIElement],
              !children.isEmpty else { return false }

        // 先尝试 AXPress（对大多数 app 有效）
        for item in children {
            if AXUIElementPerformAction(item, kAXPressAction as CFString) == .success {
                return true
            }
        }

        // AXPress 失败时用 CGEvent 模拟点击
        for item in children {
            if clickAtElement(item) { return true }
        }

        return false
    }

    /// 通过 CGEvent 在 AXUIElement 的屏幕位置模拟鼠标点击
    /// mouseDown 和 mouseUp 之间加 50ms 延迟，否则系统可能不处理
    private static func clickAtElement(_ element: AXUIElement) -> Bool {
        var positionRef: CFTypeRef?
        var sizeRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            element, kAXPositionAttribute as CFString, &positionRef
        ) == .success,
              AXUIElementCopyAttributeValue(
            element, kAXSizeAttribute as CFString, &sizeRef
        ) == .success else {
            return false
        }

        var position = CGPoint.zero
        var size = CGSize.zero
        AXValueGetValue(positionRef as! AXValue, .cgPoint, &position)
        AXValueGetValue(sizeRef as! AXValue, .cgSize, &size)

        // 校验：尺寸 > 0 且位置在菜单栏区域（屏幕顶部）
        guard size.width > 0 && size.height > 0 && position.y < 100 else {
            return false
        }

        let clickPoint = CGPoint(
            x: position.x + size.width / 2,
            y: position.y + size.height / 2
        )

        guard let mouseDown = CGEvent(
            mouseEventSource: nil, mouseType: .leftMouseDown,
            mouseCursorPosition: clickPoint, mouseButton: .left
        ),
              let mouseUp = CGEvent(
            mouseEventSource: nil, mouseType: .leftMouseUp,
            mouseCursorPosition: clickPoint, mouseButton: .left
        ) else {
            return false
        }

        mouseDown.post(tap: .cghidEventTap)
        usleep(50_000)  // 50ms
        mouseUp.post(tap: .cghidEventTap)
        return true
    }
}
