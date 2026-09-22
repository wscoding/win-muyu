# AGENTS.md

面向 AI 编码代理（Claude Code / Cursor / Trae 等）与人类贡献者的项目约定。
动手前请先读完本文件，尤其是「已知陷阱」一节——里面每一条都是真实踩过的坑。

## 这是什么

Prue Widgets（电子木鱼 / 摸鱼小部件），一个**常驻桌面的悬浮小组件**：
无边框、透明背景、始终置顶、不进 Dock / 任务栏，右键打开设置面板。

- 技术栈：Flutter（Windows + macOS 桌面端）
- 状态管理：Riverpod
- 原生代码：macOS 用 Swift，Windows 用 C++（均为 Flutter 官方模板 + 少量定制）

## 常用命令

```bash
flutter pub get                 # 安装依赖
flutter analyze                 # 静态检查，必须保持 0 issue（含 warning / info）
flutter test                    # 单元测试
flutter run -d macos            # 本机调试（macOS）
flutter run -d windows          # Windows 上调试
flutter build macos --release   # 打包 macOS
flutter build windows --release # 打包 Windows
```

Windows 安装包：先 `flutter build windows --release`，再用 Inno Setup 编译
[windows/installer/PrueWidgets.iss](windows/installer/PrueWidgets.iss)。

## 目录结构

```
lib/
├── main.dart                 入口：启动序列 + 注入 Riverpod overrides
├── app.dart                  应用根：主题、托盘 / 快捷键装配、设置变更副作用
├── constants/
│   ├── pref_keys.dart        SharedPreferences 键名（历史键名不可改）
│   ├── app_config.dart       后端地址与功能开关
│   ├── app_constants.dart    尺寸 / 时长 / 默认值
│   └── asset_catalog.dart    图片与音效清单 + 路径拼接
├── models/                   纯数据模型（AppSettings / MeritText / VersionInfo）
├── services/
│   ├── app_bootstrap.dart    启动编排：单实例 → 读状态 → 建窗 → 预加载音频
│   ├── app_lifecycle.dart    统一退出流程
│   ├── settings_repository.dart  本地读写 + v2 键迁移
│   ├── audio_service.dart    音效播放（多通道轮询）
│   ├── telemetry_service.dart    匿名统计上报（可整体关闭）
│   ├── tray_service.dart     托盘 / 菜单栏图标
│   ├── hotkey_service.dart   全局快捷键
│   └── window/desktop_window_service.dart   窗口抽象 + 平台实现
├── state/                    Riverpod controllers 与 provider 定义
└── ui/
    ├── wooden_fish_view.dart 木鱼本体（敲击 / 长按 / 右键 / 拖动）
    ├── menu_page.dart        设置菜单
    ├── pages/                各设置子页
    └── widgets/              PanelScaffold、功德提示浮层

macos/Runner/       AppDelegate.swift（单实例 / 隐藏 Dock）、MainFlutterWindow.swift（透明置顶 + 原生通道）
windows/            Flutter 官方模板 + runner 元信息
```

## 架构约定

1. **平台分支只允许出现在 `services/window/desktop_window_service.dart`。**
   上层 UI 与状态只依赖 `DesktopWindowService` 接口。新增平台（如 Linux）
   只需增加一个实现，不要在各处写 `Platform.isXxx`。

2. **Dart 与 Swift 共用的通道契约集中在两处，必须同步修改：**
   - Dart：`MacosNative`（`desktop_window_service.dart` 末尾）
   - Swift：`NativeChannel`（`macos/Runner/AppDelegate.swift` 顶部）
   通道名 `cc.iqg.prue_widgets/native`。

3. **设置只有一个修改入口：`SettingsController.patch()` / `.update()`。**
   不要在其他地方直接写 SharedPreferences，否则会出现「UI 显示 A、存储里是 B」。
   例外只有 `SettingsRepository` 自身（含 v2 键迁移）。

4. **敲击次数的持久化是「内存为准 + 定时落盘」**（`TapCounterController`），
   不要改回「每次读取即写盘」——那是 v2 卡顿的主因。

5. **网络请求一律走 `TelemetryService`**，它保证：
   后端开关关闭时短路、所有请求带超时、异常永不外抛。
   敲击路径上任何网络调用都不得阻塞 UI。

6. 新页面统一用 `PanelScaffold` 作为外壳（悬浮窗背景透明，页面需自带不透明表面）。

## 已知陷阱（改代码前务必确认）

- **audioplayers 的 `AssetSource` 会自动补 `assets/` 前缀。**
  传给它的路径必须是 `audio/muyu.mp3` 这种相对形式；写成
  `assets/audio/muyu.mp3` 会变成 `assets/assets/...` 而静默无声。
  统一用 `AssetCatalog.audioAssetPath()` 生成。
  注意 `Image.asset` 相反——它需要**完整** asset key（`AssetCatalog.imagePath()`）。

- **macOS 上 `FlutterView` 的默认背景色是黑色，且与 `NSWindow` 分开保存。**
  只设窗口透明仍会得到一块黑底。必须在 `MainFlutterWindow` 里同时设
  `flutterViewController.backgroundColor = .clear`。

- **`window_manager.setAsFrameless()` 在 macOS 上会把 `isOpaque` 设回 `true`。**
  平台样式必须在它**之后**应用（见 `showOverlayWindow` 的调用顺序）。

- **`window_manager.waitUntilReadyToShow(options, callback)` 的 callback 是同步调用、不会被 await。**
  不要依赖它做「建窗 → 设样式 → 显示」的顺序控制，改成显式逐步 await。

- **Riverpod 禁止在生命周期回调里用 Ref。**
  `ref.onDispose(() => ref.read(x))` 会抛
  `Cannot use Ref or modify other providers inside life-cycles`。
  需要在 dispose 时用的依赖，在 `build()` 里缓存成字段。

- **依赖版本以本地 SDK 为上限。** 当前 Flutter 3.41.9 / Dart 3.11.5：
  - `audioplayers` 不能到 6.8.x（要求 Flutter 3.44）
  - `flutter_riverpod` 不能到 3.4.x（要求 Dart 3.12）
  - `tray_manager` **0.6.x 已被 pub 撤回**，且 0.7.x 要求 Dart 3.13，
    因此固定在 `^0.5.3`，不要放宽到 `^0.6.0`
  - `windows_single_instance` 依赖 `win32 ^6`，与依赖 `win32_registry`(→`win32 ^5`)
    的 `launch_at_startup` **互斥**，两者不能同时引入

- **Flutter 3.41 的弃用项**（用错会让 `flutter analyze` 失败）：
  `Radio` / `RadioListTile` 的 `groupValue` + `onChanged` 已弃用，
  改用 `RadioGroup<T>` 祖先包裹；`Color.withOpacity` → `withValues(alpha:)`；
  `MaterialStateProperty` → `WidgetStateProperty`。

- **`file_picker` 13.x 的 API 与旧版不同**：`FilePicker` 已是
  `abstract final class`，没有 `.platform` 了；`pickFiles` 是静态方法且返回
  `Future<List<PlatformFile>>`（不是 `FilePickerResult`）。

- **`SharedPreferences` 的键名沿用了 v2 的历史命名**
  （`isHelpme`、`_isSoundOno`、`selectmusic`、`musicPath`…）。
  改名会让老用户升级后丢失全部设置。迁移逻辑集中在
  `SettingsRepository._migrateLegacyKeys()`，且必须保持幂等。

- **上报方法必须用 `_guard()` 包住。**
  `_safePost(AppConfig.statUri, ...)` 里 URI 的构造发生在 `_safePost`
  的 try **之外**，参数求值阶段的异常会绕过所有保护直接抛出。
  曾因此把 `'zt.999087.com/app/muyu/repo.php'` 整个当成 host，
  导致每次敲击都抛 `FormatException` 且上报静默失效。
  `AppConfig` 里 host 与 path 必须分开定义。

- **`LicensePage` 这个名字与 Flutter Material 自带类冲突。**
  本项目的对应页面叫 `AppLicensePage`，别改回去。

- **macOS 关闭了 App Sandbox，因此必须调用 `FilePicker.skipEntitlementsChecks()`。**
  （见 `macos/Runner/*.entitlements`）。原因：本地音源功能需要读取用户手填的
  任意路径，沙盒下会失败。

  **连带影响**：`file_picker_darwin` 从 2.1.2 起会在弹出文件对话框前校验
  `com.apple.security.files.user-selected.read-only` / `read-write`。
  非沙盒应用没有声明这两个 entitlement，不显式跳过就会被误拦，
  报 `PlatformException(ENTITLEMENT_NOT_FOUND, Either the Read-Only or
  Read-Write entitlement is required for this action.)`。

  修复点：`AppBootstrap.create()` 第 4 步调用
  `FilePicker.skipEntitlementsChecks()`（该 API 在其他平台是 no-op）。
  官方文档明确此方法就是给非沙盒应用用的。

  排查同类问题的通用方法——新版插件可能新增运行时校验：
  ```bash
  # 在已安装的 macOS 插件里搜 entitlement 校验
  grep -rlniE "SecTaskCopyValueForEntitlement|ENTITLEMENT_|isSandboxed" \
    ~/.pub-cache/hosted/pub.dev/<plugin>-*/
  ```
  本项目 9 个 macOS 插件中只有 `file_picker_darwin` 做此类校验。

  上架 App Store 前需要重新评估：若改为开启沙盒，则必须声明
  `com.apple.security.files.user-selected.read-only`，并且**用户手输的
  任意路径将无法读取**（沙盒只放行 picker 选过的文件），
  届时要同步改掉本地音源页的手输路径功能。

- **`AppConfig` 里的 host 与 path 必须分开定义。**
  曾把 `'zt.999087.com/app/muyu/repo.php'` 整个当成 `Uri` 的 host，
  导致每次敲击都抛 `FormatException`。相关加固见 `TelemetryService._guard()`。

## 质量门禁

提交前必须满足：

```bash
flutter analyze   # No issues found!（warning 与 info 同样算失败）
flutter test      # All tests passed!
```

- 资源清单（`AssetCatalog`）与 `assets/` 目录的一致性由
  `test/constants/asset_catalog_test.dart` 兜底——新增图片 / 音效时
  记得同步清单，否则测试会失败（这正是我们要的效果，避免运行时白屏）。
- 注释用中文，风格与现有代码保持一致：解释「为什么」而不是复述「做了什么」。
- 不要为了修一个 bug 顺手重构周围代码。