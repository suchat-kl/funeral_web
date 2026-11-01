import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../models/passkey.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../utils/dialog.dart';
import '../utils/passkey.dart';
import '../utils/util.dart';
import 'account_form.dart';

/// เมนู "ลายนิ้วมือ / Windows Hello" ของบัญชีผู้ใช้ — ใช้ร่วมกันทั้งเมนูข้างและเมนูผู้ใช้บนแถบบน
///
/// [context] ต้องยังใช้ได้ตลอดจนหน้าต่างปิด เมนูข้างจึงส่ง context ของ navigator ชั้นนอกมา
Future<void> showPasskeyDialog(
  BuildContext context,
  AuthProvider authProvider,
) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => PasskeyDialog(
      apiService: ApiService(),
      authenticator: createPasskeyAuthenticator(),
    ),
  );
}

/// หน้าต่างจัดการ passkey (เข้าสู่ระบบด้วยลายนิ้วมือ/Windows Hello) ของบัญชีตัวเอง
///
/// - รายการ passkey: ชื่อ วันที่เพิ่ม/ใช้ล่าสุด ป้าย sync ข้ามเครื่อง และปุ่มลบ (ลบได้จากทุก session)
/// - เพิ่ม: ตั้งชื่อ + รหัสผ่านปัจจุบัน (backend ฌาปนกิจบังคับทุก session) → เบราว์เซอร์ขึ้นหน้าสแกน → backend ตรวจแล้วเก็บ
///   ครบจำนวนสูงสุด (5) แล้วเพิ่มไม่ได้จนกว่าจะลบรายการเดิม
/// - passkey ใช้ RP ID inf.doh.go.th ร่วมกับสลิปภาษี: ชื่อในเครื่องขึ้นต้น "ฌาปนกิจ: " (backend ตั้งให้)
/// รหัสผ่านและผลจากตัวยืนยันตัวตนอยู่ใน state ของหน้าต่างนี้เท่านั้น ไม่เก็บลงที่เก็บของเบราว์เซอร์ ไม่ log
class PasskeyDialog extends StatefulWidget {
  final ApiService apiService;
  final PasskeyAuthenticator authenticator;

  const PasskeyDialog({
    super.key,
    required this.apiService,
    required this.authenticator,
  });

  static const String title = 'ลายนิ้วมือ / Windows Hello';

  /// คำอธิบายบนหน้าต่าง
  static const String aboutMessage =
      'เข้าสู่ระบบด้วยการสแกนลายนิ้วมือ ใบหน้า หรือ PIN ของเครื่อง (Windows Hello, Touch ID, โทรศัพท์) '
      'แทนการกรอกรหัสผ่าน: กดปุ่ม "ลายนิ้วมือ / Windows Hello" ในหน้าเข้าสู่ระบบ\n'
      'ใช้ได้เมื่อเปิดระบบที่ $passkeyHomeUrl\n'
      'passkey ของระบบนี้แยกจากของระบบสลิปภาษี (ในเครื่องจะเห็นชื่อขึ้นต้นว่า "ฌาปนกิจ:")';

  @override
  State<PasskeyDialog> createState() => _PasskeyDialogState();
}

class _PasskeyDialogState extends State<PasskeyDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _loading = true;
  bool _busy = false;
  bool _adding = false;
  bool _obscurePassword = true;
  String? _error;
  String? _success;
  PasskeyList? _list;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String _message(Object e) => e.toString().replaceAll('Exception: ', '');

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await widget.apiService.passkeyList();
      if (!mounted) return;
      setState(() {
        _list = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = _message(e);
        _loading = false;
      });
    }
  }

  void _startAdd() {
    _nameController.text = widget.authenticator.defaultName();
    _passwordController.clear();
    setState(() {
      _adding = true;
      _error = null;
      _success = null;
    });
  }

  void _cancelAdd() {
    _passwordController.clear();
    setState(() {
      _adding = false;
      _error = null;
    });
  }

  /// ขอ options (ยืนยันรหัสผ่าน) → สแกน → ส่งผลให้ backend เก็บ
  Future<void> _add() async {
    if (_busy || !_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
      _success = null;
    });
    try {
      final options = await widget.apiService.passkeyRegisterOptions(
        _passwordController.text,
      );
      // รหัสผ่านผ่านแล้ว ไม่ต้องใช้อีก (ลองใหม่ต้องกรอกใหม่)
      _passwordController.clear();
      final credential = await widget.authenticator.create(options);
      if (!mounted) return;
      if (credential == null) {
        setState(() {
          _busy = false;
          _error = passkeyCancelledMessage;
        });
        return;
      }
      final added = await widget.apiService.passkeyRegister(
        credential,
        name: _nameController.text,
      );
      if (!mounted) return;
      setState(() {
        _busy = false;
        _adding = false;
        _success =
            'เพิ่ม "${added.name}" เรียบร้อย ใช้เข้าสู่ระบบครั้งถัดไปได้เลย';
      });
      await _load();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = _message(e);
      });
    }
  }

  Future<void> _delete(PasskeyInfo p) async {
    final ok = await AppDialog.showConfirm(
      context,
      'ลบ "${p.name}"?\nอุปกรณ์นี้จะใช้เข้าสู่ระบบไม่ได้อีก '
      '(ลบออกจากตัวจัดการรหัสผ่านของเครื่องด้วยได้ที่การตั้งค่าของเครื่อง)',
      confirmText: 'ลบ',
    );
    if (ok != true || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
      _success = null;
    });
    try {
      final message = await widget.apiService.passkeyDelete(p.id);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _success = message;
      });
      await _load();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = _message(e);
      });
    }
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
      icon: Icons.fingerprint,
      title: PasskeyDialog.title,
      subtitle: 'เข้าสู่ระบบด้วย passkey ไม่ต้องกรอกรหัสผ่าน',
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
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_adding)
              ..._buildAdd()
            else
              ..._buildList(),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildList() {
    final list = _list;
    if (list == null) {
      return [
        AccountActionButtons(
          cancelText: 'ปิด',
          confirmText: 'ลองใหม่',
          confirmIcon: Icons.refresh,
          onCancel: () => Navigator.of(context).pop(),
          onConfirm: _load,
        ),
      ];
    }
    final String? note = list.full
        ? 'เพิ่มได้ไม่เกิน ${list.max} รายการ ลบรายการที่ไม่ใช้แล้วก่อนจึงจะเพิ่มใหม่ได้'
        : !widget.authenticator.isSupported()
        ? const PasskeyException(PasskeyErrorKind.unsupported).message
        : null;
    final canAdd = note == null;
    return [
      AccountBanner.info(PasskeyDialog.aboutMessage),
      const SizedBox(height: 14),
      if (list.passkeys.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(
            'ยังไม่มี passkey ของบัญชีนี้',
            textAlign: TextAlign.center,
            style: _text(color: AppTheme.textSecondary),
          ),
        )
      else
        for (final p in list.passkeys) ...[
          _buildItem(p),
          const SizedBox(height: 8),
        ],
      if (note != null) ...[
        const SizedBox(height: 6),
        Text(
          note,
          key: const ValueKey('passkey-add-note'),
          style: _text(size: 13, color: AppTheme.textSecondary),
        ),
      ],
      const SizedBox(height: 18),
      AccountActionButtons(
        cancelText: 'ปิด',
        confirmText: 'เพิ่ม passkey',
        confirmIcon: Icons.add,
        loading: _busy,
        onCancel: () => Navigator.of(context).pop(),
        onConfirm: canAdd ? _startAdd : null,
      ),
    ];
  }

  Widget _buildItem(PasskeyInfo p) {
    final dates = [
      if (p.createdAt != null)
        'เพิ่มเมื่อ ${Util.formatThaiDate(p.createdAt!)}',
      p.lastUsedAt == null
          ? 'ยังไม่เคยใช้'
          : 'ใช้ล่าสุด ${Util.formatThaiDate(p.lastUsedAt!)}',
    ].join(' · ');
    return Container(
      key: ValueKey('passkey-${p.id}'),
      padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(
            p.synced ? Icons.cloud_sync : Icons.fingerprint,
            color: AppTheme.primaryColor,
            size: 28,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.name, style: _text(size: 15, weight: FontWeight.bold)),
                Text(
                  dates,
                  style: _text(size: 12, color: AppTheme.textSecondary),
                ),
                if (p.synced)
                  Text(
                    'sync ข้ามเครื่องได้ (เช่น บัญชี Google / iCloud)',
                    style: _text(size: 12, color: AppTheme.textSecondary),
                  ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'ลบ',
            icon: const Icon(Icons.delete_outline, color: AppTheme.deleteColor),
            onPressed: _busy ? null : () => _delete(p),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildAdd() {
    return [
      Text(
        'ตั้งชื่อให้จำได้ว่าเป็นอุปกรณ์ไหน กรอกรหัสผ่านปัจจุบัน แล้วกด "สแกนเพื่อเพิ่ม" '
        'เครื่องจะขึ้นหน้าสแกนลายนิ้วมือ/ใบหน้า/PIN',
        style: _text(),
      ),
      const SizedBox(height: 14),
      AccountField(
        label: 'ชื่ออุปกรณ์',
        hint: 'เช่น Windows Hello เครื่องที่ทำงาน',
        icon: Icons.label_outline,
        controller: _nameController,
        enabled: !_busy,
        validator: (v) =>
            (v == null || v.trim().isEmpty) ? 'กรุณาตั้งชื่ออุปกรณ์' : null,
      ),
      ...[
        const SizedBox(height: 14),
        AccountField(
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
            onPressed: () =>
                setState(() => _obscurePassword = !_obscurePassword),
          ),
          validator: (v) =>
              (v == null || v.isEmpty) ? 'กรุณากรอกรหัสผ่านปัจจุบัน' : null,
        ),
      ],
      const SizedBox(height: 22),
      AccountActionButtons(
        cancelText: 'ย้อนกลับ',
        confirmText: 'สแกนเพื่อเพิ่ม',
        confirmIcon: Icons.fingerprint,
        loading: _busy,
        onCancel: _cancelAdd,
        onConfirm: _add,
      ),
    ];
  }
}
