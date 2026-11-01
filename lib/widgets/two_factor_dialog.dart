import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/theme.dart';
import '../models/two_factor.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../utils/logger.dart';
import '../utils/snackbar_helper.dart';
import 'account_form.dart';
import 'qr_view.dart';

/// เมนู "ยืนยันตัวตนสองขั้น (2FA)" ของบัญชีผู้ใช้ — ใช้ร่วมกันทั้งเมนูข้างและเมนูผู้ใช้บนแถบบน
///
/// [context] ต้องยังใช้ได้ตลอดจนหน้าต่างปิด เมนูข้างจึงส่ง context ของ navigator ชั้นนอกมา
Future<void> showTwoFactorDialog(
  BuildContext context,
  AuthProvider authProvider,
) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => TwoFactorDialog(apiService: ApiService()),
  );
}

/// ขั้นของหน้าต่างตั้งค่า 2FA
enum _Step {
  /// กำลังโหลดสถานะ
  loading,

  /// แสดงสถานะเปิด/ปิด พร้อมปุ่มเปิดใช้หรือปิดใช้
  status,

  /// เปิดใช้: ถามรหัสผ่านปัจจุบันก่อน (backend บังคับทุก session)
  password,

  /// เปิดใช้: แสดง QR + รหัสตั้งค่า แล้วรอรหัส 6 หลักเพื่อยืนยัน
  setup,

  /// ปิดใช้: ถามรหัสผ่านปัจจุบัน + รหัส 6 หลัก
  disable,
}

/// หน้าต่างตั้งค่าการยืนยันตัวตนสองขั้นของบัญชีตัวเอง
///
/// 2FA เป็นทางเลือกของผู้ใช้ ถามรหัส 6 หลักเฉพาะตอนเข้าสู่ระบบด้วยชื่อผู้ใช้/รหัสผ่าน (ThaID / passkey ไม่ถาม)
///
/// - เปิดใช้: รหัสผ่านปัจจุบัน -> QR (สร้างในเครื่องจาก otpauth_uri) + รหัสตั้งค่า -> รหัส 6 หลัก -> สำเร็จ
/// - ปิดใช้: รหัสผ่านปัจจุบัน + รหัส 6 หลัก (backend ฌาปนกิจบังคับทั้งสองอย่างทุก session)
///   มือถือหาย = ติดต่อผู้ดูแลระบบให้ปิดให้
///
/// รหัสตั้งค่าและ QR อยู่ใน state ของหน้าต่างนี้เท่านั้น ไม่เก็บลงที่เก็บของเบราว์เซอร์ ไม่ log
/// ไม่ส่งไปบริการภายนอก และทิ้งทันทีเมื่อเปิดใช้สำเร็จ ยกเลิก หรือปิดหน้าต่าง
class TwoFactorDialog extends StatefulWidget {
  final ApiService apiService;

  const TwoFactorDialog({super.key, required this.apiService});

  /// คำอธิบายสั้น ๆ ว่า 2FA คืออะไร แสดงตอนยังไม่เปิดใช้
  static const String aboutMessage =
      'เมื่อเปิดใช้ การเข้าสู่ระบบด้วยชื่อผู้ใช้และรหัสผ่านจะถามรหัส 6 หลัก'
      'จากแอป Authenticator ในมือถือเพิ่มอีกขั้น\n'
      'การเข้าสู่ระบบด้วย ThaID หรือลายนิ้วมือ/Windows Hello ไม่ถามรหัสนี้';

  /// คำแนะนำเมื่อมือถือหาย/ใช้แอปไม่ได้
  static const String lostPhoneHelp =
      'ใช้แอป Authenticator ไม่ได้ (เช่น มือถือหาย): ติดต่อผู้ดูแลระบบให้ปิดการยืนยันตัวตนสองขั้นให้';

  @override
  State<TwoFactorDialog> createState() => _TwoFactorDialogState();
}

class _TwoFactorDialogState extends State<TwoFactorDialog> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _codeController = TextEditingController();

  _Step _step = _Step.loading;
  bool _enabled = false;

  /// โหลดสถานะสำเร็จแล้ว (ไม่สำเร็จ = ไม่เดาว่าเปิดหรือปิด ให้กดลองใหม่)
  bool _statusKnown = false;
  bool _busy = false;
  bool _obscurePassword = true;
  String? _error;
  String? _success;

  /// ข้อมูลตั้งค่าที่กำลังแสดง (ความลับ) มีค่าเฉพาะระหว่างขั้น [_Step.setup]
  TwoFactorSetup? _setup;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  @override
  void dispose() {
    // ทิ้งความลับออกจาก state ก่อนหน้าต่างหายไป
    _setup = null;
    _passwordController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  String _message(Object e) => e.toString().replaceAll('Exception: ', '');

  Future<void> _loadStatus() async {
    // เรียกครั้งแรกจาก initState (ยังเป็นขั้น loading อยู่แล้ว) ไม่ต้อง setState
    if (_step != _Step.loading) {
      setState(() {
        _step = _Step.loading;
        _error = null;
      });
    }
    try {
      final enabled = await widget.apiService.twoFactorStatus();
      if (!mounted) return;
      setState(() {
        _enabled = enabled;
        _statusKnown = true;
        _step = _Step.status;
      });
    } catch (e) {
      if (AppLogger.on) AppLogger.w('โหลดสถานะ 2FA ไม่สำเร็จ');
      if (!mounted) return;
      setState(() {
        _statusKnown = false;
        _error = _message(e);
        _step = _Step.status;
      });
    }
  }

  /// กลับหน้าสถานะ ทิ้งทุกอย่างที่กรอกค้างและข้อมูลตั้งค่า
  void _backToStatus({String? success}) {
    _passwordController.clear();
    _codeController.clear();
    setState(() {
      _setup = null;
      _busy = false;
      _error = null;
      _success = success;
      _step = _Step.status;
    });
  }

  /// กดปุ่ม "เปิดใช้ 2FA": ถามรหัสผ่านปัจจุบันก่อน
  void _startEnable() {
    _passwordController.clear();
    setState(() {
      _error = null;
      _success = null;
      _step = _Step.password;
    });
  }

  /// ขอรหัสตั้งค่า + QR จาก backend แล้วไปขั้นสแกน
  Future<void> _requestSetup() async {
    if (_busy || !_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
      _success = null;
    });
    try {
      final setup = await widget.apiService.twoFactorSetup(
        _passwordController.text,
      );
      if (!mounted) return;
      // รหัสผ่านใช้ครั้งเดียว ไม่เก็บค้างในช่องกรอก
      _passwordController.clear();
      _codeController.clear();
      setState(() {
        _setup = setup;
        _busy = false;
        _step = _Step.setup;
      });
    } catch (e) {
      if (AppLogger.on) AppLogger.w('เริ่มตั้งค่า 2FA ไม่สำเร็จ');
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = _message(e);
      });
    }
  }

  /// ยืนยันรหัส 6 หลักจากแอปเพื่อเปิดใช้
  Future<void> _confirmEnable() async {
    if (_busy || !_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final message = await widget.apiService.twoFactorEnable(
        _codeController.text,
      );
      if (!mounted) return;
      _enabled = true;
      _backToStatus(success: message);
    } catch (e) {
      if (AppLogger.on) AppLogger.w('เปิดใช้ 2FA ไม่สำเร็จ');
      if (!mounted) return;
      _codeController.clear();
      setState(() {
        _busy = false;
        _error = _message(e);
      });
    }
  }

  /// กดปุ่ม "ปิดใช้ 2FA": ไปขั้นกรอกรหัสผ่าน + รหัส 6 หลัก
  void _startDisable() {
    _codeController.clear();
    _passwordController.clear();
    setState(() {
      _error = null;
      _success = null;
      _step = _Step.disable;
    });
  }

  Future<void> _confirmDisable() async {
    if (_busy || !_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
      _success = null;
    });
    try {
      final message = await widget.apiService.twoFactorDisable(
        currentPassword: _passwordController.text,
        code: _codeController.text,
      );
      if (!mounted) return;
      _enabled = false;
      _backToStatus(success: message);
    } catch (e) {
      if (AppLogger.on) AppLogger.w('ปิดใช้ 2FA ไม่สำเร็จ');
      if (!mounted) return;
      _codeController.clear();
      setState(() {
        _busy = false;
        _error = _message(e);
      });
    }
  }

  /// คัดลอกรหัสตั้งค่าไปคลิปบอร์ด (ผู้ใช้กดเอง) ไม่มีช่องว่างคั่น
  Future<void> _copySecret() async {
    final secret = _setup?.secret;
    if (secret == null || secret.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: secret));
    if (!mounted) return;
    context.showInfoSnackBar('คัดลอกรหัสตั้งค่าแล้ว');
  }

  TextStyle _text({
    double size = 14,
    FontWeight? weight,
    Color color = AppTheme.textPrimary,
  }) => TextStyle(
    fontFamily: kAccountFont,
    fontSize: size,
    fontWeight: weight,
    height: 1.5,
    color: color,
  );

  @override
  Widget build(BuildContext context) {
    return AccountDialogShell(
      icon: Icons.phonelink_lock,
      title: 'ยืนยันตัวตนสองขั้น (2FA)',
      subtitle: 'รหัส 6 หลักจากแอป Authenticator ในมือถือ',
      onClose: _busy ? null : () => Navigator.of(context).pop(),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_error != null) ...[
              AccountBanner.error(
                _error!,
                onClose: () => setState(() => _error = null),
              ),
              const SizedBox(height: 14),
            ],
            if (_success != null) ...[
              AccountBanner.success(
                _success!,
                onClose: () => setState(() => _success = null),
              ),
              const SizedBox(height: 14),
            ],
            ...switch (_step) {
              _Step.loading => const [
                Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ],
              _Step.status => _buildStatus(),
              _Step.password => _buildPassword(),
              _Step.setup => _buildSetup(),
              _Step.disable => _buildDisable(),
            },
          ],
        ),
      ),
    );
  }

  /// หน้าสถานะ: ป้ายเปิด/ปิด คำอธิบาย และปุ่มเปิดใช้หรือปิดใช้
  List<Widget> _buildStatus() {
    if (!_statusKnown) {
      return [
        AccountActionButtons(
          cancelText: 'ปิด',
          confirmText: 'ลองใหม่',
          confirmIcon: Icons.refresh,
          onCancel: () => Navigator.of(context).pop(),
          onConfirm: _loadStatus,
        ),
      ];
    }
    final color = _enabled ? AppTheme.successColor : AppTheme.textSecondary;
    return [
      Container(
        key: const ValueKey('two-factor-status'),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(
              _enabled ? Icons.verified_user : Icons.shield_outlined,
              color: color,
              size: 32,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('สถานะ', style: _text(size: 12, color: color)),
                  Text(
                    _enabled ? 'เปิดใช้อยู่' : 'ยังไม่ได้เปิดใช้',
                    style: _text(
                      size: 18,
                      weight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 14),
      AccountBanner.info(
        _enabled
            ? 'การเข้าสู่ระบบด้วยชื่อผู้ใช้และรหัสผ่านจะถามรหัส 6 หลักจากแอป Authenticator\n'
                  'เปลี่ยนมือถือ: ปิดใช้ก่อน แล้วเปิดใช้ใหม่เพื่อสแกน QR ด้วยมือถือเครื่องใหม่'
            : TwoFactorDialog.aboutMessage,
      ),
      const SizedBox(height: 22),
      AccountActionButtons(
        cancelText: 'ปิด',
        confirmText: _enabled ? 'ปิดใช้ 2FA' : 'เปิดใช้ 2FA',
        confirmIcon: _enabled ? Icons.lock_open : Icons.lock,
        loading: _busy,
        onCancel: () => Navigator.of(context).pop(),
        onConfirm: _enabled ? _startDisable : _startEnable,
      ),
    ];
  }

  Widget _passwordField() => AccountField(
    label: 'รหัสผ่านปัจจุบัน',
    hint: 'กรอกรหัสผ่านปัจจุบัน',
    icon: Icons.lock,
    controller: _passwordController,
    enabled: !_busy,
    obscureText: _obscurePassword,
    suffix: IconButton(
      icon: Icon(
        _obscurePassword ? Icons.visibility_off : Icons.visibility,
        color: Colors.grey,
      ),
      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
    ),
    validator: (v) =>
        (v == null || v.isEmpty) ? 'กรุณากรอกรหัสผ่านปัจจุบัน' : null,
  );

  /// เปิดใช้ขั้นแรก: ยืนยันด้วยรหัสผ่านปัจจุบัน
  List<Widget> _buildPassword() {
    return [
      Text(
        'กรอกรหัสผ่านปัจจุบันเพื่อยืนยันว่าเป็นเจ้าของบัญชี ก่อนเริ่มตั้งค่า',
        style: _text(),
      ),
      const SizedBox(height: 14),
      _passwordField(),
      const SizedBox(height: 22),
      AccountActionButtons(
        cancelText: 'ย้อนกลับ',
        confirmText: 'ถัดไป',
        confirmIcon: Icons.arrow_forward,
        loading: _busy,
        onCancel: () => _backToStatus(),
        onConfirm: _requestSetup,
      ),
    ];
  }

  /// เปิดใช้ขั้นสแกน: ขั้นตอนสั้น ๆ + QR + รหัสตั้งค่าแบบพิมพ์เอง + ช่องรหัส 6 หลัก
  List<Widget> _buildSetup() {
    final setup = _setup;
    if (setup == null) return const [];
    return [
      Text(
        '1. ติดตั้งแอป Authenticator ในมือถือ (เช่น Google Authenticator หรือ Microsoft Authenticator)\n'
        '2. ในแอป เลือกเพิ่มบัญชี แล้วสแกน QR ด้านล่าง หรือพิมพ์รหัสตั้งค่าเอง\n'
        '3. กรอกรหัส 6 หลักที่แอปแสดง แล้วกดยืนยัน',
        style: _text(),
      ),
      const SizedBox(height: 14),
      Center(
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: QrView(
            key: const ValueKey('two-factor-qr'),
            data: setup.otpauthUri,
            size: 200,
            semanticLabel: 'QR สำหรับตั้งค่าแอป Authenticator',
          ),
        ),
      ),
      const SizedBox(height: 14),
      Text(
        'รหัสตั้งค่า (สำหรับพิมพ์เอง)',
        style: _text(weight: FontWeight.w600),
      ),
      const SizedBox(height: 6),
      Container(
        padding: const EdgeInsets.only(left: 14, right: 4, top: 4, bottom: 4),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          children: [
            Expanded(
              child: SelectableText(
                setup.secretGrouped,
                key: const ValueKey('two-factor-secret'),
                style: const TextStyle(
                  fontFamily: kAccountFont,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.5,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
            IconButton(
              tooltip: 'คัดลอกรหัสตั้งค่า',
              icon: const Icon(Icons.copy, size: 20),
              onPressed: _copySecret,
            ),
          ],
        ),
      ),
      const SizedBox(height: 6),
      Text(
        'รหัสตั้งค่าเป็นความลับ อย่าส่งต่อให้ผู้อื่น และจะไม่แสดงอีกหลังปิดหน้าต่างนี้',
        style: _text(size: 12, color: AppTheme.textSecondary),
      ),
      const SizedBox(height: 16),
      TwoFactorCodeField(
        controller: _codeController,
        enabled: !_busy,
        onSubmitted: _confirmEnable,
        label: 'รหัส 6 หลักจากแอป',
      ),
      const SizedBox(height: 22),
      AccountActionButtons(
        confirmText: 'ยืนยันและเปิดใช้',
        confirmIcon: Icons.verified_user,
        loading: _busy,
        onCancel: () => _backToStatus(),
        onConfirm: _confirmEnable,
      ),
    ];
  }

  /// ปิดใช้: ยืนยันด้วยรหัสผ่านปัจจุบัน + รหัส 6 หลักปัจจุบัน
  List<Widget> _buildDisable() {
    return [
      Text(
        'กรอกรหัสผ่านปัจจุบันและรหัส 6 หลักจากแอป Authenticator เพื่อยืนยันการปิดใช้\n'
        'หลังปิดแล้ว การเข้าสู่ระบบด้วยรหัสผ่านจะไม่ถามรหัส 6 หลัก',
        style: _text(),
      ),
      const SizedBox(height: 14),
      _passwordField(),
      const SizedBox(height: 14),
      TwoFactorCodeField(
        controller: _codeController,
        enabled: !_busy,
        autofocus: false,
        onSubmitted: _confirmDisable,
      ),
      const SizedBox(height: 14),
      const AccountBanner.info(TwoFactorDialog.lostPhoneHelp),
      const SizedBox(height: 22),
      AccountActionButtons(
        cancelText: 'ย้อนกลับ',
        confirmText: 'ปิดใช้ 2FA',
        confirmIcon: Icons.lock_open,
        loading: _busy,
        onCancel: () => _backToStatus(),
        onConfirm: _confirmDisable,
      ),
    ];
  }
}
