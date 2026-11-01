// lib/widgets/passkey_unavailable_dialog.dart
// ตรวจก่อนสแกนลายนิ้วมือว่าเครื่องนี้ใช้ได้หรือไม่ ใช้ไม่ได้ = หน้าต่างแจ้งกลางจอ ค้างไว้จนผู้ใช้กดปิดเอง
// (มีปุ่มรองให้ใช้มือถือ / กุญแจ USB แทน สำหรับเครื่องที่มี Bluetooth หรือกุญแจ)
import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../utils/passkey.dart';

/// ฟอนต์ของหน้าต่างนี้ (ชุดเดียวกับหน้าต่างบัญชีผู้ใช้)
const String _font = 'NotoSansThai';

/// ตรวจว่าเครื่องนี้สแกนลายนิ้วมือ/passkey ในเครื่องได้หรือไม่ ก่อนเรียก [PasskeyAuthenticator.get]
/// ใช้ได้ = คืน true ให้ผู้เรียกทำงานต่อ; ใช้ไม่ได้ = แสดง [PasskeyUnavailableDialog] รอจนปิด
/// แล้วคืน true เมื่อผู้ใช้กดปุ่มรอง "ใช้มือถือ / กุญแจ USB แทน" (ทำงานต่อ เบราว์เซอร์ขึ้น QR / รอกุญแจเอง)
/// กดปิด / แตะนอกหน้าต่าง = false
/// ใช้ตัวเดียวกันทั้งปุ่มลายนิ้วมือบนแถบบนและปุ่มในหน้าเข้าสู่ระบบ
Future<bool> ensurePasskeyAvailable(
  BuildContext context,
  PasskeyAuthenticator authenticator,
) async {
  if (await authenticator.isPlatformAuthenticatorAvailable()) return true;
  if (!context.mounted) return false;
  return await showPasskeyUnavailableDialog(context);
}

/// แสดงหน้าต่างแจ้งว่าใช้การสแกนลายนิ้วมือไม่ได้ รอจนผู้ใช้ปิด
/// คืน true = ผู้ใช้เลือกใช้มือถือ / กุญแจ USB แทน
Future<bool> showPasskeyUnavailableDialog(BuildContext context) async {
  final useOther = await showDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (_) => const PasskeyUnavailableDialog(),
  );
  return useOther ?? false;
}

/// หน้าต่างแจ้งว่าเครื่องนี้ใช้การสแกนลายนิ้วมือไม่ได้ สีตามธีมที่ผู้ใช้เลือก
/// ไม่ปิดเอง ค้างไว้จนกดปุ่ม "ปิด" หรือแตะนอกหน้าต่าง
/// ปุ่มรอง [otherDeviceLabel] ปิดหน้าต่างแล้วให้ผู้เรียกสแกนต่อด้วยมือถือ (ต้องมี Bluetooth) หรือกุญแจ USB
class PasskeyUnavailableDialog extends StatelessWidget {
  const PasskeyUnavailableDialog({super.key});

  /// ข้อความที่แสดง
  static const String message = 'ไม่สามารถใช้งานการสแกนลายนิ้วมือได้';

  /// ป้ายปุ่มรอง: ใช้มือถือสแกน QR หรือกุญแจ USB แทนตัวสแกนในเครื่อง
  static const String otherDeviceLabel = 'ใช้มือถือ / กุญแจ USB แทน';

  /// คำอธิบายใต้ปุ่มรอง (สแกนด้วยมือถือต้องใช้ Bluetooth ยืนยันว่ามือถืออยู่ใกล้เครื่อง)
  static const String otherDeviceHint =
      'ใช้มือถือได้เมื่อเครื่องนี้เปิด Bluetooth อยู่';

  /// หัวข้อกล่องทางเลือกใต้ปุ่มรอง (ผู้ใช้สั่งเพิ่ม 29 ต.ค. 2569)
  static const String alternativesTitle =
      'ทางเลือกสำหรับ PC ที่ไม่มีตัวสแกนนิ้วและไม่มี Bluetooth';

  /// ทางเลือกทีละข้อ
  static const List<String> alternatives = [
    'ตั้ง Windows Hello แบบ PIN (Settings → Accounts → Sign-in options → PIN) '
        'ไม่ต้องมีอุปกรณ์เพิ่ม ปุ่ม "ลายนิ้วมือ / Windows Hello" จะใช้ได้ทันที'
        'โดยกรอก PIN แทนการสแกนนิ้ว และหน้าต่างนี้จะไม่ขึ้นอีก',
    'เสียบตัวรับ Bluetooth แบบ USB ราคาไม่แพง แล้วใช้มือถือสแกนได้ตามปกติ',
    'เสียบกุญแจ USB (security key) เช่น YubiKey',
    'เข้าด้วยชื่อผู้ใช้และรหัสผ่าน หรือ ThaID ตามเดิม',
  ];

  @override
  Widget build(BuildContext context) {
    final primary = AppTheme.primaryColor;
    // ปิดหน้าต่าง useOther = true เมื่อผู้ใช้เลือกใช้มือถือ / กุญแจ USB แทน
    void close({bool useOther = false}) => Navigator.of(context).pop(useOther);
    return Dialog(
      key: const ValueKey('passkey-unavailable-dialog'),
      backgroundColor: AppTheme.cardColor,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        // จอเตี้ย (มือถือแนวนอน) เลื่อนดูได้ ไม่ล้น
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // แถบหัวสีหลักของธีม
              Container(
                padding: const EdgeInsets.symmetric(vertical: 20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppTheme.primaryDark, primary],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: const BoxDecoration(
                      color: AppTheme.cardColor,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.fingerprint, size: 44, color: primary),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
                child: Text(
                  PasskeyUnavailableDialog.message,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: _font,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryDark,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 10),
                child: ElevatedButton(
                  key: const ValueKey('passkey-unavailable-close'),
                  onPressed: close,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'ปิด',
                    style: TextStyle(
                      fontFamily: _font,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              // ปุ่มรอง: ไปขั้นสแกนต่อ เบราว์เซอร์ให้เลือกมือถือ (QR) หรือกุญแจ USB เอง
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 6),
                child: OutlinedButton.icon(
                  key: const ValueKey('passkey-unavailable-other'),
                  onPressed: () => close(useOther: true),
                  icon: const Icon(Icons.qr_code_2, size: 20),
                  label: const Text(
                    PasskeyUnavailableDialog.otherDeviceLabel,
                    style: TextStyle(
                      fontFamily: _font,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: primary,
                    side: BorderSide(color: primary),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 14),
                child: Text(
                  PasskeyUnavailableDialog.otherDeviceHint,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: _font,
                    fontSize: 13,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ),
              // กล่องทางเลือกเมื่อเครื่องไม่มีทั้งตัวสแกนและ Bluetooth
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
                child: Container(
                  key: const ValueKey('passkey-unavailable-alternatives'),
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryPale,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.lightbulb_outline,
                            size: 18,
                            color: primary,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              PasskeyUnavailableDialog.alternativesTitle,
                              style: TextStyle(
                                fontFamily: _font,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.primaryDark,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      for (final (i, item)
                          in PasskeyUnavailableDialog.alternatives.indexed)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: 20,
                                child: Text(
                                  '${i + 1}.',
                                  style: TextStyle(
                                    fontFamily: _font,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: primary,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  item,
                                  style: const TextStyle(
                                    fontFamily: _font,
                                    fontSize: 13,
                                    height: 1.4,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
