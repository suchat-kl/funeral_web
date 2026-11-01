// ส่วนประกอบร่วมของหน้าต่างที่ผู้ใช้จัดการบัญชีตัวเอง
// (ลงทะเบียน / ลืมรหัสผ่าน / ข้อมูลส่วนตัว) หน้าตาเดียวกับหน้าเปลี่ยนรหัสผ่าน
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/theme.dart';

/// ฟอนต์ของหน้าต่างชุดนี้ ระบุชัดทุกจุดตามข้อกำหนดฟอนต์ไทยของโปรเจกต์
const String kAccountFont = 'NotoSansThai';

/// ผลตรวจรหัสผ่านตามเงื่อนไขของระบบ (ชุดเดียวกับหน้าเปลี่ยนรหัสผ่านและหน้าสร้างผู้ใช้งาน)
class PasswordRules {
  final bool hasMinLength;
  final bool hasUppercase;
  final bool hasLowercase;
  final bool hasDigit;
  final bool hasSpecialChar;

  /// อักขระพิเศษ = อะไรก็ได้ที่ไม่ใช่ A-Z a-z 0-9 — ตรงกับ backend (PasswordPolicy.validateStrength)
  static final RegExp specialChar = RegExp(r'[^A-Za-z0-9]');

  /// ยาวสุด (BCrypt ใช้แค่ 72 ไบต์แรก backend ปฏิเสธที่ยาวกว่า)
  static const int maxLength = 72;

  const PasswordRules._({
    required this.hasMinLength,
    required this.hasUppercase,
    required this.hasLowercase,
    required this.hasDigit,
    required this.hasSpecialChar,
  });

  factory PasswordRules.of(String password) => PasswordRules._(
    hasMinLength: password.length >= 8 && password.length <= maxLength,
    hasUppercase: password.contains(RegExp(r'[A-Z]')),
    hasLowercase: password.contains(RegExp(r'[a-z]')),
    hasDigit: password.contains(RegExp(r'[0-9]')),
    hasSpecialChar: password.contains(specialChar),
  );

  /// จำนวนเงื่อนไขที่ผ่าน (0-5)
  int get score =>
      (hasMinLength ? 1 : 0) +
      (hasUppercase ? 1 : 0) +
      (hasLowercase ? 1 : 0) +
      (hasDigit ? 1 : 0) +
      (hasSpecialChar ? 1 : 0);

  bool get allPassed => score == 5;

  /// ข้อความเมื่อรหัสผ่านยังไม่ครบเงื่อนไข
  static const String notMetMessage =
      'กรุณาตั้งรหัสผ่านให้ตรงตามเงื่อนไขที่กำหนด';
}

/// ป้ายระดับความแข็งแรงของรหัสผ่าน อ่อน / ปานกลาง / ดี / ดีมาก
class PasswordStrengthChip extends StatelessWidget {
  final PasswordRules rules;

  const PasswordStrengthChip({super.key, required this.rules});

  @override
  Widget build(BuildContext context) {
    final (Color color, String text) = switch (rules.score) {
      <= 2 => (Colors.red, 'อ่อน'),
      3 => (Colors.orange, 'ปานกลาง'),
      4 => (Colors.blue, 'ดี'),
      _ => (Colors.green, 'ดีมาก'),
    };
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontFamily: kAccountFont,
            fontSize: 11,
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

/// กล่องเงื่อนไขการตั้งรหัสผ่าน ติ๊กเขียวทีละข้อเมื่อผ่าน
class PasswordRequirementsBox extends StatelessWidget {
  final PasswordRules rules;
  final bool isDesktop;

  const PasswordRequirementsBox({
    super.key,
    required this.rules,
    this.isDesktop = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(isDesktop ? 16 : 12),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'เงื่อนไขการตั้งรหัสผ่าน',
            style: TextStyle(
              fontFamily: kAccountFont,
              fontSize: isDesktop ? 14 : 13,
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryColor,
            ),
          ),
          const SizedBox(height: 8),
          _item('ยาว 8 ถึง 72 ตัวอักษร', rules.hasMinLength),
          _item('มีตัวอักษรพิมพ์ใหญ่อย่างน้อย 1 ตัว (A-Z)', rules.hasUppercase),
          _item('มีตัวอักษรพิมพ์เล็กอย่างน้อย 1 ตัว (a-z)', rules.hasLowercase),
          _item('มีตัวเลขอย่างน้อย 1 ตัว (0-9)', rules.hasDigit),
          _item(
            'มีอักขระพิเศษอย่างน้อย 1 ตัว (เช่น !@#\$%^&*)',
            rules.hasSpecialChar,
          ),
        ],
      ),
    );
  }

  Widget _item(String text, bool ok) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(
            ok ? Icons.check_circle : Icons.radio_button_unchecked,
            size: isDesktop ? 18 : 16,
            color: ok ? Colors.green : Colors.grey.shade400,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontFamily: kAccountFont,
                fontSize: isDesktop ? 13 : 12,
                color: ok ? Colors.green.shade700 : Colors.grey.shade600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// โครงหน้าต่าง: หัวไล่สี (ไอคอน + ชื่อ + คำอธิบาย) กับเนื้อหาที่เลื่อนได้
class AccountDialogShell extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget child;

  /// แสดงปุ่มกากบาทปิดที่มุมหัว (null = ไม่มีปุ่ม)
  final VoidCallback? onClose;

  const AccountDialogShell({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.child,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 768;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.all(isDesktop ? 40 : 16),
      child: Container(
        width: isDesktop ? 600 : screenWidth * 0.95,
        constraints: const BoxConstraints(maxWidth: 650),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryColor.withValues(alpha: 0.2),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        // พื้นขาวของหน้าต่างเป็น Material ให้ ListTile (ช่องติ๊ก/สวิตช์) วาดสีและคลื่นตอนกดได้
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(
                  horizontal: isDesktop ? 24 : 16,
                  vertical: isDesktop ? 16 : 12,
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
                child: Row(
                  children: [
                    Container(
                      width: isDesktop ? 45 : 38,
                      height: isDesktop ? 45 : 38,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        icon,
                        color: AppTheme.primaryColor,
                        size: isDesktop ? 24 : 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              fontFamily: kAccountFont,
                              fontSize: isDesktop ? 18 : 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            subtitle,
                            style: TextStyle(
                              fontFamily: kAccountFont,
                              fontSize: isDesktop ? 12 : 11,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (onClose != null)
                      IconButton(
                        tooltip: 'ปิด',
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: onClose,
                      ),
                  ],
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(isDesktop ? 28 : 20),
                  child: child,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// แถบข้อความในหน้าต่าง แดง = ข้อผิดพลาด, เขียว = สำเร็จ, ฟ้า = คำอธิบาย
class AccountBanner extends StatelessWidget {
  final String message;
  final MaterialColor color;
  final IconData icon;

  /// ปุ่มกากบาทปิดแถบ (null = ไม่มีปุ่ม)
  final VoidCallback? onClose;

  const AccountBanner.error(this.message, {super.key, this.onClose})
    : color = Colors.red,
      icon = Icons.error_outline;

  const AccountBanner.success(this.message, {super.key, this.onClose})
    : color = Colors.green,
      icon = Icons.check_circle_outline;

  const AccountBanner.info(this.message, {super.key, this.onClose})
    : color = Colors.blue,
      icon = Icons.info_outline;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color.shade700, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontFamily: kAccountFont,
                color: color.shade700,
                fontSize: 13,
              ),
            ),
          ),
          if (onClose != null)
            InkWell(
              onTap: onClose,
              child: Icon(Icons.close, color: color.shade700, size: 18),
            ),
        ],
      ),
    );
  }
}

/// ช่องกรอกพร้อมป้ายชื่อด้านบน รูปแบบเดียวกันทุกช่อง
class AccountField extends StatelessWidget {
  final String label;
  final String? hint;
  final IconData icon;
  final TextEditingController controller;
  final bool enabled;

  /// อ่านอย่างเดียว พื้นเทา (ค่ายังเลือกคัดลอกได้)
  final bool readOnly;
  final bool obscureText;
  final Widget? suffix;
  final String? helper;

  /// ข้อความผิดพลาดจาก backend ของช่องนี้ แสดงใต้ช่องแบบเดียวกับผลของ [validator]
  /// (validator ไม่ผ่านจะแสดงข้อความของ validator แทน) ผู้เรียกล้างเองเมื่อผู้ใช้แก้ค่า
  final String? errorText;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onTap;

  /// ใช้เมื่อช่องนี้อยู่ใน autocomplete ซึ่งต้องคุมโฟกัสและปุ่ม Enter เอง
  final FocusNode? focusNode;
  final ValueChanged<String>? onFieldSubmitted;

  const AccountField({
    super.key,
    required this.label,
    this.hint,
    required this.icon,
    required this.controller,
    this.enabled = true,
    this.readOnly = false,
    this.obscureText = false,
    this.suffix,
    this.helper,
    this.errorText,
    this.keyboardType,
    this.inputFormatters,
    this.validator,
    this.onChanged,
    this.onTap,
    this.focusNode,
    this.onFieldSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 768;
    // ช่องที่เปิดตัวเลือก (onTap) อ่านอย่างเดียวแต่ยังใช้งานได้ จึงไม่ทำพื้นเทา
    final greyed = readOnly && onTap == null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontFamily: kAccountFont,
            fontSize: isDesktop ? 14 : 13,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          focusNode: focusNode,
          enabled: enabled,
          readOnly: readOnly,
          obscureText: obscureText,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          onChanged: onChanged,
          onTap: onTap,
          onFieldSubmitted: onFieldSubmitted,
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(fontFamily: kAccountFont),
            errorStyle: const TextStyle(fontFamily: kAccountFont),
            errorText: errorText,
            errorMaxLines: 3,
            prefixIcon: Icon(icon, color: greyed ? Colors.grey : null),
            suffixIcon: suffix,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: greyed ? Colors.grey.shade300 : AppTheme.primaryColor,
                width: greyed ? 1 : 2,
              ),
            ),
            filled: true,
            fillColor: greyed ? Colors.grey.shade100 : AppTheme.fieldFillColor,
          ),
          style: TextStyle(
            fontFamily: kAccountFont,
            fontSize: isDesktop ? 16 : 14,
            color: greyed ? Colors.grey.shade700 : AppTheme.textPrimary,
          ),
        ),
        if (helper != null) ...[
          const SizedBox(height: 6),
          Text(
            helper!,
            style: TextStyle(
              fontFamily: kAccountFont,
              fontSize: isDesktop ? 12 : 11,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ],
    );
  }
}

/// ช่องรหัสผ่านใหม่ + ยืนยัน + กล่องเงื่อนไข ใช้ร่วมกันในหน้าลงทะเบียนและหน้าลืมรหัสผ่าน
///
/// ผู้เรียกตรวจ `PasswordRules.of(password.text).allPassed` ก่อนส่งเอง
/// (ช่องยืนยันตรวจว่าตรงกันผ่าน validator ของ Form)
class NewPasswordFields extends StatefulWidget {
  final TextEditingController password;
  final TextEditingController confirm;
  final bool enabled;
  final String label;

  /// ข้อความผิดพลาดจาก backend ของช่องรหัสผ่าน (เช่นรหัสผ่านไม่ผ่านกติกา) แสดงใต้ช่องแรก
  final String? passwordErrorText;

  /// โฟกัสของช่องรหัสผ่านช่องแรก ให้ผู้เรียกพาผู้ใช้มาที่ช่องนี้ได้
  final FocusNode? passwordFocusNode;

  /// ผู้ใช้แก้ค่าในช่องรหัสผ่านช่องแรก
  final ValueChanged<String>? onPasswordChanged;

  const NewPasswordFields({
    super.key,
    required this.password,
    required this.confirm,
    this.enabled = true,
    this.label = 'รหัสผ่าน',
    this.passwordErrorText,
    this.passwordFocusNode,
    this.onPasswordChanged,
  });

  @override
  State<NewPasswordFields> createState() => _NewPasswordFieldsState();
}

class _NewPasswordFieldsState extends State<NewPasswordFields> {
  bool _obscure = true;
  bool _obscureConfirm = true;

  @override
  void initState() {
    super.initState();
    widget.password.addListener(_changed);
  }

  @override
  void dispose() {
    widget.password.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  Widget _eye(bool obscure, VoidCallback onPressed) => IconButton(
    icon: Icon(
      obscure ? Icons.visibility_off : Icons.visibility,
      color: Colors.grey,
    ),
    onPressed: onPressed,
  );

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 768;
    final rules = PasswordRules.of(widget.password.text);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AccountField(
          label: widget.label,
          hint: 'กรอก${widget.label}',
          icon: Icons.lock,
          controller: widget.password,
          enabled: widget.enabled,
          obscureText: _obscure,
          errorText: widget.passwordErrorText,
          focusNode: widget.passwordFocusNode,
          onChanged: widget.onPasswordChanged,
          suffix: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.password.text.isNotEmpty)
                PasswordStrengthChip(rules: rules),
              _eye(_obscure, () => setState(() => _obscure = !_obscure)),
            ],
          ),
          validator: (v) =>
              (v == null || v.isEmpty) ? 'กรุณากรอก${widget.label}' : null,
        ),
        const SizedBox(height: 14),
        AccountField(
          label: 'ยืนยัน${widget.label}',
          hint: 'กรอก${widget.label}อีกครั้ง',
          icon: Icons.lock,
          controller: widget.confirm,
          enabled: widget.enabled,
          obscureText: _obscureConfirm,
          suffix: _eye(
            _obscureConfirm,
            () => setState(() => _obscureConfirm = !_obscureConfirm),
          ),
          validator: (v) {
            if (v == null || v.isEmpty) return 'กรุณายืนยัน${widget.label}';
            if (v != widget.password.text) return 'รหัสผ่านไม่ตรงกัน';
            return null;
          },
        ),
        const SizedBox(height: 14),
        PasswordRequirementsBox(rules: rules, isDesktop: isDesktop),
      ],
    );
  }
}

/// ช่องรหัส 6 หลักจากแอป Authenticator (2FA)
///
/// รับเฉพาะตัวเลข ไม่เกิน 6 หลัก วางรหัสที่มีช่องว่างหรือขีดคั่น (เช่น "123 456") ได้ — ตัวกรองตัดให้เหลือตัวเลข
/// กด Enter เรียก [onSubmitted] ใช้ร่วมกันทั้งหน้าเข้าสู่ระบบและหน้าตั้งค่า 2FA
class TwoFactorCodeField extends StatelessWidget {
  final TextEditingController controller;
  final bool enabled;
  final bool autofocus;
  final FocusNode? focusNode;
  final VoidCallback? onSubmitted;
  final String label;

  const TwoFactorCodeField({
    super.key,
    required this.controller,
    this.enabled = true,
    this.autofocus = true,
    this.focusNode,
    this.onSubmitted,
    this.label = 'รหัส 6 หลัก',
  });

  /// คีย์ของช่องกรอก ใช้หาในเทสต์
  static const Key fieldKey = ValueKey('two-factor-code');

  /// รหัสครบ 6 หลักและเป็นตัวเลขล้วน
  static bool isComplete(String code) => RegExp(r'^\d{6}$').hasMatch(code);

  static String? validate(String? v) =>
      isComplete(v ?? '') ? null : 'กรุณากรอกรหัส 6 หลักให้ครบ';

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: kAccountFont,
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          key: fieldKey,
          controller: controller,
          focusNode: focusNode,
          enabled: enabled,
          autofocus: autofocus,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.oneTimeCode],
          autocorrect: false,
          enableSuggestions: false,
          textAlign: TextAlign.center,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(6),
          ],
          validator: validate,
          onFieldSubmitted: (_) => onSubmitted?.call(),
          decoration: InputDecoration(
            hintText: '000000',
            hintStyle: TextStyle(
              fontFamily: kAccountFont,
              color: Colors.grey.shade400,
              letterSpacing: 8,
            ),
            errorStyle: const TextStyle(fontFamily: kAccountFont),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppTheme.primaryColor, width: 2),
            ),
            filled: true,
            fillColor: AppTheme.fieldFillColor,
          ),
          style: const TextStyle(
            fontFamily: kAccountFont,
            fontSize: 24,
            fontWeight: FontWeight.w600,
            letterSpacing: 8,
            color: AppTheme.textPrimary,
          ),
        ),
      ],
    );
  }
}

/// ปุ่มคู่ท้ายหน้าต่าง: ยกเลิก (ซ้าย) กับปุ่มหลัก (ขวา หมุนรอระหว่างทำงาน)
class AccountActionButtons extends StatelessWidget {
  final String cancelText;
  final String confirmText;
  final IconData confirmIcon;
  final bool loading;
  final VoidCallback? onCancel;
  final VoidCallback? onConfirm;

  const AccountActionButtons({
    super.key,
    this.cancelText = 'ยกเลิก',
    required this.confirmText,
    this.confirmIcon = Icons.check,
    this.loading = false,
    required this.onCancel,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 768;
    final height = isDesktop ? 50.0 : 44.0;
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: height,
            child: OutlinedButton(
              onPressed: loading ? null : onCancel,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.cancelColor,
                side: const BorderSide(color: AppTheme.cancelColor),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                cancelText,
                style: TextStyle(
                  fontFamily: kAccountFont,
                  fontSize: isDesktop ? 16 : 14,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: SizedBox(
            height: height,
            child: ElevatedButton(
              onPressed: loading ? null : onConfirm,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
              ),
              child: loading
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
                        Icon(confirmIcon, size: 20),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            confirmText,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: kAccountFont,
                              fontSize: isDesktop ? 16 : 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ],
    );
  }
}
