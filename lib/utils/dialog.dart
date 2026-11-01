import 'package:flutter/material.dart';
import '../config/theme.dart';

class AppDialog {
  /// ความกว้างของหน้าต่าง: หนึ่งในสี่ของจอแต่ไม่แคบกว่า 420 (จอเล็กกว่านั้นใช้เต็มจอ) ใช้บนมือถือได้
  static double _width(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    return (w * 0.25).clamp(420.0, double.infinity).clamp(0.0, w);
  }

  // Success Dialog
  static Future<void> showSuccess(
    BuildContext context,
    String message, {
    VoidCallback? onPressed,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Center(
          child: Material(
            type: MaterialType.transparency,
            child: SizedBox(
              width: _width(context),
              child: Dialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                elevation: 0,
                backgroundColor: Colors.transparent,
                child: _buildDialogWithIcon(
                  context,
                  icon: Icons.check_circle,
                  iconColor: AppTheme.successColor,
                  title: 'สำเร็จ!',
                  message: message,
                  buttonText: 'ตกลง',
                  onPressed: onPressed,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // Error Dialog
  static Future<void> showError(
    BuildContext context,
    String message, {
    VoidCallback? onPressed,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Center(
          child: Material(
            type: MaterialType.transparency,
            child: SizedBox(
              width: _width(context),
              child: Dialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                elevation: 0,
                backgroundColor: Colors.transparent,
                child: _buildDialogWithIcon(
                  context,
                  icon: Icons.error,
                  iconColor: AppTheme.dangerColor,
                  title: 'ข้อผิดพลาด',
                  message: message,
                  buttonText: 'ตกลง',
                  onPressed: onPressed,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // Info Dialog
  static Future<void> showInfo(
    BuildContext context,
    String message, {
    VoidCallback? onPressed,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Center(
          child: Material(
            type: MaterialType.transparency,
            child: SizedBox(
              width: _width(context),
              child: Dialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                elevation: 0,
                backgroundColor: Colors.transparent,
                child: _buildDialogWithIcon(
                  context,
                  icon: Icons.info,
                  iconColor: AppTheme.infoColor,
                  title: 'แจ้งเตือน',
                  message: message,
                  buttonText: 'ตกลง',
                  onPressed: onPressed,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // Warning Dialog
  static Future<void> showWarning(
    BuildContext context,
    String message, {
    VoidCallback? onPressed,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Center(
          child: Material(
            type: MaterialType.transparency,
            child: SizedBox(
              width: _width(context),
              child: Dialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                elevation: 0,
                backgroundColor: Colors.transparent,
                child: _buildDialogWithIcon(
                  context,
                  icon: Icons.warning,
                  iconColor: AppTheme.warningColor,
                  title: 'คำเตือน',
                  message: message,
                  buttonText: 'ตกลง',
                  onPressed: onPressed,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // Confirm Dialog (มีปุ่มยืนยันและยกเลิก)
  static Future<bool?> showConfirm(
    BuildContext context,
    String message, {
    String confirmText = 'ยืนยัน',
    String cancelText = 'ยกเลิก',
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Center(
          child: Material(
            type: MaterialType.transparency,
            child: SizedBox(
              // หนึ่งในสี่ของจอ แต่ไม่แคบกว่า 420 (จอเล็กกว่านั้นใช้เต็มจอ)
              // เดิมใช้ 25% ตรง ๆ บนจอแคบปุ่มสองปุ่มจะไม่พอที่
              width: (MediaQuery.of(context).size.width * 0.25)
                  .clamp(420.0, double.infinity)
                  .clamp(0.0, MediaQuery.of(context).size.width),
              child: Dialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                elevation: 0,
                backgroundColor: Colors.transparent,
                child: _buildConfirmDialog(
                  context,
                  message: message,
                  confirmText: confirmText,
                  cancelText: cancelText,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // Private method สำหรับสร้าง Dialog พร้อมไอคอน
  static Widget _buildDialogWithIcon(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String message,
    required String buttonText,
    VoidCallback? onPressed,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.3),
            spreadRadius: 5,
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min, // ✅ ให้ขนาดตามเนื้อหา
        children: [
          // ไอคอน
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 64, color: iconColor),
          ),
          const SizedBox(height: 16),
          // หัวข้อ
          Text(
            title,
            style: const TextStyle(
              fontFamily: 'NotoSansThai',
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          // ข้อความ
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'NotoSansThai',
              fontSize: 16,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 24),
          // ปุ่ม
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                if (onPressed != null) onPressed();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: iconColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
              ),
              child: Text(
                buttonText,
                style: const TextStyle(
                  fontFamily: 'NotoSansThai',
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Private method สำหรับ Confirm Dialog
  static Widget _buildConfirmDialog(
    BuildContext context, {
    required String message,
    required String confirmText,
    required String cancelText,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.3),
            spreadRadius: 5,
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ไอคอน
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.primaryPale,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.question_mark,
              size: 64,
              color: AppTheme.primaryColor,
            ),
          ),
          const SizedBox(height: 16),
          // หัวข้อ
          const Text(
            'ยืนยันการดำเนินการ',
            style: TextStyle(
              fontFamily: 'NotoSansThai',
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          // ข้อความ
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'NotoSansThai',
              fontSize: 16,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 24),
          // ปุ่ม
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context, false),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey.shade200,
                    foregroundColor: Colors.grey.shade800,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    cancelText,
                    style: const TextStyle(
                      fontFamily: 'NotoSansThai',
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                  child: Text(
                    confirmText,
                    style: const TextStyle(
                      fontFamily: 'NotoSansThai',
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
