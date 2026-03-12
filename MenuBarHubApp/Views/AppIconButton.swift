import SwiftUI

/// 单个 app 图标按钮
///
/// 交互：
/// - 单击触发 onTap（由外部决定是 pressStatusItem 还是 activate）
/// - 右键菜单：切换到 / 退出
/// - hover 效果：背景高亮
/// - 活跃 app 右上角绿色圆点
struct AppIconButton: View {
    let app: RunningAppInfo
    let isHovered: Bool
    let onHover: (Bool) -> Void
    let onTap: () -> Void
    let onForceQuit: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                ZStack(alignment: .topTrailing) {
                    Image(nsImage: app.icon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 36, height: 36)

                    if app.isActive {
                        Circle().fill(.green)
                            .frame(width: 6, height: 6)
                            .offset(x: 2, y: -2)
                    }
                }

                Text(app.name)
                    .font(.system(size: 10))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(width: 64)
            }
            .padding(6)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isHovered ? .white.opacity(0.1) : .clear)
            )
        }
        .buttonStyle(.plain)
        .onHover(perform: onHover)
        .contextMenu {
            Button("切换到 \(app.name)") { onTap() }
            Divider()
            Button("退出 \(app.name)", role: .destructive) { onForceQuit() }
        }
    }
}
