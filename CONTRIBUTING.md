# Contributing

感谢你对 MenuBarHub 的关注！欢迎提交 Issue 和 Pull Request。

## 提交 Issue

- Bug：请说明复现步骤、macOS 版本、预期行为 vs 实际行为
- Feature：简要描述需求和使用场景

## 提交 PR

1. Fork 本仓库，基于 `main` 创建新分支
2. 在本地构建并测试：
   ```bash
   open MenuBarHubApp.xcodeproj   # Xcode 26+
   # 或命令行：
   xcodebuild -project MenuBarHubApp.xcodeproj -scheme MenuBarHubApp -configuration Debug build
   ```
3. 提交 PR，简要描述改动内容和原因

## 代码风格

- Swift 严格并发检查（Strict Concurrency）
- Model 层用 `struct`，Service 层用 `class`（ObservableObject）
- AX API 调用检查返回值，失败时静默 fallback，不要 crash
- 注释语言：中文
- 不引入第三方依赖

## 项目配置注意

- App Sandbox 必须关闭（AXUIElement / CGEvent 需要）
- Info.plist 需要 `LSUIElement = YES`
- Entitlements 需要 `com.apple.security.automation.apple-events = YES`

详细架构说明见 [CLAUDE.md](./CLAUDE.md)。
