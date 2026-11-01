import 'dart:async';

import 'package:flutter/material.dart';
import '../config/theme.dart';

extension SnackBarHelper on BuildContext {
  void showSuccessSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(this).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: AppTheme.successColor,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(this).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: AppTheme.dangerColor,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void showInfoSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(this).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.info_outline, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: AppTheme.infoColor,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  /// ข้อความแจ้งเตือนที่ลอยอยู่เหนือ dialog
  ///
  /// SnackBar ปกติถูก ScaffoldMessenger วางไว้ใน Scaffold ของหน้าเบื้องหลัง
  /// เมื่อมี dialog เปิดอยู่ ทั้งตัว dialog และฉากหลังสีดำจะบังจนอ่านไม่ออก
  /// ตัวนี้จึงแทรกเป็น OverlayEntry ใน root overlay แทน ซึ่งซ้อนอยู่เหนือ
  /// route ของ dialog เสมอ
  ///
  /// แตะที่ข้อความเพื่อปิดก่อนเวลาได้
  void showOverlayMessage(
    String message, {
    IconData icon = Icons.info_outline,
    Color? background,
    Duration duration = const Duration(seconds: 3),
  }) {
    final overlay = Overlay.maybeOf(this, rootOverlay: true);
    if (overlay == null) return;

    late final OverlayEntry entry;
    Timer? timer;
    var removed = false;

    // กันถอดซ้ำ ทั้งจากการแตะปิดเองและจากตัวจับเวลา
    void dismiss() {
      if (removed) return;
      removed = true;
      timer?.cancel();
      entry.remove();
    }

    entry = OverlayEntry(
      builder: (context) => Positioned(
        left: 24,
        right: 24,
        bottom: 32,
        child: SafeArea(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 180),
            builder: (context, t, child) => Opacity(
              opacity: t,
              child: Transform.translate(
                offset: Offset(0, 12 * (1 - t)),
                child: child,
              ),
            ),
            child: Center(
              child: Material(
                color: background ?? AppTheme.primaryColor,
                elevation: 8,
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: dismiss,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 14,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(icon, color: Colors.white, size: 20),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Text(
                            message,
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    overlay.insert(entry);
    timer = Timer(duration, dismiss);
  }
}
// use // Use:
// context.showSuccessSnackBar('ยินดีต้อนรับ คุณ${authProvider.displayName}')
// context.showOverlayMessage('ข้อความที่ต้องเห็นแม้มี dialog เปิดอยู่')
