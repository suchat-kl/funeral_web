import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../models/user_admin.dart';
import '../services/api_service.dart';
import '../utils/dialog.dart';
import '../utils/roles.dart';
import '../utils/util.dart';
import 'account_form.dart';
import 'screen_parts.dart';

/// หน้าต่างแก้ไขผู้ใช้ของผู้ดูแล: ประเภทบุคลากร, บทบาทที่ผู้ดูแลกำหนด (เช่น ADMIN), เปิด/ปิดบัญชี, ปลดล็อก
/// และงานเสริม: ตั้งรหัสผ่านใหม่ / ปิด 2FA / ลบ passkey ทั้งหมด
///
/// คืน [UserAdmin] ล่าสุดเมื่อมีการเปลี่ยนแปลง (ปิดเฉย ๆ = null) — ชื่อ เลขบัตร เลขสมาชิกแก้ที่นี่ไม่ได้
class UserAdminDialog extends StatefulWidget {
  final ApiService apiService;
  final UserAdmin user;

  /// บทบาทจาก `GET /api/admin/roles` (แสดงเฉพาะที่ assignable เป็นช่องติ๊ก)
  final List<RoleInfo> roles;

  const UserAdminDialog({
    super.key,
    required this.apiService,
    required this.user,
    required this.roles,
  });

  static const Key saveKey = ValueKey('user-save');
  static const Key activeKey = ValueKey('user-active');
  static const Key lockedKey = ValueKey('user-locked');
  static const Key resetPasswordKey = ValueKey('user-reset-password');
  static const Key disable2faKey = ValueKey('user-disable-2fa');
  static const Key deletePasskeysKey = ValueKey('user-delete-passkeys');
  static Key personTypeKey(String? t) => ValueKey('user-person-${t ?? 'none'}');
  static Key roleKey(String r) => ValueKey('user-role-$r');

  @override
  State<UserAdminDialog> createState() => _UserAdminDialogState();
}

class _UserAdminDialogState extends State<UserAdminDialog> {
  late UserAdmin _user = widget.user;
  late String? _personType = widget.user.personType;
  late final Set<String> _assigned = {...widget.user.assignedRoles};
  late bool _active = widget.user.active;
  late bool _locked = widget.user.locked;
  bool _busy = false;
  bool _changed = false;
  String? _error;
  String? _success;

  List<RoleInfo> get _assignable {
    final list = [for (final r in widget.roles) if (r.assignable) r];
    // บทบาทที่ผู้ใช้ถืออยู่แต่ backend ไม่ได้ส่งมาในรายการ ยังต้องแสดงให้เอาออกได้
    for (final r in _assigned) {
      if (!list.any((x) => x.name == r)) {
        list.add(RoleInfo(name: r, assignable: true));
      }
    }
    return list;
  }

  Future<void> _save() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
      _success = null;
    });
    try {
      final saved = await widget.apiService.updateUser(
        _user.id,
        personType: _personType,
        assignedRoles: [
          for (final r in _assignable)
            if (_assigned.contains(r.name)) r.name,
        ],
        active: _active,
        locked: _locked,
      );
      if (!mounted) return;
      Navigator.of(context).pop(saved);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.toString();
      });
    }
  }

  /// งานเสริมที่เรียก backend แล้วแสดงข้อความ (ถามยืนยันก่อน)
  Future<void> _action(
    String confirm,
    Future<String> Function() run, {
    UserAdmin Function(UserAdmin u)? apply,
  }) async {
    final ok = await AppDialog.showConfirm(context, confirm);
    if (ok != true || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
      _success = null;
    });
    try {
      final message = await run();
      if (!mounted) return;
      setState(() {
        _busy = false;
        _changed = true;
        _success = message;
        if (apply != null) _user = apply(_user);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _resetPassword() async {
    final password = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _NewPasswordDialog(username: _user.username),
    );
    if (password == null || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
      _success = null;
    });
    try {
      final message = await widget.apiService.adminResetPassword(
        _user.id,
        password,
      );
      if (!mounted) return;
      setState(() {
        _busy = false;
        _changed = true;
        _success = message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.toString();
      });
    }
  }

  TextStyle _t({double size = 14, FontWeight? w, Color? c}) =>
      screenText(size: size, weight: w ?? FontWeight.w400, color: c ?? AppTheme.textPrimary);

  Widget _fact(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 130,
          child: Text(label, style: _t(size: 13, c: AppTheme.textSecondary)),
        ),
        Expanded(child: Text(value, style: _t(size: 13.5))),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final u = _user;
    return AccountDialogShell(
      icon: Icons.manage_accounts,
      title: 'แก้ไขผู้ใช้: ${u.username}',
      subtitle: u.fullName.isEmpty ? '-' : u.fullName,
      onClose: _busy
          ? null
          : () => Navigator.of(context).pop(_changed ? u : null),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_error != null) ...[
            AccountBanner.error(_error!),
            const SizedBox(height: 10),
          ],
          if (_success != null) ...[
            AccountBanner.success(_success!),
            const SizedBox(height: 10),
          ],
          _fact('เลขบัตรประชาชน', Util.maskIdcard(u.idcard)),
          _fact(
            'สมาชิกฌาปนกิจ',
            u.member ? 'เป็นสมาชิก เลขที่ ${u.memberNo ?? '-'}' : 'ไม่ใช่สมาชิก',
          ),
          _fact('ผู้นำไฟล์เข้า', u.uploader ? 'มีสิทธิ์' : 'ไม่มี'),
          _fact(
            'บทบาทที่ใช้งาน',
            u.roles.isEmpty ? '-' : u.roles.map(Roles.nameOf).join(', '),
          ),
          _fact('ลงทะเบียนเมื่อ', Util.thaiDateOf(u.createdAt)),
          _fact('เข้าสู่ระบบล่าสุด', Util.thaiDateTimeOf(u.lastLogin)),
          const Divider(height: 24),
          Text('ประเภทบุคลากร', style: _t(w: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(
            'ใช้กรองแบบฟอร์ม (ข้าราชการเห็นแบบฟอร์มข้าราชการ ลูกจ้างประจำเห็นของลูกจ้างประจำ)',
            style: _t(size: 12, c: AppTheme.textSecondary),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              for (final t in <String?>[...PersonType.names.keys, null])
                ChoiceChip(
                  key: UserAdminDialog.personTypeKey(t),
                  label: Text(
                    t == null ? 'ไม่ทราบ' : PersonType.nameOf(t),
                    style: _t(),
                  ),
                  selected: _personType == t,
                  onSelected: _busy
                      ? null
                      : (_) => setState(() => _personType = t),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Text('บทบาทที่ผู้ดูแลกำหนด', style: _t(w: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(
            'สมาชิก/ไม่ใช่สมาชิก และผู้นำไฟล์เข้า ระบบตั้งเองทุกครั้งที่เข้าสู่ระบบ',
            style: _t(size: 12, c: AppTheme.textSecondary),
          ),
          for (final r in _assignable)
            CheckboxListTile(
              key: UserAdminDialog.roleKey(r.name),
              dense: true,
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: _assigned.contains(r.name),
              title: Text(r.label, style: _t()),
              subtitle: r.description.isEmpty || r.description == r.label
                  ? null
                  : Text(r.description, style: _t(size: 12)),
              onChanged: _busy
                  ? null
                  : (v) => setState(() {
                      if (v == true) {
                        _assigned.add(r.name);
                      } else {
                        _assigned.remove(r.name);
                      }
                    }),
            ),
          const SizedBox(height: 6),
          SwitchListTile(
            key: UserAdminDialog.activeKey,
            contentPadding: EdgeInsets.zero,
            value: _active,
            title: Text('เปิดใช้งานบัญชี', style: _t()),
            subtitle: Text(
              _active ? 'ใช้งานได้' : 'ระงับการใช้งาน (เข้าสู่ระบบไม่ได้)',
              style: _t(size: 12, c: AppTheme.textSecondary),
            ),
            onChanged: _busy ? null : (v) => setState(() => _active = v),
          ),
          SwitchListTile(
            key: UserAdminDialog.lockedKey,
            contentPadding: EdgeInsets.zero,
            value: _locked,
            title: Text('ล็อกบัญชี', style: _t()),
            subtitle: Text(
              _locked
                  ? 'ล็อกอยู่ (เช่น ใส่รหัสผ่านผิดหลายครั้ง) ปิดสวิตช์เพื่อปลดล็อก'
                  : 'ไม่ได้ล็อก',
              style: _t(size: 12, c: AppTheme.textSecondary),
            ),
            onChanged: _busy ? null : (v) => setState(() => _locked = v),
          ),
          const Divider(height: 24),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                key: UserAdminDialog.resetPasswordKey,
                onPressed: _busy ? null : _resetPassword,
                icon: const Icon(Icons.lock_reset, size: 18),
                label: Text('ตั้งรหัสผ่านใหม่', style: _t()),
              ),
              if (u.twoFactorEnabled)
                OutlinedButton.icon(
                  key: UserAdminDialog.disable2faKey,
                  onPressed: _busy
                      ? null
                      : () => _action(
                          'ปิดการยืนยันตัวตนสองขั้นของ "${u.username}"?\n'
                          'ใช้เมื่อผู้ใช้ทำมือถือหายหรือใช้แอป Authenticator ไม่ได้',
                          () => widget.apiService.adminDisableTwoFactor(u.id),
                          apply: (x) => x.copyWith(twoFactorEnabled: false),
                        ),
                  icon: const Icon(Icons.phonelink_erase, size: 18),
                  label: Text('ปิด 2FA', style: _t()),
                ),
              OutlinedButton.icon(
                key: UserAdminDialog.deletePasskeysKey,
                onPressed: _busy
                    ? null
                    : () => _action(
                        'ลบ passkey (ลายนิ้วมือ/Windows Hello) ทั้งหมดของ "${u.username}"?',
                        () => widget.apiService.adminDeletePasskeys(u.id),
                      ),
                icon: const Icon(Icons.fingerprint, size: 18),
                label: Text('ลบ passkey ทั้งหมด', style: _t()),
              ),
            ],
          ),
          const SizedBox(height: 20),
          AccountActionButtons(
            key: UserAdminDialog.saveKey,
            cancelText: 'ปิด',
            confirmText: 'บันทึก',
            confirmIcon: Icons.save,
            loading: _busy,
            onCancel: () => Navigator.of(context).pop(_changed ? u : null),
            onConfirm: _save,
          ),
        ],
      ),
    );
  }
}

/// ถามรหัสผ่านใหม่ (+ ยืนยัน) ที่ผู้ดูแลตั้งให้ผู้ใช้ — ผู้ใช้ต้องเปลี่ยนเองตอนเข้าสู่ระบบครั้งถัดไป
class _NewPasswordDialog extends StatefulWidget {
  final String username;

  const _NewPasswordDialog({required this.username});

  @override
  State<_NewPasswordDialog> createState() => _NewPasswordDialogState();
}

class _NewPasswordDialogState extends State<_NewPasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _ok() {
    if (!_formKey.currentState!.validate()) return;
    if (!PasswordRules.of(_password.text).allPassed) {
      setState(() => _error = PasswordRules.notMetMessage);
      return;
    }
    Navigator.of(context).pop(_password.text);
  }

  @override
  Widget build(BuildContext context) {
    return AccountDialogShell(
      icon: Icons.lock_reset,
      title: 'ตั้งรหัสผ่านใหม่',
      subtitle: 'บัญชี ${widget.username} — ผู้ใช้ต้องเปลี่ยนรหัสผ่านเองตอนเข้าสู่ระบบครั้งถัดไป',
      onClose: () => Navigator.of(context).pop(),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_error != null) ...[
              AccountBanner.error(_error!),
              const SizedBox(height: 10),
            ],
            NewPasswordFields(
              password: _password,
              confirm: _confirm,
              label: 'รหัสผ่านใหม่',
            ),
            const SizedBox(height: 18),
            AccountActionButtons(
              confirmText: 'ตั้งรหัสผ่าน',
              confirmIcon: Icons.lock_reset,
              onCancel: () => Navigator.of(context).pop(),
              onConfirm: _ok,
            ),
          ],
        ),
      ),
    );
  }
}
