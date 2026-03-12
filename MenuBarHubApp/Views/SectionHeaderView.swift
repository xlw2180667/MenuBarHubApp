import SwiftUI

/// 分组标题组件（如 "菜单栏应用 (5)"）
struct SectionHeaderView: View {
    let title: String
    let icon: String
    let count: Int

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon).font(.caption2)
            Text(title).font(.system(size: 11, weight: .semibold))
            Text("(\(count))")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, 14)
    }
}
