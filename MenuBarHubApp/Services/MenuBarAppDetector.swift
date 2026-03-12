import AppKit
internal import ApplicationServices

/// 判断 .accessory app 是否是用户关心的真正菜单栏 app
///
/// 过滤规则（按顺序）：
/// 1. 排除 bundleID 以 "com.apple." 开头的系统进程
/// 2. 排除嵌套在其他 .app 内的 helper 进程
/// 3. 排除名称符合 helper/agent 模式的进程（如 "FigmaAgent"）
/// 4. 如果有辅助功能权限，用 AX API 精确检测是否有可见状态栏图标
/// 5. 否则回退到检查 Info.plist 是否定义了自定义图标
struct MenuBarAppDetector {

    // MARK: - 主入口

    /// 判断一个 .accessory/.prohibited app 是否是真正的第三方菜单栏 app
    static func isRealMenuBarApp(_ app: NSRunningApplication) -> Bool {
        guard let bundleID = app.bundleIdentifier else { return false }

        // 规则 1: 排除 Apple 系统进程
        if bundleID.hasPrefix("com.apple.") { return false }

        // 规则 2: 排除嵌套 helper（如 Slack.app/Contents/Frameworks/Slack Helper.app）
        if isNestedHelper(app) { return false }

        // 规则 3: 排除 helper/agent 命名模式
        let name = app.localizedName ?? ""
        let isHelper = isHelperName(name)

        // 规则 4: AX API 精确检测（需要辅助功能权限）
        if AXIsProcessTrusted() {
            if hasStatusBarItem(pid: app.processIdentifier) {
                return true
            }
            // AX 明确说没有状态栏图标 → helper 一定不是菜单栏 app
            if isHelper { return false }
        }

        // 规则 5: 启发式回退
        // .prohibited 纯后台进程只能靠 AX 检测，启发式不可靠
        if app.activationPolicy == .prohibited { return false }
        if isHelper { return false }
        return hasCustomIcon(app)
    }

    // MARK: - AX 检测

    /// 使用 AXUIElement API 检查进程是否有可见的状态栏图标
    /// 通过 AXExtrasMenuBar 获取状态栏 children，要求尺寸 > 0（排除隐形占位）
    static func hasStatusBarItem(pid: pid_t) -> Bool {
        let appElement = AXUIElementCreateApplication(pid)
        var menuBarRef: CFTypeRef?
        let err = AXUIElementCopyAttributeValue(
            appElement, "AXExtrasMenuBar" as CFString, &menuBarRef
        )
        guard err == .success else { return false }

        var childrenRef: CFTypeRef?
        let childErr = AXUIElementCopyAttributeValue(
            menuBarRef as! AXUIElement, kAXChildrenAttribute as CFString, &childrenRef
        )
        if childErr == .success, let children = childrenRef as? [AXUIElement] {
            for child in children {
                var sizeRef: CFTypeRef?
                if AXUIElementCopyAttributeValue(
                    child, kAXSizeAttribute as CFString, &sizeRef
                ) == .success {
                    var size = CGSize.zero
                    AXValueGetValue(sizeRef as! AXValue, .cgSize, &size)
                    if size.width > 0 && size.height > 0 { return true }
                }
            }
        }
        return false
    }

    // MARK: - 启发式检测

    /// 检查 app bundle 的 Info.plist 是否定义了自定义图标
    /// 没有 CFBundleIconFile 或 CFBundleIconName 的 app 会显示默认白色乐高块图标
    static func hasCustomIcon(_ app: NSRunningApplication) -> Bool {
        guard let bundleURL = app.bundleURL,
              let bundle = Bundle(url: bundleURL) else { return false }
        let info = bundle.infoDictionary ?? [:]
        if let name = info["CFBundleIconName"] as? String, !name.isEmpty { return true }
        if let file = info["CFBundleIconFile"] as? String, !file.isEmpty { return true }
        return false
    }

    // MARK: - 辅助过滤

    /// 检查 app 是否嵌套在另一个 .app bundle 内部
    /// 例如路径 /Applications/Slack.app/Contents/Frameworks/Slack Helper.app → 嵌套 helper
    private static func isNestedHelper(_ app: NSRunningApplication) -> Bool {
        guard let bundleURL = app.bundleURL else { return true }
        let path = bundleURL.path
        // 路径中第一个 .app/ 之后如果还有 .app，说明是嵌套的 helper
        if let range = path.range(of: ".app/") {
            let rest = path[range.upperBound...]
            if rest.contains(".app") { return true }
        }
        return false
    }

    /// 检查名称是否符合 helper/agent 模式
    /// 匹配: "FigmaAgent", "Dropbox Agent", "FooHelper", "Bar Helper"
    private static func isHelperName(_ name: String) -> Bool {
        let suffixes = ["Agent", " Agent", "Helper", " Helper"]
        return suffixes.contains { suffix in
            name.hasSuffix(suffix) && name.count > suffix.count
        }
    }
}
