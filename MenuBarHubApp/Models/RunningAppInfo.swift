import AppKit

/// 运行中 app 的元数据，用于在 UI 中展示
struct RunningAppInfo: Identifiable, Hashable {
    let id: pid_t
    let name: String
    let icon: NSImage
    let bundleIdentifier: String?
    let isActive: Bool
    let category: AppCategory

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: Self, rhs: Self) -> Bool { lhs.id == rhs.id }
}
