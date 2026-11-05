import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/theme.dart';
import '../models/register_ticket.dart';
import '../services/api_service.dart';
import '../utils/roles.dart';
import '../utils/thaid.dart';
import '../utils/util.dart';
import 'account_form.dart';
import 'screen_parts.dart';

/// ผลของหน้าต่างลงทะเบียน: ลงทะเบียนสำเร็จ ([username]) หรือผู้ใช้เลือกไปหน้าลืมรหัสผ่าน (เลขบัตรมีบัญชีแล้ว)
class RegisterResult {
  final String? username;
  final bool goForgotPassword;

  const RegisterResult.registered(String this.username)
    : goForgotPassword = false;

  const RegisterResult.forgotPassword()
    : username = null,
      goForgotPassword = true;
}

/// ขั้นของการลงทะเบียน
enum RegisterStep {
  /// ขั้น 1: เป็นสมาชิก / ไม่เป็นสมาชิก
  choose,

  /// ขั้น 2: ทางยืนยันตัวตน (สมาชิก: แบบเดิม หรือ ThaID / ไม่เป็นสมาชิก: ThaID เท่านั้น)
  verify,

  /// ขั้น 3: ตั้งชื่อผู้ใช้ + รหัสผ่านด้วยใบผ่าน
  account,
}

/// ทางยืนยันตัวตนของสมาชิกในขั้นที่ 2
enum MemberWay { legacy, thaid }

/// หน้าต่างลงทะเบียน (ข้อกำหนดหัวข้อ 3) — ไม่ต้องเข้าสู่ระบบ
///
/// ขั้น 1 เลือก "เป็นสมาชิก" / "ไม่เป็นสมาชิก" → ขั้น 2 ยืนยันตัวตน → ขั้น 3 ตั้งชื่อผู้ใช้ + รหัสผ่าน
/// - เป็นสมาชิก แบบเดิม: เลขบัตร + เลขสมาชิก (ไม่ใช้วันเกิด: ผู้เกษียณบางคนมีแค่ปีเกิด) — ไม่ตรงไม่บอกว่าช่องไหนผิด
/// - เป็นสมาชิก ThaID / ไม่เป็นสมาชิก ThaID (ไม่เป็นสมาชิกมีทางเดียว)
/// - ทุกทางได้ใบผ่าน ([RegisterTicket]) อายุสั้น ชื่อซ้ำ (409 DUPLICATE) ใช้ใบผ่านเดิมแก้ชื่อได้
///   ใบผ่านหมดอายุ (REGISTER_TICKET_INVALID) ต้องเริ่มใหม่ เลขบัตรมีบัญชีแล้ว (ALREADY_REGISTERED) ชวนไปลืมรหัสผ่าน
///
/// ใบผ่าน ชื่อ เลขบัตร อยู่ใน state ของหน้าต่างนี้เท่านั้น ไม่ log ไม่เก็บลงที่เก็บของเบราว์เซอร์
/// ข้อความแจ้งผู้ที่จะได้ประเภท U (ผู้ใช้สั่ง 5 พ.ย. 2569)
const String unknownContactText =
    'หากต้องการดาวน์โหลดทะเบียนคุมรายชื่อ ให้ติดต่องานฌาปนกิจ (โทร 25142)';

class RegisterDialog extends StatefulWidget {
  final ApiService apiService;

  /// ตัวเปิด ThaID (เทสต์ส่งตัวปลอม) ไม่ส่ง = [currentThaidAuthorizer]
  final ThaidAuthorizer? thaidAuthorizer;

  const RegisterDialog({
    super.key,
    required this.apiService,
    this.thaidAuthorizer,
  });

  static const Key memberKey = ValueKey('register-member');
  static const Key nonMemberKey = ValueKey('register-non-member');
  static const Key legacyWayKey = ValueKey('register-way-legacy');
  static const Key thaidWayKey = ValueKey('register-way-thaid');
  static const Key idcardKey = ValueKey('register-idcard');
  static const Key memberNoKey = ValueKey('register-member-no');
  static const Key verifyKey = ValueKey('register-verify');
  static const Key thaidButtonKey = ValueKey('register-thaid');
  static const Key usernameKey = ValueKey('register-username');
  static const Key submitKey = ValueKey('register-submit');
  static const Key verifiedKey = ValueKey('register-verified');
  static const Key unknownContactKey = ValueKey('register-unknown-contact');
  static const Key alreadyKey = ValueKey('register-already');
  static const Key goForgotKey = ValueKey('register-go-forgot');
  static const Key goNonMemberKey = ValueKey('register-go-non-member');
  static const Key backKey = ValueKey('register-back');

  /// ข้อความเมื่อใบผ่านหมดอายุ (ต้องเริ่มใหม่)
  static const String ticketExpiredMessage =
      'หมดเวลาลงทะเบียน กรุณาเริ่มลงทะเบียนใหม่อีกครั้ง';

  /// คำแนะนำเมื่อเลขบัตรนี้มีบัญชีแล้ว
  static const String alreadyHint =
      'ถ้าจำรหัสผ่านไม่ได้ ใช้ "ลืมรหัสผ่าน" แล้วยืนยันตัวตนด้วย ThaID เพื่อตั้งรหัสผ่านใหม่';

  /// กติกาชื่อผู้ใช้ (ตรงกับ backend): ตรวจแค่ความยาว 4-30 ตัว
  static const String usernameRule = 'ยาว 4-30 ตัวอักษร';

  /// ตรวจชื่อผู้ใช้แบบเดียวกับ backend ผ่าน = null
  /// นับตามตัวอักษรจริง (rune) และกันอักขระควบคุม (ขึ้นบรรทัดใหม่ แท็บ) ที่มองไม่เห็น
  static String? validateUsername(String? value) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return 'กรุณากรอกชื่อผู้ใช้';
    final len = v.runes.length;
    if (len < 4 || len > 30) return 'ชื่อผู้ใช้ต้อง$usernameRule';
    if (RegExp(r'[\x00-\x1F\x7F-\x9F]').hasMatch(v)) {
      return 'ชื่อผู้ใช้มีอักขระที่ใช้ไม่ได้';
    }
    return null;
  }

  @override
  State<RegisterDialog> createState() => _RegisterDialogState();
}

class _RegisterDialogState extends State<RegisterDialog> {
  final _formKey = GlobalKey<FormState>();
  final _idcard = TextEditingController();
  final _memberNo = TextEditingController();
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  RegisterStep _step = RegisterStep.choose;
  bool? _member;
  MemberWay _way = MemberWay.legacy;
  RegisterTicket? _ticket;
  bool _busy = false;
  String? _error;
  String? _info;

  /// เลขบัตรนี้มีบัญชีแล้ว: แสดงปุ่มไปหน้าลืมรหัสผ่าน
  bool _already = false;

  /// ไม่พบในทะเบียนสมาชิก (ThaID ทางสมาชิก): แสดงปุ่มลงทะเบียนแบบไม่เป็นสมาชิก
  bool _notMember = false;

  /// ชื่อผู้ใช้ซ้ำ (409) แสดงใต้ช่อง
  String? _usernameError;

  @override
  void dispose() {
    _ticket = null;
    for (final c in [_idcard, _memberNo, _username, _password, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  void _clearMessages() {
    _error = null;
    _info = null;
    _already = false;
    _notMember = false;
    _usernameError = null;
  }

  void _choose(bool member) {
    setState(() {
      _clearMessages();
      _member = member;
      _way = member ? MemberWay.legacy : MemberWay.thaid;
      _step = RegisterStep.verify;
    });
  }

  /// กลับไปขั้นก่อนหน้า (จากขั้น 3 ทิ้งใบผ่าน ต้องยืนยันตัวตนใหม่)
  void _back() {
    setState(() {
      _clearMessages();
      if (_step == RegisterStep.account) {
        _ticket = null;
        _password.clear();
        _confirm.clear();
        _step = RegisterStep.verify;
      } else {
        _step = RegisterStep.choose;
      }
    });
  }

  /// เริ่มใหม่ทั้งหมด (ใบผ่านหมดอายุ)
  void _restart(String message) {
    _ticket = null;
    _password.clear();
    _confirm.clear();
    setState(() {
      _clearMessages();
      _step = RegisterStep.choose;
      _member = null;
      _error = message;
    });
  }

  /// ข้อผิดพลาดของขั้นที่ 2 (ทั้งแบบเดิมและ ThaID)
  void _verifyFailed(Object e) {
    setState(() {
      _busy = false;
      _error = e.toString();
      if (e is ApiException) {
        _already = e.code == ErrorCodes.alreadyRegistered;
        _notMember = e.code == ErrorCodes.notMember;
      }
    });
  }

  void _gotTicket(RegisterTicket t) {
    setState(() {
      _busy = false;
      _ticket = t;
      _clearMessages();
      _step = RegisterStep.account;
    });
  }

  /// เป็นสมาชิก แบบเดิม: ตรวจเลขบัตร + เลขสมาชิก
  Future<void> _verifyLegacy() async {
    if (_busy || !_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _clearMessages();
    });
    try {
      final t = await widget.apiService.registerLegacyVerify(
        idcard: _idcard.text.trim(),
        memberNo: _memberNo.text.trim(),
      );
      if (!mounted) return;
      _gotTicket(t);
    } catch (e) {
      if (mounted) _verifyFailed(e);
    }
  }

  /// ยืนยันด้วย ThaID (ทางสมาชิก หรือไม่เป็นสมาชิก)
  Future<void> _verifyThaid() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _clearMessages();
    });
    try {
      final authorize = widget.thaidAuthorizer ?? currentThaidAuthorizer;
      final state = await authorize(
        widget.apiService,
        purpose: ApiService.thaidPurposeRegister,
      );
      if (!mounted) return;
      if (state == null) {
        setState(() {
          _busy = false;
          _info = thaidCancelledMessage;
        });
        return;
      }
      final t = await widget.apiService.thaidRegister(
        state,
        _member == true
            ? ApiService.registerModeMember
            : ApiService.registerModeNonMember,
      );
      if (!mounted) return;
      _gotTicket(t);
    } catch (e) {
      if (mounted) _verifyFailed(e);
    }
  }

  /// ขั้น 3: ตั้งชื่อผู้ใช้ + รหัสผ่าน
  Future<void> _complete() async {
    final ticket = _ticket;
    if (_busy || ticket == null) return;
    setState(() => _usernameError = null);
    if (!_formKey.currentState!.validate()) return;
    if (!PasswordRules.of(_password.text).allPassed) {
      setState(() => _error = PasswordRules.notMetMessage);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final r = await widget.apiService.registerComplete(
        ticket: ticket.ticket,
        username: _username.text.trim(),
        password: _password.text,
      );
      if (!mounted) return;
      Navigator.of(context).pop(RegisterResult.registered(r.username));
    } catch (e) {
      if (!mounted) return;
      final code = e is ApiException ? e.code : null;
      if (code == ErrorCodes.registerTicketInvalid) {
        _restart(
          e is ApiException && e.message.isNotEmpty
              ? '${e.message}\n${RegisterDialog.ticketExpiredMessage}'
              : RegisterDialog.ticketExpiredMessage,
        );
        return;
      }
      setState(() {
        _busy = false;
        if (code == ErrorCodes.duplicate) {
          // ชื่อซ้ำ: ใบผ่านยังใช้ได้ แก้ชื่อแล้วกดใหม่
          _usernameError = e.toString();
        } else {
          _error = e.toString();
          _already = code == ErrorCodes.alreadyRegistered;
        }
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

  String get _stepTitle => switch (_step) {
    RegisterStep.choose => 'ขั้นที่ 1 จาก 3: ท่านเป็นสมาชิกฌาปนกิจหรือไม่',
    RegisterStep.verify => 'ขั้นที่ 2 จาก 3: ยืนยันตัวตน',
    RegisterStep.account => 'ขั้นที่ 3 จาก 3: ตั้งชื่อผู้ใช้และรหัสผ่าน',
  };

  @override
  Widget build(BuildContext context) {
    return AccountDialogShell(
      icon: Icons.how_to_reg,
      title: 'ลงทะเบียน',
      subtitle: _stepTitle,
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
            if (_already) ...[
              Container(
                key: RegisterDialog.alreadyKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(RegisterDialog.alreadyHint, style: _text(size: 13)),
                    const SizedBox(height: 6),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton.icon(
                        key: RegisterDialog.goForgotKey,
                        onPressed: () => Navigator.of(
                          context,
                        ).pop(const RegisterResult.forgotPassword()),
                        icon: const Icon(Icons.password, size: 18),
                        label: Text(
                          'ลืมรหัสผ่าน (ยืนยันด้วย ThaID)',
                          style: _text(size: 14),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (_notMember) ...[
              Text(
                'ไม่พบเลขบัตรในทะเบียนสมาชิกฌาปนกิจ ถ้าท่านไม่ได้เป็นสมาชิก ลงทะเบียนแบบ "ไม่เป็นสมาชิก" ได้',
                style: _text(size: 13),
              ),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  key: RegisterDialog.goNonMemberKey,
                  onPressed: _busy ? null : () => _choose(false),
                  icon: const Icon(Icons.person_outline, size: 18),
                  label: Text(
                    'ลงทะเบียนแบบไม่เป็นสมาชิก',
                    style: _text(size: 14),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (_info != null) ...[
              AccountBanner.info(_info!),
              const SizedBox(height: 12),
            ],
            ...switch (_step) {
              RegisterStep.choose => _buildChoose(),
              RegisterStep.verify => _buildVerify(),
              RegisterStep.account => _buildAccount(),
            },
          ],
        ),
      ),
    );
  }

  List<Widget> _buildChoose() => [
    Text(
      'ระบบใช้ข้อมูลนี้ตรวจสอบสิทธิ์ สมาชิกฌาปนกิจดาวน์โหลดใบเสร็จรับเงินของตนเองได้ '
      'ผู้ที่ไม่ได้เป็นสมาชิกดาวน์โหลดแบบฟอร์มและทะเบียนคุมรายชื่อได้',
      style: _text(),
    ),
    const SizedBox(height: 14),
    ChoiceCard(
      key: RegisterDialog.memberKey,
      icon: Icons.card_membership,
      title: 'เป็นสมาชิกฌาปนกิจ',
      subtitle: 'ยืนยันด้วยเลขบัตร + เลขสมาชิก หรือด้วย ThaID',
      selected: _member == true,
      onTap: () => _choose(true),
    ),
    const SizedBox(height: 10),
    ChoiceCard(
      key: RegisterDialog.nonMemberKey,
      icon: Icons.person_outline,
      title: 'ไม่เป็นสมาชิก',
      subtitle: 'ข้าราชการ/ลูกจ้างประจำกรมทางหลวง ยืนยันด้วย ThaID เท่านั้น',
      selected: _member == false,
      onTap: () => _choose(false),
    ),
    const SizedBox(height: 18),
    AccountActionButtons(
      cancelText: 'ปิด',
      confirmText: 'ถัดไป',
      confirmIcon: Icons.arrow_forward,
      onCancel: () => Navigator.of(context).pop(),
      onConfirm: _member == null ? null : () => _choose(_member!),
    ),
  ];

  List<Widget> _buildVerify() {
    final member = _member == true;
    return [
      if (member) ...[
        Text('เลือกวิธียืนยันตัวตน', style: _text(weight: FontWeight.w600)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: ChoiceCard(
                key: RegisterDialog.legacyWayKey,
                icon: Icons.badge_outlined,
                title: 'แบบเดิม',
                subtitle: 'เลขบัตร + เลขสมาชิก',
                selected: _way == MemberWay.legacy,
                onTap: _busy
                    ? null
                    : () => setState(() {
                        _clearMessages();
                        _way = MemberWay.legacy;
                      }),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ChoiceCard(
                key: RegisterDialog.thaidWayKey,
                icon: Icons.verified_user_outlined,
                title: 'ThaID',
                subtitle: 'สแกนด้วยแอป ThaID',
                selected: _way == MemberWay.thaid,
                onTap: _busy
                    ? null
                    : () => setState(() {
                        _clearMessages();
                        _way = MemberWay.thaid;
                      }),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
      ],
      if (member && _way == MemberWay.legacy)
        ..._buildLegacyForm()
      else
        ..._buildThaid(member),
    ];
  }

  List<Widget> _buildLegacyForm() => [
    AccountField(
      key: RegisterDialog.idcardKey,
      label: 'เลขบัตรประชาชน 13 หลัก',
      hint: 'กรอกเลขบัตรประชาชน',
      icon: Icons.credit_card,
      controller: _idcard,
      enabled: !_busy,
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(13),
      ],
      validator: (v) {
        final s = (v ?? '').trim();
        if (s.isEmpty) return 'กรุณากรอกเลขบัตรประชาชน';
        if (!Util.isValidThaiId(s)) return 'เลขบัตรประชาชนไม่ถูกต้อง';
        return null;
      },
    ),
    const SizedBox(height: 12),
    AccountField(
      key: RegisterDialog.memberNoKey,
      label: 'เลขสมาชิกฌาปนกิจ',
      hint: 'กรอกเลขสมาชิก',
      icon: Icons.confirmation_number_outlined,
      controller: _memberNo,
      enabled: !_busy,
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(10),
      ],
      validator: (v) => (v ?? '').trim().isEmpty ? 'กรุณากรอกเลขสมาชิก' : null,
    ),
    const SizedBox(height: 8),
    Text(
      'ข้อมูลต้องตรงกับทะเบียนสมาชิกฌาปนกิจ ถ้าไม่ตรง ระบบจะไม่บอกว่าช่องใดผิด และจำกัดจำนวนครั้งที่ลอง',
      style: _text(size: 12, color: AppTheme.textSecondary),
    ),
    const SizedBox(height: 18),
    AccountActionButtons(
      key: RegisterDialog.verifyKey,
      cancelText: 'ย้อนกลับ',
      confirmText: 'ตรวจสอบ',
      confirmIcon: Icons.fact_check_outlined,
      loading: _busy,
      onCancel: _back,
      onConfirm: _verifyLegacy,
    ),
  ];

  List<Widget> _buildThaid(bool member) => [
    AccountBanner.info(
      member
          ? 'กดปุ่มด้านล่างแล้วสแกน QR ด้วยแอป ThaID ระบบจะตรวจเลขบัตรของท่านกับทะเบียนสมาชิกฌาปนกิจ'
          : 'ผู้ที่ไม่ได้เป็นสมาชิกลงทะเบียนได้ด้วย ThaID เท่านั้น ระบบจะตรวจเลขบัตรกับข้อมูลบุคลากรกรมทางหลวง '
                'เพื่อกำหนดประเภทบุคลากร (ถ้าไม่พบ ระบบตั้งเป็นไม่ทราบประเภท (U) '
                'และถ้าพบในทะเบียนสมาชิกด้วย ระบบตั้งเป็นสมาชิกให้) '
                '$unknownContactText',
    ),
    const SizedBox(height: 16),
    SizedBox(
      height: 50,
      child: ElevatedButton.icon(
        key: RegisterDialog.thaidButtonKey,
        onPressed: _busy ? null : _verifyThaid,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF06115A),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        icon: _busy
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.qr_code_scanner),
        label: Text(
          _busy ? 'กำลังรอผลจาก ThaID...' : 'ยืนยันตัวตนด้วย ThaID',
          style: _text(size: 15, weight: FontWeight.w600, color: Colors.white),
        ),
      ),
    ),
    const SizedBox(height: 12),
    Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        key: RegisterDialog.backKey,
        onPressed: _busy ? null : _back,
        icon: const Icon(Icons.arrow_back, size: 18),
        label: Text('ย้อนกลับ', style: _text()),
      ),
    ),
  ];

  List<Widget> _buildAccount() {
    final t = _ticket!;
    final minutes = t.expiresInMinutes;
    return [
      Container(
        key: RegisterDialog.verifiedKey,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.successColor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppTheme.successColor.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.verified, color: AppTheme.successColor),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ยืนยันตัวตนแล้ว',
                    style: _text(
                      size: 12,
                      color: AppTheme.successColor,
                      weight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    t.fullName.isEmpty ? '-' : t.fullName,
                    style: _text(size: 16, weight: FontWeight.bold),
                  ),
                  Text(
                    t.member
                        ? 'สมาชิกฌาปนกิจ${t.memberNo == null ? '' : ' เลขสมาชิก ${t.memberNo}'}'
                        : 'ไม่ใช่สมาชิกฌาปนกิจ',
                    style: _text(size: 13, color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      if (t.personType == PersonType.unknown) ...[
        const SizedBox(height: 10),
        Container(
          key: RegisterDialog.unknownContactKey,
          child: AccountBanner.info(
            'ไม่พบท่านในข้อมูลบุคลากรกรมทางหลวง ระบบตั้งประเภทบุคลากรเป็นไม่ทราบประเภท (U) '
            '$unknownContactText',
          ),
        ),
      ],
      const SizedBox(height: 8),
      Text(
        'ตั้งชื่อผู้ใช้และรหัสผ่านให้เสร็จ${minutes == null ? 'ภายในเวลาที่กำหนด' : 'ภายใน $minutes นาที'} '
        'ถ้าเกินเวลาต้องเริ่มลงทะเบียนใหม่',
        style: _text(size: 12, color: AppTheme.textSecondary),
      ),
      const SizedBox(height: 14),
      AccountField(
        key: RegisterDialog.usernameKey,
        label: 'ชื่อผู้ใช้',
        hint: 'เช่น somchai.j',
        icon: Icons.person,
        controller: _username,
        enabled: !_busy,
        helper: RegisterDialog.usernameRule,
        errorText: _usernameError,
        onChanged: (_) {
          if (_usernameError != null) setState(() => _usernameError = null);
        },
        validator: RegisterDialog.validateUsername,
      ),
      const SizedBox(height: 14),
      NewPasswordFields(
        password: _password,
        confirm: _confirm,
        enabled: !_busy,
      ),
      const SizedBox(height: 18),
      AccountActionButtons(
        key: RegisterDialog.submitKey,
        cancelText: 'ย้อนกลับ',
        confirmText: 'ลงทะเบียน',
        confirmIcon: Icons.how_to_reg,
        loading: _busy,
        onCancel: _back,
        onConfirm: _complete,
      ),
    ];
  }
}
