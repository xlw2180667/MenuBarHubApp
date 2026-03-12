import AppKit
internal import Combine

/// 检测所有运行中的 app，分类、去重、排序
///
/// 检测逻辑：
/// - activationPolicy == .regular → Dock app，全部包含
/// - activationPolicy == .accessory → 调用 MenuBarAppDetector 过滤
/// - activationPolicy == .prohibited → 排除
///
/// 刷新：启动时立即刷新 + 每 2 秒 Timer 自动刷新
final class AppListManager: ObservableObject {
    @Published var apps: [RunningAppInfo] = []
    private var timer: Timer?

    /// 启动定时刷新（在 app 启动时调用，提前预加载数据）
    func start() {
        refreshApps()
        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            self?.refreshApps()
        }
    }

    /// 手动刷新（popover 打开时也可调用）
    func refreshApps() {
        let workspace = NSWorkspace.shared
        let running = workspace.runningApplications
        let activeApp = workspace.frontmostApplication
        let selfBundleID = Bundle.main.bundleIdentifier

        // 第一步：按 activationPolicy 过滤，生成 RunningAppInfo
        let all = running
            .filter { app in
                guard app.bundleIdentifier != selfBundleID else { return false }
                switch app.activationPolicy {
                case .regular:
                    return true
                case .accessory:
                    return MenuBarAppDetector.isRealMenuBarApp(app)
                case .prohibited:
                    return false
                @unknown default:
                    return false
                }
            }
            .compactMap { app -> RunningAppInfo? in
                guard let name = app.localizedName, !name.isEmpty else { return nil }
                let icon = app.icon ?? NSImage(
                    systemSymbolName: "app.fill",
                    accessibilityDescription: nil
                )!
                icon.size = NSSize(width: 32, height: 32)

                return RunningAppInfo(
                    id: app.processIdentifier,
                    name: name,
                    icon: icon,
                    bundleIdentifier: app.bundleIdentifier,
                    isActive: app.processIdentifier == activeApp?.processIdentifier,
                    category: app.activationPolicy == .regular ? .regular : .menuBarOnly
                )
            }

        // 第二步：按 bundleIdentifier 去重
        // 优先保留 isActive 的实例，其次保留名字较短的主进程
        let bundleDeduped = deduplicateByBundleID(all)

        // 第三步：过滤关联的 helper/daemon 进程
        let filtered = filterRelatedProcesses(bundleDeduped)

        apps = filtered.sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
    }

    // MARK: - 去重

    /// 按 bundleIdentifier 去重，同 bundle 保留最佳实例
    private func deduplicateByBundleID(_ apps: [RunningAppInfo]) -> [RunningAppInfo] {
        var bestByBundle: [String: RunningAppInfo] = [:]
        var noBundleApps: [RunningAppInfo] = []

        for app in apps {
            if let bid = app.bundleIdentifier {
                if let existing = bestByBundle[bid] {
                    // 优先保留活跃实例
                    if app.isActive && !existing.isActive {
                        bestByBundle[bid] = app
                    }
                    // 都不活跃时保留较短名称（主进程通常名字短于 helper）
                    else if !app.isActive && !existing.isActive
                                && app.name.count < existing.name.count {
                        bestByBundle[bid] = app
                    }
                } else {
                    bestByBundle[bid] = app
                }
            } else {
                noBundleApps.append(app)
            }
        }
        return Array(bestByBundle.values) + noBundleApps
    }

    /// 过滤关联的 helper/agent/daemon 进程
    ///
    /// 规则：
    /// - "Foo Agent" 存在且 "Foo" 也在 → 移除 "Foo Agent"
    /// - "Foo Desktop" 存在且 "Foo" 也在 → 移除 "Foo"（daemon），保留 "Foo Desktop"（GUI）
    private func filterRelatedProcesses(_ apps: [RunningAppInfo]) -> [RunningAppInfo] {
        let allNamesLower = Set(apps.map { $0.name.lowercased() })
        let helperSuffixes = [" Agent", "Agent", " Helper", "Helper"]

        // 找出 daemon 名称：如果 "Foo Desktop" 存在，则 "Foo" 是 daemon
        let daemonNames: Set<String> = Set(apps.compactMap { app -> String? in
            guard app.category == .menuBarOnly, app.name.hasSuffix(" Desktop") else { return nil }
            let daemonName = String(app.name.dropLast(" Desktop".count))
            if allNamesLower.contains(daemonName.lowercased()) {
                return daemonName.lowercased()
            }
            return nil
        })

        return apps.filter { app in
            guard app.category == .menuBarOnly else { return true }

            // 移除 daemon（有对应的 Desktop GUI 进程）
            if daemonNames.contains(app.name.lowercased()) { return false }

            // 移除 helper/agent（有对应的主进程）
            for suffix in helperSuffixes {
                if app.name.hasSuffix(suffix) {
                    let parentName = String(app.name.dropLast(suffix.count))
                    if !parentName.isEmpty && allNamesLower.contains(parentName.lowercased()) {
                        return false
                    }
                }
            }
            return true
        }
    }
}
