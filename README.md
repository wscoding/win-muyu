# Prue Widgets · 电子木鱼

> 🙏 敲电子木鱼，颂赛博真经，见机甲佛祖。
> 主打一个虔诚（娱乐向）。

一个**常驻桌面的悬浮小组件**：无边框、透明背景、始终置顶、不占 Dock / 任务栏。
左键敲击功德 +1，长按切换黑白，右键打开设置面板。

**v3.0 新增 macOS 原生支持**（单实例、隐藏 Dock、菜单栏图标、全局快捷键）。

---

## 功能

**敲击**
- 左键单击：功德 +1，播放音效并飘出提示
- 左键长按：黑色 / 白色图案切换
- 右键单击：打开设置面板
- 按住拖动：移动窗口位置

**自定义**
- 42 种内置木鱼图案
- 24 种内置音效，也可用本地音频文件或网络直链
- 播放速度 0.5x – 2.0x 可调
- 自定义功德文字与祝福语池（满 100 次后随机展示）
- 自动敲击：可调间隔 0.2 – 6.7 次/秒

**数据**
- 敲击次数统计与等级评价
- 可选匿名统计上报（默认关闭，见下文）

**系统集成**
- 托盘 / 菜单栏图标：显示隐藏、重置次数、退出
- 全局快捷键 `⌥⌘M`：唤起 / 收起木鱼（应用失焦时同样有效）
- 单实例保护：重复启动会唤起已有窗口

---

## 下载安装

### Windows

从 [Releases](https://github.com/wscoding/win-muyu/releases) 下载 `PrueWidgets-Setup.exe`，
双击安装。首次安装建议勾选「创建桌面快捷方式」，否则容易找不到。

**兼容性**：需要 Windows 10 1809 或更高版本、x64 架构、内存 4GB 以上。

若提示 `vcruntime140_1.dll 无法继续执行代码`，请安装
[Microsoft Visual C++ 运行库](https://aka.ms/vs/17/release/vc_redist.x64.exe)。

### macOS

从 Releases 下载 `.dmg`，或自行构建：

```bash
flutter build macos --release
# 产物：build/macos/Build/Products/Release/PrueWidgets.app
```

首次打开若被 Gatekeeper 拦下，执行：

```bash
xattr -dr com.apple.quarantine /Applications/PrueWidgets.app
```

**系统要求**：macOS 10.15 (Catalina) 或更高版本。

> **关于 Dock 图标**：应用以 `LSUIElement` 模式运行，不会出现在 Dock 与 ⌘Tab 中，
> 交互入口是菜单栏图标与 `⌥⌘M`。这是桌面小部件的常规做法。

---

## 从源码运行

需要 Flutter 3.41 或更高版本。

```bash
git clone https://github.com/wscoding/win-muyu.git
cd win-muyu
flutter pub get
flutter run -d macos      # 或 -d windows
```

打包：

```bash
flutter build macos --release
flutter build windows --release
```

Windows 安装包：先 `flutter build windows --release`，再用 Inno Setup 编译
[windows/installer/PrueWidgets.iss](windows/installer/PrueWidgets.iss)。

### 质量检查

```bash
flutter analyze   # 应输出 No issues found!
flutter test      # 应全部通过
```

---

## 关于统计上报

v2 每次敲击都会向作者服务器上报次数。**v3 默认关闭上报**，原因是
原后端已下线。你可以在「设置 → 数据 → 匿名统计上报」中手动开启，
但在后端重写完成前不会有实际效果。

客户端已做以下保证：
- 上报失败不影响任何功能，也不会让敲击变卡
- 所有请求 5 秒超时，异常一律吞掉
- 后端整体开关关闭时，不产生任何网络请求

后端接口约定见 [docs/backend-api.md](docs/backend-api.md)。

---

## 项目结构

```
lib/
├── constants/   键名、配置、尺寸、资源清单
├── models/      纯数据模型
├── services/    窗口 / 音频 / 存储 / 上报 / 托盘 / 快捷键
├── state/       Riverpod 状态
└── ui/          木鱼本体、设置菜单与各子页
macos/           Swift 原生代码（单实例、透明置顶、原生通道）
windows/         C++ runner 与安装脚本
```

架构说明、开发约定与**已知陷阱**见 [AGENTS.md](AGENTS.md)。

---

## 许可

MIT License，版权所有 (c) 2023 无书 (wushu)。

软件按「原样」提供，不作任何明示或暗示的保证。

---

## 联系与支持

- 邮箱：2821981550@qq.com
- QQ 群：574237747
- 官网：http://pw.0gg.cc/
- 相关帖：https://www.52pojie.cn/thread-1796636-1-1.html
- 视频教程：https://www.bilibili.com/video/BV1sV4y1m7LD/

开发不易，欢迎打赏支持（见应用内「更多 → 赞助」）。
