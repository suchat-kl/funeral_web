import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../services/api_service.dart';
import '../utils/snackbar_helper.dart';
import 'account_form.dart';

class ChangePasswordDialog extends StatefulWidget {
  final String username;
  final ApiService apiService;

  /// บังคับเปลี่ยน (ยังใช้รหัสผ่านตั้งต้น): ปิดหน้านี้ไม่ได้
  /// ปุ่มยกเลิกเปลี่ยนเป็นออกจากระบบ คืนค่า false ให้ผู้เรียกไปออกจากระบบ
  final bool forced;

  const ChangePasswordDialog({
    super.key,
    required this.username,
    required this.apiService,
    this.forced = false,
  });

  @override
  State<ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<ChangePasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _oldPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _obscureOldPassword = true;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  String? _errorMessage;

  // Password validation states
  bool _hasMinLength = false;
  bool _hasUppercase = false;
  bool _hasLowercase = false;
  bool _hasDigit = false;
  bool _hasSpecialChar = false;

  @override
  void initState() {
    super.initState();
    _newPasswordController.addListener(_validatePasswordStrength);
  }

  @override
  void dispose() {
    _oldPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _validatePasswordStrength() {
    final password = _newPasswordController.text;
    setState(() {
      _hasMinLength = password.length >= 8;
      _hasUppercase = password.contains(RegExp(r'[A-Z]'));
      _hasLowercase = password.contains(RegExp(r'[a-z]'));
      _hasDigit = password.contains(RegExp(r'[0-9]'));
      _hasSpecialChar = password.contains(PasswordRules.specialChar);
    });
  }

  Future<void> _handleChangePassword() async {
    if (!_formKey.currentState!.validate()) return;

    // Validate all password requirements
    if (!_hasMinLength ||
        !_hasUppercase ||
        !_hasLowercase ||
        !_hasDigit ||
        !_hasSpecialChar) {
      setState(() {
        _errorMessage = 'กรุณาตั้งรหัสผ่านให้ตรงตามเงื่อนไขที่กำหนด';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await widget.apiService.changePassword(
        _oldPasswordController.text,
        _newPasswordController.text,
      );

      if (mounted) {
        Navigator.of(context).pop(true);
        // context.showSuccessSnackBar('เปลี่ยนรหัสผ่านสำเร็จ');
        context.showSuccessSnackBar(
          'เปลี่ยนรหัสผ่านสำเร็จ 🎉\nกรุณาใช้รหัสผ่านใหม่ในการเข้าสู่ระบบครั้งต่อไป',
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 768;

    return PopScope(
      // บังคับเปลี่ยน: กด Esc หรือย้อนกลับแล้วไม่ปิด
      canPop: !widget.forced,
      child: Dialog(
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              _buildHeader(isDesktop),
              // Form Content
              Flexible(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(isDesktop ? 32 : 20),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Error Message
                        if (_errorMessage != null) ...[
                          _buildErrorBanner(),
                          const SizedBox(height: 16),
                        ],

                        // Username Field (Read-only)
                        _buildUsernameField(isDesktop),
                        const SizedBox(height: 16),

                        // Old Password Field
                        _buildOldPasswordField(isDesktop),
                        const SizedBox(height: 16),

                        // New Password Field
                        _buildNewPasswordField(isDesktop),
                        const SizedBox(height: 16),

                        // Confirm Password Field
                        _buildConfirmPasswordField(isDesktop),
                        const SizedBox(height: 20),

                        // Password Requirements
                        _buildPasswordRequirements(isDesktop),
                        const SizedBox(height: 24),

                        // Buttons
                        _buildActionButtons(isDesktop),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDesktop) {
    return Container(
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
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Row(
        children: [
          // Icon
          Container(
            width: isDesktop ? 45 : 38,
            height: isDesktop ? 45 : 38,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.lock_reset,
              color: AppTheme.primaryColor,
              size: isDesktop ? 24 : 20,
            ),
          ),
          const SizedBox(width: 12),
          // Title
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'เปลี่ยนรหัสผ่าน',
                  style: TextStyle(
 fontFamily: kAccountFont,
                    fontSize: isDesktop ? 18 : 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  widget.forced
                      ? 'ผู้ดูแลระบบตั้งรหัสผ่านให้ กรุณาเปลี่ยนรหัสผ่านก่อนใช้งาน'
                      : 'กรุณากรอกรหัสผ่านให้ตรงตามเงื่อนไข',
                  style: TextStyle(
 fontFamily: kAccountFont,
                    fontSize: isDesktop ? 12 : 11,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red.shade700, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _errorMessage!,
              style: TextStyle(
 fontFamily: kAccountFont,color: Colors.red.shade700, fontSize: 13),
            ),
          ),
          InkWell(
            onTap: () => setState(() => _errorMessage = null),
            child: Icon(Icons.close, color: Colors.red.shade700, size: 18),
          ),
        ],
      ),
    );
  }

  Widget _buildUsernameField(bool isDesktop) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ชื่อผู้ใช้',
          style: TextStyle(
 fontFamily: kAccountFont,
            fontSize: isDesktop ? 14 : 13,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          initialValue: widget.username,
          readOnly: true,
          enabled: false,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.person, color: Colors.grey),
            filled: true,
            fillColor: Colors.grey.shade100,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
          ),
          style: TextStyle(
 fontFamily: kAccountFont,
            fontSize: isDesktop ? 16 : 14,
            color: Colors.grey.shade700,
          ),
        ),
      ],
    );
  }

  Widget _buildOldPasswordField(bool isDesktop) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'รหัสผ่านเดิม',
          style: TextStyle(
 fontFamily: kAccountFont,
            fontSize: isDesktop ? 14 : 13,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _oldPasswordController,
          enabled: !_isLoading,
          obscureText: _obscureOldPassword,
          decoration: InputDecoration(
            hintText: 'กรอกรหัสผ่านเดิม',
            prefixIcon: const Icon(Icons.lock_outline),
            suffixIcon: IconButton(
              icon: Icon(
                _obscureOldPassword ? Icons.visibility_off : Icons.visibility,
                color: Colors.grey,
              ),
              onPressed: () {
                setState(() => _obscureOldPassword = !_obscureOldPassword);
              },
            ),
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
          style: TextStyle(
 fontFamily: kAccountFont,fontSize: isDesktop ? 16 : 14),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'กรุณากรอกรหัสผ่านเดิม';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildNewPasswordField(bool isDesktop) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'รหัสผ่านใหม่',
          style: TextStyle(
 fontFamily: kAccountFont,
            fontSize: isDesktop ? 14 : 13,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _newPasswordController,
          enabled: !_isLoading,
          obscureText: _obscureNewPassword,
          decoration: InputDecoration(
            hintText: 'กรอกรหัสผ่านใหม่',
            prefixIcon: const Icon(Icons.lock),
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Password strength indicator
                if (_newPasswordController.text.isNotEmpty)
                  _buildStrengthIndicator(),
                IconButton(
                  icon: Icon(
                    _obscureNewPassword
                        ? Icons.visibility_off
                        : Icons.visibility,
                    color: Colors.grey,
                  ),
                  onPressed: () {
                    setState(() => _obscureNewPassword = !_obscureNewPassword);
                  },
                ),
              ],
            ),
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
          style: TextStyle(
 fontFamily: kAccountFont,fontSize: isDesktop ? 16 : 14),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'กรุณากรอกรหัสผ่านใหม่';
            }
            if (value == _oldPasswordController.text) {
              return 'รหัสผ่านใหม่ต้องไม่เหมือนรหัสผ่านเดิม';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildConfirmPasswordField(bool isDesktop) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ยืนยันรหัสผ่านใหม่',
          style: TextStyle(
 fontFamily: kAccountFont,
            fontSize: isDesktop ? 14 : 13,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _confirmPasswordController,
          enabled: !_isLoading,
          obscureText: _obscureConfirmPassword,
          decoration: InputDecoration(
            hintText: 'กรุณากรอกรหัสผ่านใหม่อีกครั้ง',
            prefixIcon: const Icon(Icons.lock),
            suffixIcon: IconButton(
              icon: Icon(
                _obscureConfirmPassword
                    ? Icons.visibility_off
                    : Icons.visibility,
                color: Colors.grey,
              ),
              onPressed: () {
                setState(
                  () => _obscureConfirmPassword = !_obscureConfirmPassword,
                );
              },
            ),
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
          style: TextStyle(
 fontFamily: kAccountFont,fontSize: isDesktop ? 16 : 14),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'กรุณายืนยันรหัสผ่านใหม่';
            }
            if (value != _newPasswordController.text) {
              return 'รหัสผ่านไม่ตรงกัน';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildStrengthIndicator() {
    int strength = 0;
    if (_hasMinLength) strength++;
    if (_hasUppercase) strength++;
    if (_hasLowercase) strength++;
    if (_hasDigit) strength++;
    if (_hasSpecialChar) strength++;

    Color color;
    String text;
    if (strength <= 2) {
      color = Colors.red;
      text = 'อ่อน';
    } else if (strength <= 3) {
      color = Colors.orange;
      text = 'ปานกลาง';
    } else if (strength <= 4) {
      color = Colors.blue;
      text = 'ดี';
    } else {
      color = Colors.green;
      text = 'ดีมาก';
    }

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

  Widget _buildPasswordRequirements(bool isDesktop) {
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
          const SizedBox(height: 12),
          _buildRequirementItem(
            'อย่างน้อย 8 ตัวอักษร',
            _hasMinLength,
            isDesktop,
          ),
          _buildRequirementItem(
            'มีตัวอักษรพิมพ์ใหญ่อย่างน้อย 1 ตัว (A-Z)',
            _hasUppercase,
            isDesktop,
          ),
          _buildRequirementItem(
            'มีตัวอักษรพิมพ์เล็กอย่างน้อย 1 ตัว (a-z)',
            _hasLowercase,
            isDesktop,
          ),
          _buildRequirementItem(
            'มีตัวเลขอย่างน้อย 1 ตัว (0-9)',
            _hasDigit,
            isDesktop,
          ),
          _buildRequirementItem(
            'มีอักขระพิเศษอย่างน้อย 1 ตัว (!@#\$%^&*)',
            _hasSpecialChar,
            isDesktop,
          ),
        ],
      ),
    );
  }

  Widget _buildRequirementItem(String text, bool isValid, bool isDesktop) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(
            isValid ? Icons.check_circle : Icons.radio_button_unchecked,
            size: isDesktop ? 18 : 16,
            color: isValid ? Colors.green : Colors.grey.shade400,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
 fontFamily: kAccountFont,
                fontSize: isDesktop ? 13 : 12,
                color: isValid ? Colors.green.shade700 : Colors.grey.shade600,
                decoration: isValid ? TextDecoration.none : TextDecoration.none,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(bool isDesktop) {
    return Row(
      children: [
        // Cancel Button
        Expanded(
          child: SizedBox(
            height: isDesktop ? 50 : 44,
            child: OutlinedButton(
              onPressed: _isLoading
                  ? null
                  : () => Navigator.of(context).pop(false),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.cancelColor,
                side: const BorderSide(color: AppTheme.cancelColor),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                widget.forced ? 'ออกจากระบบ' : 'ยกเลิก',
                style: TextStyle(
 fontFamily: kAccountFont,fontSize: isDesktop ? 16 : 14),
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        // Confirm Button
        Expanded(
          child: SizedBox(
            height: isDesktop ? 50 : 44,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _handleChangePassword,
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
                        const Icon(Icons.check, size: 20),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'เปลี่ยนรหัสผ่าน',
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
