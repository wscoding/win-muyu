# CLAUDE.md

本文件为 Claude Code 等 AI 代理提供入口指引。

**项目约定、架构说明与「已知陷阱」全部在 [AGENTS.md](AGENTS.md)，请先完整阅读。**

## 快速摘要

Prue Widgets（电子木鱼）—— 常驻桌面的悬浮小组件，Flutter 实现，支持 Windows 与 macOS。
无边框、透明、置顶，右键打开设置面板。

```
flutter analyze   # 必须 0 issue（warning / info 也算失败）
flutter test      # 必须全绿
flutter run -d macos
```

## 动手前必看的三条

1. **平台差异只写在** `lib/services/window/desktop_window_service.dart`。
   UI 与状态层不得出现 `Platform.isXxx`。

2. **设置只能通过** `SettingsController.patch()` / `.update()` **修改**。
   不要绕过它直接写 SharedPreferences。

3. **`AGENTS.md` 的「已知陷阱」逐条都是真实踩过的坑**，包括：
   - audioplayers 会自动补 `assets/` 前缀（`Image.asset` 则相反）
   - macOS `FlutterView` 背景色默认黑色，需单独设为 clear
   - Riverpod 禁止在 `onDispose` 里用 `ref.read`
   - 依赖版本受本地 SDK 上限约束，且 `tray_manager 0.6.x` 已被 pub 撤回

## 涉及原生代码时

Dart 与 Swift 的通道契约分布在两处，改动必须同步：
- `lib/services/window/desktop_window_service.dart` 里的 `MacosNative`
- `macos/Runner/AppDelegate.swift` 里的 `NativeChannel`

## 文档索引

| 文件 | 内容 |
|---|---|
| [AGENTS.md](AGENTS.md) | 项目约定、架构、陷阱、质量门禁 |
| [README.md](README.md) | 面向用户的功能介绍与安装说明 |
| [docs/backend-api.md](docs/backend-api.md) | 统计后端接口约定（供后端重写参考） |