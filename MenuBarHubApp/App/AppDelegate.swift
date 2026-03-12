import AppKit
import SwiftUI

/// 管理 NSStatusItem + NSPopover 生命周期
///
/// 关键行为：
/// - NSStatusItem 使用 squareLength，图标用 SF Symbol "square.grid.2x2"
/// - NSPopover behavior = .semitransient（不用 .transient，否则按钮点击会被吞）
/// - popover 打开后调用 makeKey() 确保按钮可点击
/// - 点击外部区域关闭 popover（NSEvent.addGlobalMonitorForEvents）
/// - ⌥Space 全局快捷键 toggle popover
class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var globalMonitor: Any?
    private let hotKeyService = HotKeyService()
    private let appManager = AppListManager()

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        setupPopover()
        hotKeyService.register()
        appManager.start()

        // 监听 ⌥Space 快捷键的通知
        NotificationCenter.default.addObserver(
            self, selector: #selector(togglePopover),
            name: .togglePopover, object: nil
        )
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotKeyService.unregister()
        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }

    // MARK: - 状态栏图标

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(
                systemSymbolName: "square.grid.2x2",
                accessibilityDescription: "MenuBar Hub"
            )
            button.action = #selector(togglePopover)
            button.target = self
        }
    }

    // MARK: - Popover

    private func setupPopover() {
        popover = NSPopover()
        popover.behavior = .semitransient
        popover.contentViewController = NSHostingController(
            rootView: AppGridView(
                appManager: appManager,
                closePopover: { [weak self] in self?.closePopover() }
            )
        )
    }

    @objc private func togglePopover() {
        if popover.isShown {
            closePopover()
        } else {
            openPopover()
        }
    }

    private func openPopover() {
        guard let button = statusItem.button else { return }

        // 打开时立即刷新一次
        appManager.refreshApps()

        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)

        // makeKey() 确保 SwiftUI 按钮可点击
        popover.contentViewController?.view.window?.makeKey()

        // 全局监听点击外部区域关闭 popover
        globalMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] _ in
            self?.closePopover()
        }
    }

    private func closePopover() {
        popover.performClose(nil)
        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
            globalMonitor = nil
        }
    }
}
