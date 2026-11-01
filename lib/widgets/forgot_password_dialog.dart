import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../services/api_service.dart';
import '../utils/thaid.dart';
import 'account_form.dart';

/// ผลของหน้าต่างลืมรหัสผ่าน: ตั้งรหัสใหม่สำเร็จ หรือผู้ใช้เลือกไปลงทะเบียน (ยังไม่มีบัญชี)
class ForgotPasswordResult {
  /// ชื่อผู้ใช้ที่อ่านได้จากข้อความของ backend (อ่านไม่ได้ = null)
  final String? username;
  final String message;
  final bool goRegister;

  const ForgotPasswordResult.done(this.username, this.message)
    : goRegister = false;

  const ForgotPasswordResult.register()
    : username = null,
      message = '',
      goRegister = true;

  /// ข้อความของ backend "ตั้งรหัสผ่านใหม่สำเร็จ ชื่อผู้ใช้ของท่านคือ xxx" → xxx
  static String? usernameFrom(String message) =>
      RegExp(r'ชื่อผู้ใช้ของท่านคือ\s+(\S+)').firstMatch(message)?.group(1);
}

/// ลืมรหัสผ่าน (ไม่ต้องเข้าสู่ระบบ): ตั้งรหัสผ่านใหม่ → ยืนยันตัวตนด้วย ThaID → backend ตั้งรหัสให้บัญชีของเลขบัตรนั้น
///
/// ให้กรอกรหัสผ่านใหม่ **ก่อน** สแกน ThaID เพราะผล ThaID ของ state หนึ่งใช้ได้ครั้งเดียว
/// (backend ใช้ผลทิ้งก่อนตรวจรหัสผ่าน ถ้ารหัสไม่ผ่านกติกาต้องสแกนใหม่) หน้านี้จึงตรวจกติกาครบก่อนเสมอ
/// ไม่มี ThaID = ติดต่อผู้ดูแลระบบ (ไม่มีการรีเซ็ตด้วยวันเกิด)
class ForgotPasswordDialog extends StatefulWidget {
  final ApiService apiService;
  final ThaidAuthorizer? thaidAuthorizer;

  const ForgotPasswordDialog({
    super.key,
    required this.apiService,
    this.thaidAuthorizer,
  });

  static const Key submitKey = ValueKey('forgot-submit');
  static const Key goRegisterKey = ValueKey('forgot-go-register');

  static const String explanation =
      'ตั้งรหัสผ่านใหม่ แล้วกด "ยืนยันตัวตนด้วย ThaID" ระบบจะตั้งรหัสผ่านใหม่ให้บัญชีของเลขบัตรที่ยืนยัน '
      'และแจ้งชื่อผู้ใช้ของท่าน\nไม่มีแอป ThaID: ติดต่อผู้ดูแลระบบให้ตั้งรหัสผ่านใหม่';

  @override
  State<ForgotPasswordDialog> createState() => _ForgotPasswordDialogState();
}

class _ForgotPasswordDialogState extends State<ForgotPasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  String? _error;
  String? _info;
  bool _notRegistered = false;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !_formKey.currentState!.validate()) return;
    if (!PasswordRules.of(_password.text).allPassed) {
      setState(() => _error = PasswordRules.notMetMessage);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _info = null;
      _notRegistered = false;
    });
    try {
      final authorize = widget.thaidAuthorizer ?? currentThaidAuthorizer;
      final state = await authorize(
        widget.apiService,
        purpose: ApiService.thaidPurposeReset,
      );
      if (!mounted) return;
      if (state == null) {
        setState(() {
          _busy = false;
          _info = thaidCancelledMessage;
        });
        return;
      }
      final message = await widget.apiService.thaidReset(state, _password.text);
      if (!mounted) return;
      Navigator.of(context).pop(
        ForgotPasswordResult.done(
          ForgotPasswordResult.usernameFrom(message),
          message,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.toString();
        _notRegistered =
            e is ApiException && e.code == ErrorCodes.notRegistered;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AccountDialogShell(
      icon: Icons.password,
      title: 'ลืมรหัสผ่าน',
      subtitle: 'ตั้งรหัสผ่านใหม่โดยยืนยันตัวตนด้วย ThaID',
      onClose: _busy ? null : () => Navigator.of(context).pop(),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_error != null) ...[
              AccountBanner.error(_error!),
              const SizedBox(height: 10),
            ],
            if (_notRegistered) ...[
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  key: ForgotPasswordDialog.goRegisterKey,
                  onPressed: () => Navigator.of(
                    context,
                  ).pop(const ForgotPasswordResult.register()),
                  icon: const Icon(Icons.how_to_reg, size: 18),
                  label: const Text(
                    'ไปลงทะเบียน',
                    style: TextStyle(fontFamily: kAccountFont, fontSize: 14),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (_info != null) ...[
              AccountBanner.info(_info!),
              const SizedBox(height: 12),
            ],
            const AccountBanner.info(ForgotPasswordDialog.explanation),
            const SizedBox(height: 16),
            NewPasswordFields(
              password: _password,
              confirm: _confirm,
              enabled: !_busy,
              label: 'รหัสผ่านใหม่',
            ),
            const SizedBox(height: 18),
            AccountActionButtons(
              key: ForgotPasswordDialog.submitKey,
              confirmText: _busy ? 'กำลังรอผลจาก ThaID...' : 'ยืนยันตัวตนด้วย ThaID',
              confirmIcon: Icons.qr_code_scanner,
              loading: _busy,
              onCancel: () => Navigator.of(context).pop(),
              onConfirm: _submit,
            ),
            const SizedBox(height: 8),
            Text(
              'ระบบจะยกเลิกการเข้าสู่ระบบที่ค้างอยู่ทุกเครื่องของบัญชีนี้หลังตั้งรหัสใหม่',
              style: TextStyle(
                fontFamily: kAccountFont,
                fontSize: 12,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
