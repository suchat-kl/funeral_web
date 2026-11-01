import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../config/theme.dart';
import '../models/two_factor.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../utils/passkey.dart';
import '../utils/thaid.dart';
import 'account_form.dart';
import 'forgot_password_dialog.dart';
import 'passkey_unavailable_dialog.dart';
import 'register_dialog.dart';

/// หน้าต่างเข้าสู่ระบบ: ชื่อผู้ใช้/รหัสผ่าน (+ ขั้นรหัส 6 หลักของบัญชีที่เปิด 2FA), ThaID, ลายนิ้วมือ/Windows Hello,
/// ลิงก์ลงทะเบียน และลืมรหัสผ่าน (ยืนยันด้วย ThaID)
///
/// คืน true เมื่อเข้าสู่ระบบสำเร็จ

class LoginDialog extends StatefulWidget {
  final AuthProvider authProvider;

  /// ชื่อผู้ใช้ที่เติมไว้ให้ตอนเปิด (เช่นหลังลงทะเบียน หรือหลังเปลี่ยนชื่อผู้ใช้)
  final String? initialUsername;

  /// ข้อความแจ้งสีเขียวเหนือช่องกรอกตอนเปิด
  final String? initialMessage;

  const LoginDialog({
    super.key,
    required this.authProvider,
    this.initialUsername,
    this.initialMessage,
  });

  /// คีย์ของแถบหัวสีของหน้าต่าง ใช้วัดความสูงในเทสต์
  static const Key headerKey = ValueKey('login-dialog-header');

  /// ป้ายของลิงก์ลืมรหัสผ่านใต้ช่องกรอก เปิด flow กำหนดรหัสผ่านใหม่ด้วย ThaID (ไม่ต้องเข้าสู่ระบบ)
  static const String forgotPasswordLabel = 'ลืมรหัสผ่าน?';

  /// ป้ายปุ่มเข้าสู่ระบบด้วย ThaID
  static const String thaidButtonLabel = 'เข้าสู่ระบบด้วย ThaID';

  /// ข้อความเมื่อยืนยัน ThaID แล้วแต่ยังไม่ได้ลงทะเบียน
  static const String notRegisteredHint =
      'เลขบัตรนี้ยังไม่ได้ลงทะเบียนในระบบ กดปุ่ม "ลงทะเบียน" เพื่อลงทะเบียนก่อน';

  /// ข้อความแจ้งผลเมื่อกลับมาจากหน้าลงทะเบียนสำเร็จ
  static const String registeredMessage =
      'ลงทะเบียนสำเร็จ กรุณากรอกรหัสผ่านเพื่อเข้าสู่ระบบ';

  /// ป้ายปุ่มเข้าสู่ระบบด้วย passkey (แสดงเมื่อเบราว์เซอร์รองรับ)
  static const String passkeyButtonLabel = 'ลายนิ้วมือ / Windows Hello';

  /// คำแนะนำในขั้นที่สอง (รหัส 6 หลัก) เมื่อมือถือหายหรือใช้แอป Authenticator ไม่ได้
  /// เข้าด้วย ThaID ไม่ถามรหัส 6 หลัก และปิด 2FA ได้โดยไม่ต้องใช้รหัส
  static const String twoFactorLostHelp =
      'มือถือหายหรือใช้แอป Authenticator ไม่ได้: เข้าสู่ระบบด้วย ThaID ได้โดยไม่ต้องใช้รหัส 6 หลัก '
      'หรือติดต่อผู้ดูแลระบบให้ปิดการยืนยันตัวตนสองขั้น';

  @override
  State<LoginDialog> createState() => _LoginDialogState();
}

class _LoginDialogState extends State<LoginDialog> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _apiService = ApiService();

  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  /// ข้อความแจ้งผลสำเร็จ (เช่นลงทะเบียนแล้ว) ให้เข้าสู่ระบบต่อ
  late String? _infoMessage = widget.initialMessage;

  /// ไม่ใช่ null = อยู่ขั้นที่สอง (รอรหัส 6 หลักของบัญชีที่เปิด 2FA) ยังไม่ได้เข้าสู่ระบบ
  /// อยู่ใน state ของหน้าต่างนี้เท่านั้น ไม่เก็บลงที่เก็บของเบราว์เซอร์ และไม่ log
  TwoFactorChallenge? _challenge;
  final _codeController = TextEditingController();
  final _codeFocus = FocusNode();

  /// ตัวเรียก WebAuthn ของเบราว์เซอร์ (เทสต์ใส่ตัวปลอมผ่าน passkeyAuthenticatorOverride)
  final PasskeyAuthenticator _passkey = createPasskeyAuthenticator();
  late final bool _passkeySupported = _passkey.isSupported();

  @override
  void initState() {
    super.initState();
    _usernameController.text = widget.initialUsername ?? '';
  }

  /// เข้าสู่ระบบด้วย passkey: ไม่ต้องกรอกชื่อผู้ใช้ เบราว์เซอร์แสดงบัญชีที่เคยลงทะเบียนไว้ให้เลือกแล้วสแกน
  /// ไม่ถาม 2FA (passkey + สแกนนิ้ว/PIN นับเป็นสองปัจจัยแล้ว) กดยกเลิกที่หน้าสแกน = ไม่แจ้งอะไร
  Future<void> _handlePasskey() async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _infoMessage = null;
    });
    // เครื่องไม่มีตัวสแกนในเครื่อง = หน้าต่างแจ้งกลางจอ (ค้างไว้จนผู้ใช้กดปิด) แล้วกลับมาหน้านี้ตามเดิม
    // เว้นแต่ผู้ใช้กดปุ่มรองใช้มือถือ / กุญแจ USB แทน = สแกนต่อ
    if (!await ensurePasskeyAvailable(context, _passkey)) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    try {
      // ชื่อผู้ใช้ที่พิมพ์ไว้ (ถ้ามี) ให้ backend เสนอเฉพาะ passkey ของบัญชีนั้น
      final ok = await widget.authProvider.loginWithPasskey(
        _passkey,
        username: _usernameController.text.trim(),
      );
      if (!mounted) return;
      if (ok) {
        _finishLogin();
        return;
      }
      setState(() => _isLoading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  /// กลับจากหน้าลงทะเบียนหรือกำหนดรหัสผ่านใหม่สำเร็จ: เติมชื่อผู้ใช้ให้ ล้างรหัสผ่าน แล้วแจ้งผล
  void _prefill(String username, String message) {
    if (!mounted) return;
    _usernameController.text = username;
    _passwordController.clear();
    setState(() {
      _errorMessage = null;
      _infoMessage = message;
    });
  }

  /// เข้าสู่ระบบด้วย ThaID จากหน้าต่างนี้ — ยังไม่ลงทะเบียน (NOT_REGISTERED) แนะนำให้ลงทะเบียน
  Future<void> _handleThaid() async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _infoMessage = null;
    });
    try {
      final ok = await widget.authProvider.loginWithThaid();
      if (!mounted) return;
      if (ok) {
        _finishLogin();
        return;
      }
      setState(() {
        _isLoading = false;
        _errorMessage = thaidCancelledMessage;
      });
    } catch (e) {
      if (!mounted) return;
      final notRegistered =
          e is ApiException && e.code == ErrorCodes.notRegistered;
      setState(() {
        _isLoading = false;
        _errorMessage = notRegistered
            ? '$e\n${LoginDialog.notRegisteredHint}'
            : e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  /// เปิดหน้าลงทะเบียนซ้อนบนหน้าต่างนี้ — สำเร็จแล้วเติมชื่อผู้ใช้ให้
  /// เลขบัตรเคยลงทะเบียนแล้วและผู้ใช้เลือก "ลืมรหัสผ่าน" = เปิดหน้าลืมรหัสผ่านต่อ
  Future<void> _openRegister() async {
    final result = await showDialog<RegisterResult>(
      context: context,
      barrierDismissible: false,
      builder: (_) => RegisterDialog(apiService: _apiService),
    );
    if (result == null || !mounted) return;
    if (result.goForgotPassword) {
      await _openResetPassword();
      return;
    }
    final username = result.username;
    if (username != null) _prefill(username, LoginDialog.registeredMessage);
  }

  /// ลืมรหัสผ่าน: ยืนยันด้วย ThaID แล้วตั้งรหัสใหม่ สำเร็จแล้วเติมชื่อผู้ใช้ให้
  /// ยังไม่ลงทะเบียนแล้วผู้ใช้เลือกลงทะเบียน = เปิดหน้าลงทะเบียนต่อ
  Future<void> _openResetPassword() async {
    final result = await showDialog<ForgotPasswordResult>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ForgotPasswordDialog(apiService: _apiService),
    );
    if (result == null || !mounted) return;
    if (result.goRegister) {
      await _openRegister();
      return;
    }
    _prefill(result.username ?? _usernameController.text, result.message);
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _codeController.dispose();
    _codeFocus.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _infoMessage = null;
    });

    try {
      final challenge = await widget.authProvider.login(
        _usernameController.text.trim(),
        _passwordController.text,
      );
      if (!mounted) return;

      // บัญชีเปิด 2FA: ยังไม่ได้เข้าสู่ระบบ เปลี่ยนเป็นขั้นที่สองในหน้าต่างเดิม
      // รหัสผ่านไม่ต้องใช้อีกแล้ว ล้างทิ้ง (ย้อนกลับหรือ challenge หมดอายุต้องกรอกใหม่)
      if (challenge != null) {
        _passwordController.clear();
        _codeController.clear();
        setState(() {
          _challenge = challenge;
          _isLoading = false;
        });
        return;
      }

      _finishLogin();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  /// ได้ token แล้ว: แจ้งต้อนรับและปิดหน้าต่าง
  void _finishLogin() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'ยินดีต้อนรับ คุณ${widget.authProvider.displayName}',
                style: const TextStyle(
 fontFamily: kAccountFont,color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );

    // Close dialog
    Navigator.of(context).pop(true);
  }

  /// ขั้นที่สอง: ส่งรหัส 6 หลักคู่กับ challenge
  /// - รหัสผิด (401): แสดงข้อความ ล้างช่อง ให้ลองใหม่ด้วย challenge เดิม
  /// - challenge หมดอายุ/ใช้แล้ว/ผิดเกินกำหนด (400): แจ้งแล้วกลับไปขั้นแรก
  Future<void> _handleTwoFactor() async {
    final challenge = _challenge;
    if (challenge == null || _isLoading) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await widget.authProvider.loginTwoFactor(challenge, _codeController.text);
      if (!mounted) return;
      _finishLogin();
    } catch (e) {
      if (!mounted) return;
      final message = e.toString().replaceAll('Exception: ', '');
      if (e is ApiException && e.statusCode == 400) {
        _backToLogin(error: message);
        return;
      }
      _codeController.clear();
      setState(() {
        _errorMessage = message;
        _isLoading = false;
      });
      _codeFocus.requestFocus();
    }
  }

  /// กลับไปขั้นแรก (ชื่อผู้ใช้/รหัสผ่าน) ทิ้ง challenge และรหัสที่กรอกค้างไว้
  void _backToLogin({String? error}) {
    _codeController.clear();
    _passwordController.clear();
    setState(() {
      _challenge = null;
      _isLoading = false;
      _errorMessage = error;
    });
  }

  /// ปุ่มยกเลิก (ปิดหน้าต่าง)
  Widget _cancelButton(bool isDesktop) {
    return SizedBox(
      height: isDesktop ? 50 : 44,
      child: OutlinedButton(
        onPressed: _isLoading ? null : () => Navigator.of(context).pop(false),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppTheme.cancelColor,
          side: const BorderSide(color: AppTheme.cancelColor),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text('ยกเลิก', style: TextStyle(
 fontFamily: kAccountFont,fontSize: isDesktop ? 16 : 14)),
      ),
    );
  }

  /// ลิงก์ใต้ช่องกรอก (ลงทะเบียน / ลืมรหัสผ่าน) ระยะขอบแคบให้สองลิงก์อยู่แถวเดียวกันได้
  static final ButtonStyle _linkStyle = TextButton.styleFrom(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
    minimumSize: Size.zero,
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
  );

  /// เนื้อหาของขั้นที่สอง: คำอธิบาย ช่องรหัส 6 หลัก ปุ่มยืนยัน ปุ่มย้อนกลับ และคำแนะนำเมื่อใช้แอปไม่ได้
  List<Widget> _buildTwoFactorStep(bool isDesktop) {
    final minutes = _challenge?.expiresInMinutes;
    return [
      Text(
        'บัญชี "${_usernameController.text.trim()}" เปิดการยืนยันตัวตนสองขั้นไว้\n'
        'เปิดแอป Authenticator ในมือถือ แล้วกรอกรหัส 6 หลักของระบบนี้'
        '${minutes == null ? '' : ' (ภายใน $minutes นาที)'}',
        style: const TextStyle(
          fontFamily: kAccountFont,
          fontSize: 14,
          height: 1.5,
          color: AppTheme.textPrimary,
        ),
      ),
      const SizedBox(height: 16),
      TwoFactorCodeField(
        controller: _codeController,
        focusNode: _codeFocus,
        enabled: !_isLoading,
        onSubmitted: _handleTwoFactor,
      ),
      const SizedBox(height: 16),
      const AccountBanner.info(LoginDialog.twoFactorLostHelp),
      const SizedBox(height: 16),
      SizedBox(
        height: isDesktop ? 50 : 44,
        child: ElevatedButton(
          onPressed: _isLoading ? null : _handleTwoFactor,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryColor,
            foregroundColor: Colors.white,
            disabledBackgroundColor: Colors.grey,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 2,
          ),
          child: _isLoading
              ? SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.verified_user, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'ยืนยัน',
                      style: TextStyle(
                        fontFamily: kAccountFont,
                        fontSize: isDesktop ? 16 : 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
        ),
      ),
      const SizedBox(height: 12),
      SizedBox(
        height: isDesktop ? 50 : 44,
        child: OutlinedButton.icon(
          onPressed: _isLoading ? null : () => _backToLogin(),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppTheme.cancelColor,
            side: const BorderSide(color: AppTheme.cancelColor),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          icon: const Icon(Icons.arrow_back, size: 18),
          label: Text(
            'ย้อนกลับ',
            style: TextStyle(
              fontFamily: kAccountFont,
              fontSize: isDesktop ? 16 : 14,
            ),
          ),
        ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 600;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 40 : 20,
        vertical: isDesktop ? 24 : 16,
      ),
      child: Container(
        width: isDesktop ? 480 : screenWidth * 0.9,
        constraints: const BoxConstraints(maxWidth: 500),
        // ตัดเนื้อหาตามมุมโค้งของหน้าต่าง กันส่วนที่เลื่อนโผล่ทับแถบหัว
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryColor.withValues(alpha: 0.3),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header with gradient
            Container(
              key: LoginDialog.headerKey,
              width: double.infinity,
              padding: EdgeInsets.symmetric(
                horizontal: isDesktop ? 28 : 20,
                vertical: isDesktop ? 26 : 18,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppTheme.primaryColor,
                    AppTheme.primaryColor.withValues(alpha: 0.8),
                  ],
                ),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
              ),
              // แถบหัวแบบเตี้ย: ไอคอนกับชื่อเรื่องอยู่แถวเดียวกัน (ใช้ทั้งขั้นแรกและขั้นรหัส 6 หลัก)
              // เดิมไอคอนใหญ่ซ้อนเหนือชื่อเรื่อง กินความสูงจนต้องเลื่อนหาปุ่มเข้าสู่ระบบบนจอโน้ตบุ๊ก
              child: Row(
                children: [
                  Container(
                    width: isDesktop ? 52 : 44,
                    height: isDesktop ? 52 : 44,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _challenge != null
                          ? Icons.phonelink_lock
                          : Icons.account_balance,
                      color: AppTheme.primaryColor,
                      size: isDesktop ? 28 : 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _challenge != null
                              ? 'ยืนยันตัวตนสองขั้น'
                              : 'เข้าสู่ระบบ',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
 fontFamily: kAccountFont,
                            fontSize: isDesktop ? 20 : 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          AppConfig.systemName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
 fontFamily: kAccountFont,
                            fontSize: isDesktop ? 13 : 12,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Login Form — จอเตี้ยเลื่อนเฉพาะส่วนนี้ แถบหัวอยู่เหนือพื้นที่เลื่อน ไม่ทับเนื้อหา
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: isDesktop ? 32 : 20,
                  vertical: isDesktop ? 22 : 16,
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Error Message
                      if (_errorMessage != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.red.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.error_outline,
                                color: Colors.red.shade700,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _errorMessage!,
                                  style: TextStyle(
 fontFamily: kAccountFont,
                                    color: Colors.red.shade700,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              InkWell(
                                onTap: () =>
                                    setState(() => _errorMessage = null),
                                child: Icon(
                                  Icons.close,
                                  color: Colors.red.shade700,
                                  size: 18,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      if (_infoMessage != null) ...[
                        AccountBanner.success(
                          _infoMessage!,
                          onClose: () => setState(() => _infoMessage = null),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // ขั้นที่สอง (บัญชีที่เปิด 2FA): รหัส 6 หลักแทนช่องชื่อผู้ใช้/รหัสผ่าน
                      if (_challenge != null)
                        ..._buildTwoFactorStep(isDesktop)
                      else ...[
                        // Username Field
                        TextFormField(
                          controller: _usernameController,
                          enabled: !_isLoading,
                          decoration: InputDecoration(
                            labelText: 'ชื่อผู้ใช้',
                            labelStyle: const TextStyle(fontFamily: kAccountFont),
                            hintText: 'กรอกชื่อผู้ใช้',
                            prefixIcon: const Icon(Icons.person_outline),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: Colors.grey.shade300,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: AppTheme.primaryColor,
                                width: 2,
                              ),
                            ),
                            filled: true,
                            fillColor: AppTheme.fieldFillColor,
                          ),
                          style: const TextStyle(
 fontFamily: kAccountFont,fontSize: 16),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'กรุณากรอกชื่อผู้ใช้';
                            }
                            return null;
                          },
                        ),

                        const SizedBox(height: 12),

                        // Password Field
                        TextFormField(
                          controller: _passwordController,
                          enabled: !_isLoading,
                          obscureText: _obscurePassword,
                          decoration: InputDecoration(
                            labelText: 'รหัสผ่าน',
                            labelStyle: const TextStyle(fontFamily: kAccountFont),
                            hintText: 'กรอกรหัสผ่าน',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: Colors.grey.shade300,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: AppTheme.primaryColor,
                                width: 2,
                              ),
                            ),
                            filled: true,
                            fillColor: AppTheme.fieldFillColor,
                          ),
                          style: const TextStyle(
 fontFamily: kAccountFont,fontSize: 16),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'กรุณากรอกรหัสผ่าน';
                            }
                            return null;
                          },
                        ),

                        // ลงทะเบียนด้วยตัวเอง คู่กับลิงก์ลืมรหัสผ่าน
                        // (กำหนดรหัสผ่านใหม่ด้วยการยืนยันตัวตน ThaID ไม่ต้องเข้าสู่ระบบ)
                        const SizedBox(height: 4),
                        // แถวเดียวกันเสมอ: ลงทะเบียนชิดซ้าย ลืมรหัสผ่านชิดขวา (จอแคบข้อความด้านขวาตัดบรรทัดเอง)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            TextButton.icon(
                              style: _linkStyle,
                              onPressed: _isLoading ? null : _openRegister,
                              icon: const Icon(Icons.how_to_reg, size: 18),
                              label: const Text(
                                'ลงทะเบียน',
                                style: TextStyle(
                                  fontFamily: kAccountFont,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Flexible(
                              child: TextButton.icon(
                                style: _linkStyle,
                                onPressed: _isLoading
                                    ? null
                                    : _openResetPassword,
                                icon: const Icon(Icons.password, size: 18),
                                label: const Text(
                                  LoginDialog.forgotPasswordLabel,
                                  textAlign: TextAlign.end,
                                  style: TextStyle(
                                    fontFamily: kAccountFont,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 12),

                        // Login Button
                        SizedBox(
                          height: isDesktop ? 50 : 44,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _handleLogin,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryColor,
                              disabledBackgroundColor: Colors.grey,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 2,
                            ),
                            child: _isLoading
                                ? SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white.withValues(alpha: 0.8),
                                      ),
                                    ),
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.login, size: 20),
                                      const SizedBox(width: 8),
                                      Text(
                                        'เข้าสู่ระบบ',
                                        style: TextStyle(
 fontFamily: kAccountFont,
                                          fontSize: isDesktop ? 16 : 14,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),

                        const SizedBox(height: 10),

                        // ThaID: ยืนยันตัวตนด้วยแอป ThaID ไม่ต้องกรอกรหัสผ่าน (ไม่ถามรหัส 6 หลัก)
                        SizedBox(
                          height: isDesktop ? 50 : 44,
                          child: OutlinedButton.icon(
                            key: const ValueKey('thaid-login'),
                            onPressed: _isLoading ? null : _handleThaid,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF06115A),
                              side: const BorderSide(color: Color(0xFF06115A)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            icon: Image.asset(
                              'assets/images/thaid.png',
                              height: 24,
                              errorBuilder: (_, _, _) =>
                                  const Icon(Icons.badge_outlined),
                            ),
                            label: Text(
                              LoginDialog.thaidButtonLabel,
                              style: TextStyle(
                                fontFamily: kAccountFont,
                                fontSize: isDesktop ? 15 : 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 10),

                        // ปุ่มเข้าด้วย passkey อยู่แถวเดียวกับปุ่มยกเลิก (ความสูงหน้าต่างเท่าเดิม จอ 1366x720 ไม่ต้องเลื่อน)
                        // เบราว์เซอร์ไม่รองรับ = ปุ่มยกเลิกเต็มแถวแบบเดิม
                        if (_passkeySupported)
                          Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: SizedBox(
                                  height: isDesktop ? 50 : 44,
                                  child: OutlinedButton.icon(
                                    key: const ValueKey('passkey-login'),
                                    onPressed: _isLoading
                                        ? null
                                        : _handlePasskey,
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: AppTheme.primaryColor,
                                      side: BorderSide(
                                        color: AppTheme.primaryColor,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    icon: const Icon(Icons.fingerprint),
                                    label: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        LoginDialog.passkeyButtonLabel,
                                        style: TextStyle(
                                          fontFamily: kAccountFont,
                                          fontSize: isDesktop ? 15 : 13,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                flex: 2,
                                child: _cancelButton(isDesktop),
                              ),
                            ],
                          )
                        else
                          _cancelButton(isDesktop),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
