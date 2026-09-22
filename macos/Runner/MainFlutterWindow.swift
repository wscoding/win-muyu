import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  /// 供 [AppDelegate] 在收到「重复启动」通知时回调当前窗口
  static weak var active: MainFlutterWindow?

  private var nativeChannel: FlutterMethodChannel?
  private weak var flutterViewController: FlutterViewController?

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    self.flutterViewController = flutterViewController
    MainFlutterWindow.active = self

    // 关键：窗口与 FlutterView 的背景色是**分开保存**的。
    // FlutterView 不显式设置时默认是黑色，只把 NSWindow 设成透明，
    // 结果仍是一块不透明的黑底（FlutterViewController.h 有明确说明）。
    flutterViewController.backgroundColor = .clear
    backgroundColor = .clear

    // 先隐藏窗口：悬浮样式（透明 / 无边框 / 置顶）要等 Dart 侧调用
    // configureOverlayWindow 之后才生效，否则会闪一下带标题栏的默认窗口。
    self.alphaValue = 0

    setUpNativeChannel(with: flutterViewController)
    applyOverlayAppearance()

    super.awakeFromNib()
  }

  // MARK: - 原生通道

  private func setUpNativeChannel(with controller: FlutterViewController) {
    let channel = FlutterMethodChannel(
      name: NativeChannel.name,
      binaryMessenger: controller.engine.binaryMessenger
    )

    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else {
        result(
          FlutterError(
            code: "window_released",
            message: "窗口已释放",
            details: nil
          ))
        return
      }

      switch call.method {
      case NativeChannel.isPrimaryInstance:
        result(SingleInstanceGuard.shared.isPrimary)

      case NativeChannel.activateExistingInstance:
        SingleInstanceGuard.shared.activatePrimary()
        result(nil)

      case NativeChannel.configureOverlayWindow:
        self.applyOverlayAppearance()
        self.alphaValue = 1
        result(nil)

      case NativeChannel.setDockIconVisible:
        let visible = (call.arguments as? Bool) ?? false
        NSApp.setActivationPolicy(visible ? .regular : .accessory)
        result(nil)

      default:
        result(FlutterMethodNotImplemented)
      }
    }

    nativeChannel = channel
  }

  // MARK: - 悬浮窗口样式

  /// 透明、无边框、置顶、在所有 Space 可见。
  ///
  /// 必须在 `window_manager.setAsFrameless()` 之后调用：那个插件在 macOS 上
  /// 会把 `isOpaque` 重新设回 `true`，只有这里覆盖掉才是真正的透明窗口。
  private func applyOverlayAppearance() {
    isOpaque = false
    backgroundColor = .clear
    hasShadow = false

    // window_manager 的 setBackgroundColor 只改 NSWindow，
    // 这里必须再压一次 FlutterView 的背景色，否则仍是黑底。
    flutterViewController?.backgroundColor = .clear
    titleVisibility = .hidden
    titlebarAppearsTransparent = true
    isMovableByWindowBackground = true
    ignoresMouseEvents = false

    // window_manager 的 setTitleBarStyle 有可能把红黄绿按钮带回来，这里一律隐藏
    for buttonType in [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton] {
      standardWindowButton(buttonType)?.isHidden = true
    }

    // 悬浮在所有普通窗口之上，但不盖住系统级 UI（菜单栏、通知中心等）
    level = .floating

    // 每个 Space 都显示；切换 Space 时不跟着移动；支持全屏应用之上叠加
    collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
  }

  /// 被重复启动时把自己顶到最前，并让 Flutter 层同步显示状态
  func requestActivateFromNative() {
    alphaValue = 1
    makeKeyAndOrderFront(nil)
    orderFrontRegardless()
    // 10.6+ 可用，且不像 NSApp.activate(ignoringOtherApps:) 那样在新 SDK 上被弃用
    NSRunningApplication.current.activate(options: [.activateAllWindows])
    nativeChannel?.invokeMethod(NativeChannel.onActivateRequested, arguments: nil)
  }
}