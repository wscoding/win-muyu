import Cocoa
import FlutterMacOS

/// Dart 与 Swift 两侧共用的通道方法名。
///
/// 改动时必须同步 `lib/services/window/desktop_window_service.dart`
/// 中的 `MacosNative`。
enum NativeChannel {
  static let name = "cc.iqg.prue_widgets/native"

  // Dart -> Swift
  static let isPrimaryInstance = "isPrimaryInstance"
  static let activateExistingInstance = "activateExistingInstance"
  static let configureOverlayWindow = "configureOverlayWindow"
  static let setDockIconVisible = "setDockIconVisible"

  // Swift -> Dart
  static let onActivateRequested = "onActivateRequested"
}

/// 单实例守卫。
///
/// Windows 侧由 `windows_single_instance` 插件用命名管道实现；
/// macOS 没有对应的插件，这里用「Application Support 下的文件锁 + 分布式通知」：
/// - 首个实例用 `flock(LOCK_EX | LOCK_NB)` 占住锁文件；
/// - 后启动的实例拿不到锁，于是发一条分布式通知让首实例把窗口前置，自己退出。
///
/// 之所以不用 `NSRunningApplication.runningApplications(withBundleIdentifier:)`：
/// 应用启动过程中自身也会出现在该列表里，判定天然存在竞态；`flock` 是原子的。
final class SingleInstanceGuard {
  static let shared = SingleInstanceGuard()

  /// 首实例收到该通知时把自己的窗口前置
  static let activateNotification = Notification.Name("cc.iqg.prueWidgets.activate")

  private var lockFileDescriptor: Int32 = -1
  private(set) var isPrimary = false

  private init() {}

  /// 尝试成为首实例。拿到锁返回 `true`。
  @discardableResult
  func acquire() -> Bool {
    let fileManager = FileManager.default
    let supportDir =
      fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
      ?? URL(fileURLWithPath: NSTemporaryDirectory())

    let bundleId = Bundle.main.bundleIdentifier ?? "prue_widgets"
    let folder = supportDir.appendingPathComponent(bundleId, isDirectory: true)

    do {
      try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
    } catch {
      // 建目录失败（例如权限问题）时退化成「总是首实例」，
      // 宁可多开一个窗口，也不要因为锁文件问题完全无法启动。
      NSLog("[PrueWidgets] 无法创建锁文件目录，跳过单实例检查：\(error)")
      isPrimary = true
      return true
    }

    let lockPath = folder.appendingPathComponent(".instance.lock").path
    lockFileDescriptor = open(lockPath, O_CREAT | O_RDWR, 0o644)
    guard lockFileDescriptor != -1 else {
      NSLog("[PrueWidgets] 无法打开锁文件，跳过单实例检查")
      isPrimary = true
      return true
    }

    if flock(lockFileDescriptor, LOCK_EX | LOCK_NB) == 0 {
      isPrimary = true
      return true
    }

    // 锁被别的实例持有
    close(lockFileDescriptor)
    lockFileDescriptor = -1
    isPrimary = false
    return false
  }

  /// 通知首实例把自己前置
  func activatePrimary() {
    DistributedNotificationCenter.default().postNotificationName(
      SingleInstanceGuard.activateNotification,
      object: nil,
      userInfo: nil,
      deliverImmediately: true
    )
  }
}

@main
class AppDelegate: FlutterAppDelegate {
  override func applicationWillFinishLaunching(_ notification: Notification) {
    super.applicationWillFinishLaunching(notification)

    // 单实例判定要在任何窗口显示之前完成
    guard SingleInstanceGuard.shared.acquire() else {
      SingleInstanceGuard.shared.activatePrimary()
      NSLog("[PrueWidgets] 已有实例在运行，退出当前进程")
      NSApp.terminate(nil)
      return
    }

    // 纯桌面小部件：不进 Dock、不占 ⌘Tab、不显示菜单栏。
    // 与 Info.plist 里的 LSUIElement 双重保证，Dart 侧可通过
    // setDockIconVisible 再次切换。
    NSApp.setActivationPolicy(.accessory)

    DistributedNotificationCenter.default().addObserver(
      self,
      selector: #selector(handleActivateRequest(_:)),
      name: SingleInstanceGuard.activateNotification,
      object: nil,
      suspensionBehavior: .deliverImmediately
    )
  }

  /// 收到「被重复启动」的通知：把已有窗口顶到最前，并告知 Flutter 层
  @objc private func handleActivateRequest(_ notification: Notification) {
    DispatchQueue.main.async {
      MainFlutterWindow.active?.requestActivateFromNative()
    }
  }

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    // 常驻菜单栏图标，隐藏 / 关闭窗口都不等于退出应用
    return false
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }

  override func applicationWillTerminate(_ notification: Notification) {
    DistributedNotificationCenter.default().removeObserver(self)
    super.applicationWillTerminate(notification)
  }
}