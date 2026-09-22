import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../constants/app_constants.dart';

/// 敲击时飘出的功德提示。
///
/// v2 的 `toast.dart` 每次敲击都 `insert` 一个新的 [OverlayEntry]，
/// 并且只在特定时间差条件下才 `remove()`；高频连击时会残留大量
/// 未移除的浮层（内存泄漏 + 文字叠影）。这里改为：
/// - 同一时刻只保留一个提示，新提示直接替换旧的；
/// - 由 [AnimatedOpacity] 驱动淡入淡出，动画结束后自行移除。
class MeritToast {
  const MeritToast._();

  static OverlayEntry? _currentEntry;

  /// 显示一条功德提示。缺少 Overlay 时静默跳过。
  static void show(
    BuildContext context, {
    required String text,
    required Color textColor,
  }) {
    final overlay = Overlay.maybeOf(context);
    if (overlay == null) return;

    _removeCurrent();

    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => _MeritToastBubble(
        text: text,
        textColor: textColor,
        onFinished: () {
          if (identical(_currentEntry, entry)) {
            _removeCurrent();
          }
        },
      ),
    );
    _currentEntry = entry;
    overlay.insert(entry);
  }

  static void _removeCurrent() {
    final entry = _currentEntry;
    _currentEntry = null;
    if (entry == null) return;
    // 已经移除过的 entry 再次 remove 会抛异常
    if (entry.mounted) entry.remove();
  }
}

class _MeritToastBubble extends StatefulWidget {
  const _MeritToastBubble({
    required this.text,
    required this.textColor,
    required this.onFinished,
  });

  final String text;
  final Color textColor;
  final VoidCallback onFinished;

  @override
  State<_MeritToastBubble> createState() => _MeritToastBubbleState();
}

class _MeritToastBubbleState extends State<_MeritToastBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<Offset> _offset;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppConstants.toastFadeIn,
      reverseDuration: AppConstants.toastFadeOut,
    );
    _opacity = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _offset = Tween<Offset>(
      begin: const Offset(0, 0.35),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _run();
  }

  Future<void> _run() async {
    await _controller.forward();
    await Future<void>.delayed(AppConstants.toastHold);
    if (!mounted) return;
    await _controller.reverse();
    if (!mounted) return;
    widget.onFinished();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Align(
        alignment: const Alignment(0, -0.55),
        child: FadeTransition(
          opacity: _opacity,
          child: SlideTransition(
            position: _offset,
            child: Text(
              widget.text,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: widget.textColor,
                fontSize: 28.sp,
                fontWeight: FontWeight.w600,
                // 桌面壁纸颜色不可控，加一层描边阴影保证任何背景下都能看清
                shadows: [
                  Shadow(
                    color: widget.textColor.computeLuminance() > 0.5
                        ? Colors.black54
                        : Colors.white70,
                    blurRadius: 3,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}