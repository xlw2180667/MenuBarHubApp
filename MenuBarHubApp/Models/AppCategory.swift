/// App 分类：菜单栏应用 vs Dock 应用
enum AppCategory: String {
    /// 只在菜单栏显示的 app（activationPolicy == .accessory）
    case menuBarOnly = "菜单栏应用"
    /// 在 Dock 中显示的普通 app（activationPolicy == .regular）
    case regular = "Dock 应用"
}
