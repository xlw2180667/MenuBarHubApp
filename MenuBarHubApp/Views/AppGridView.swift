import SwiftUI

/// 主面板视图
///
/// 布局：标题栏 → 搜索框 → 滚动网格（菜单栏应用 + Dock 应用）→ 底部状态栏
///
/// 交互：
/// - 菜单栏 app 单击 → 关闭 popover，延迟 0.35s，调用 pressStatusItem
/// - Dock app 单击 → 关闭 popover，延迟 0.15s，调用 activate
/// - 右键退出 app
struct AppGridView: View {
    @ObservedObject var appManager: AppListManager
    let closePopover: () -> Void

    @State private var searchText = ""
    @State private var hoveredAppID: pid_t?

    private let columns = Array(repeating: GridItem(.fixed(76), spacing: 4), count: 6)

    /// 搜索过滤后的菜单栏应用
    private var menuBarApps: [RunningAppInfo] {
        filteredApps.filter { $0.category == .menuBarOnly }
    }

    /// 搜索过滤后的 Dock 应用
    private var dockApps: [RunningAppInfo] {
        filteredApps.filter { $0.category == .regular }
    }

    /// 按名称或 bundleID 搜索
    private var filteredApps: [RunningAppInfo] {
        if searchText.isEmpty { return appManager.apps }
        let query = searchText.lowercased()
        return appManager.apps.filter {
            $0.name.lowercased().contains(query)
                || ($0.bundleIdentifier?.lowercased().contains(query) ?? false)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            SearchBar(text: $searchText)

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    // 菜单栏应用分组
                    if !menuBarApps.isEmpty {
                        SectionHeaderView(
                            title: AppCategory.menuBarOnly.rawValue,
                            icon: "menubar.rectangle",
                            count: menuBarApps.count
                        )
                        LazyVGrid(columns: columns, spacing: 4) {
                            ForEach(menuBarApps) { app in
                                AppIconButton(
                                    app: app,
                                    isHovered: hoveredAppID == app.id,
                                    onHover: { hoveredAppID = $0 ? app.id : nil },
                                    onTap: { switchToApp(app) },
                                    onForceQuit: { quitApp(app) }
                                )
                            }
                        }
                        .padding(.horizontal, 8)
                    }

                    // Dock 应用分组
                    if !dockApps.isEmpty {
                        SectionHeaderView(
                            title: AppCategory.regular.rawValue,
                            icon: "dock.rectangle",
                            count: dockApps.count
                        )
                        LazyVGrid(columns: columns, spacing: 4) {
                            ForEach(dockApps) { app in
                                AppIconButton(
                                    app: app,
                                    isHovered: hoveredAppID == app.id,
                                    onHover: { hoveredAppID = $0 ? app.id : nil },
                                    onTap: { switchToApp(app) },
                                    onForceQuit: { quitApp(app) }
                                )
                            }
                        }
                        .padding(.horizontal, 8)
                    }

                    // 搜索无结果
                    if filteredApps.isEmpty {
                        Text("没有匹配的应用")
                            .foregroundStyle(.tertiary)
                            .frame(maxWidth: .infinity, minHeight: 80)
                    }
                }
                .padding(.vertical, 8)
            }
            .frame(maxHeight: 420)

            Divider()
            footer
        }
        .frame(width: 500)
    }

    // MARK: - 标题栏

    private var header: some View {
        HStack {
            Image(systemName: "square.grid.2x2").font(.title3)
            Text("MenuBar Hub").font(.headline)
            Spacer()
            Text("⌥Space")
                .font(.caption)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 4))
            Button(action: { appManager.refreshApps() }) {
                Image(systemName: "arrow.clockwise").font(.caption)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.top, 12)
        .padding(.bottom, 4)
    }

    // MARK: - 底部状态栏

    private var footer: some View {
        HStack {
            Text("菜单栏 \(menuBarApps.count) · Dock \(dockApps.count)")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Button("退出 Hub") { NSApplication.shared.terminate(nil) }
                .font(.caption)
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    // MARK: - 操作

    /// 切换到指定 app（必须先关闭 popover 再操作，否则会抢焦点）
    private func switchToApp(_ app: RunningAppInfo) {
        closePopover()
        let pid = app.id
        let delay: Double = app.category == .menuBarOnly ? 0.35 : 0.15

        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            if app.category == .menuBarOnly {
                AccessibilityService.pressStatusItem(pid: pid)
            } else {
                NSRunningApplication(processIdentifier: pid)?
                    .activate(options: [.activateAllWindows])
            }
        }
    }

    /// 退出指定 app
    private func quitApp(_ app: RunningAppInfo) {
        NSRunningApplication(processIdentifier: app.id)?.terminate()
    }
}
