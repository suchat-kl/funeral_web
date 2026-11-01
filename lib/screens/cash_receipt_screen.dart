import 'dart:async';

import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../models/receipt.dart';
import '../services/api_service.dart';
import '../utils/roles.dart';
import '../utils/util.dart';
import '../widgets/pdf_password_picker.dart';
import '../widgets/screen_parts.dart';
import '../widgets/work_parts.dart';

/// ดาวน์โหลด › ใบเสร็จรับเงิน (เงินสด)
///
/// - สมาชิก: เลขสมาชิกล็อกเป็นของตัวเอง (backend ใช้เลขของบัญชีเสมอ ไม่ส่ง memberNo)
/// - ผู้นำไฟล์เข้า/ผู้ดูแล: ค้นสมาชิก (autocomplete พิมพ์อย่างน้อย 2 ตัว) แล้วออกให้ใครก็ได้
///   ออกให้ผู้อื่นใช้รหัสเปิดไฟล์ได้เฉพาะ "ไม่ใส่" / "กำหนดเอง" (เลขบัตร/วันเกิดเป็นของผู้ขอ ไม่ใช่ของเจ้าของใบเสร็จ)
/// - ปี พ.ศ. + เลือกหลายเดือน (ปุ่มชื่อเดือนไทย) → PDF ไฟล์เดียว
class CashReceiptScreen extends StatefulWidget {
  final ApiService apiService;

  /// วันนี้ (เทสต์ส่งวันตายตัว)
  final DateTime? today;

  const CashReceiptScreen({super.key, required this.apiService, this.today});

  static const String menuTitle = 'ใบเสร็จรับเงิน (เงินสด)';
  static const IconData menuIcon = Icons.payments_outlined;
  static const String groupTitle = 'ดาวน์โหลด';

  static const Key memberFieldKey = ValueKey('cash-member');
  static const Key lockedMemberKey = ValueKey('cash-member-locked');
  static const Key selectAllKey = ValueKey('cash-select-all');
  static const Key clearKey = ValueKey('cash-clear');
  static const Key downloadKey = ValueKey('cash-download');
  static const Key ownKey = ValueKey('cash-own');

  /// หน่วงเวลาค้นสมาชิกหลังพิมพ์ (ไม่ยิงทุกตัวอักษร)
  static const Duration searchDelay = Duration(milliseconds: 350);

  @override
  State<CashReceiptScreen> createState() => _CashReceiptScreenState();
}

class _CashReceiptScreenState extends State<CashReceiptScreen>
    with FileDownloads<CashReceiptScreen> {
  final _formKey = GlobalKey<FormState>();
  final _custom = TextEditingController();
  late final DateTime _today = widget.today ?? DateTime.now();
  late int _year = _today.year + 543;
  final Set<int> _months = {};
  String _passwordType = PdfPassword.none;
  String? _notice;

  /// สมาชิกที่ผู้นำไฟล์เข้า/ผู้ดูแลเลือกจากการค้น (null = ยังไม่เลือก)
  MemberHit? _picked;
  String? _searchError;
  int _searchSerial = 0;

  bool get _isStaff => MenuAccess(
    loggedIn: widget.apiService.isLoggedIn,
    roles: widget.apiService.roles,
  ).isStaff;

  String? get _ownMemberNo => widget.apiService.memberNo;

  /// เลขสมาชิกที่จะออกใบเสร็จ
  String? get _targetMemberNo => _isStaff ? _picked?.memberNo : _ownMemberNo;

  /// ใบเสร็จของตัวเอง (ใช้เลขบัตร/วันเกิดเป็นรหัสได้)
  bool get _own =>
      _targetMemberNo != null && _targetMemberNo == _ownMemberNo;

  List<String> get _passwordOptions =>
      _own ? PdfPassword.forSelf : PdfPassword.forOthers;

  @override
  void initState() {
    super.initState();
    // ผู้นำไฟล์เข้า/ผู้ดูแลที่เป็นสมาชิกด้วย: เริ่มที่ใบเสร็จของตัวเอง
    final own = _ownMemberNo;
    if (_isStaff && own != null) {
      _picked = MemberHit(
        memberNo: own,
        firstname: widget.apiService.fullName ?? '',
      );
    }
  }

  @override
  void dispose() {
    _custom.dispose();
    super.dispose();
  }

  void _changed(VoidCallback apply) {
    clearSaved();
    setState(() {
      _notice = null;
      downloadError = null;
      apply();
      if (!_passwordOptions.contains(_passwordType)) {
        _passwordType = PdfPassword.none;
      }
    });
  }

  /// ค้นสมาชิกสำหรับ autocomplete — หน่วงเวลา และทิ้งผลของคำค้นที่เก่ากว่า
  Future<Iterable<MemberHit>> _search(String text) async {
    final q = text.trim();
    final serial = ++_searchSerial;
    if (q.length < 2) return const [];
    await Future.delayed(CashReceiptScreen.searchDelay);
    if (serial != _searchSerial || !mounted) return const [];
    try {
      final hits = await widget.apiService.searchMembers(q);
      if (serial != _searchSerial || !mounted) return const [];
      if (_searchError != null) setState(() => _searchError = null);
      return hits;
    } catch (e) {
      if (mounted) setState(() => _searchError = e.toString());
      return const [];
    }
  }

  Future<void> _download() async {
    final target = _targetMemberNo;
    if (target == null) {
      setState(() => _notice = 'กรุณาค้นและเลือกสมาชิกก่อน');
      return;
    }
    if (_months.isEmpty) {
      setState(() => _notice = 'กรุณาเลือกเดือนอย่างน้อย 1 เดือน');
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    await runDownload(
      'cash',
      () => widget.apiService.downloadCashReceipts(
        // สมาชิกไม่ส่งเลข (backend ใช้ของบัญชี) ผู้นำไฟล์เข้า/ผู้ดูแลส่งเลขที่เลือก
        memberNo: _isStaff ? target : null,
        year: _year,
        months: _months.toList(),
        passwordType: _passwordType,
        password: _custom.text,
      ),
    );
  }

  Widget _memberCard() {
    if (!_isStaff) {
      return StepCard(
        step: 1,
        title: 'สมาชิก',
        child: Row(
          key: CashReceiptScreen.lockedMemberKey,
          children: [
            const Icon(Icons.lock_outline, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'เลขสมาชิก ${_ownMemberNo ?? '-'}  ${widget.apiService.fullName ?? ''}',
                style: screenText(weight: FontWeight.w600),
              ),
            ),
          ],
        ),
      );
    }
    final picked = _picked;
    return StepCard(
      step: 1,
      title: 'ค้นหาสมาชิก',
      subtitle: 'พิมพ์เลขสมาชิก ชื่อ หรือนามสกุล อย่างน้อย 2 ตัวอักษร',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Autocomplete<MemberHit>(
            key: CashReceiptScreen.memberFieldKey,
            displayStringForOption: (m) => m.display,
            optionsBuilder: (v) => _search(v.text),
            onSelected: (m) => _changed(() => _picked = m),
            fieldViewBuilder: (context, controller, focus, onSubmit) =>
                TextField(
                  controller: controller,
                  focusNode: focus,
                  style: screenText(),
                  onSubmitted: (_) => onSubmit(),
                  decoration: InputDecoration(
                    hintText: 'เช่น 12345 หรือ สมชาย',
                    hintStyle: screenText(color: AppTheme.textSecondary),
                    prefixIcon: const Icon(Icons.person_search),
                    isDense: true,
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
            optionsViewBuilder: (context, onSelected, options) => Align(
              alignment: Alignment.topLeft,
              child: Material(
                elevation: 4,
                borderRadius: BorderRadius.circular(10),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxHeight: 320,
                    maxWidth: 560,
                  ),
                  child: ListView(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    children: [
                      for (final m in options)
                        ListTile(
                          key: ValueKey('member-${m.memberNo}'),
                          dense: true,
                          title: Text(m.display, style: screenText(size: 14)),
                          subtitle: Text(
                            [
                              if (m.orgName.isNotEmpty) m.orgName,
                              if (!m.active) 'พ้นสภาพสมาชิก',
                            ].join(' · '),
                            style: screenText(
                              size: 12,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          onTap: () => onSelected(m),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (_searchError != null) ...[
            const SizedBox(height: 8),
            NoticeBar(type: NoticeType.error, text: _searchError!),
          ],
          const SizedBox(height: 10),
          if (picked == null)
            Text(
              'ยังไม่ได้เลือกสมาชิก',
              style: screenText(size: 13.5, color: AppTheme.textSecondary),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                StatusChip(
                  'ออกใบเสร็จให้: ${picked.display}',
                  AppTheme.successColor,
                  icon: Icons.check_circle_outline,
                ),
                if (_own)
                  StatusChip('ของตัวเอง', AppTheme.infoColor),
              ],
            ),
          if (_ownMemberNo != null && !_own) ...[
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                key: CashReceiptScreen.ownKey,
                onPressed: () => _changed(
                  () => _picked = MemberHit(
                    memberNo: _ownMemberNo!,
                    firstname: widget.apiService.fullName ?? '',
                  ),
                ),
                icon: const Icon(Icons.person, size: 18),
                label: Text('ใบเสร็จของตัวเอง', style: screenText(size: 14)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final busy = downloading != null;
    final cy = _today.year + 543;
    final months = _months.toList()..sort();
    return WorkPage(
      group: CashReceiptScreen.groupTitle,
      children: [
        ScreenHeader(
          icon: CashReceiptScreen.menuIcon,
          title: CashReceiptScreen.menuTitle,
          subtitle: 'ใบเสร็จรับเงินค่าบำรุงฌาปนกิจที่ชำระเป็นเงินสด',
          bullets: [
            _isStaff
                ? 'ผู้นำไฟล์เข้า/ผู้ดูแล ออกใบเสร็จให้สมาชิกทุกคนได้'
                : 'ออกได้เฉพาะใบเสร็จของท่านเอง',
            'เลือกปีและเดือน (หลายเดือนได้) จะได้ PDF ไฟล์เดียว',
          ],
        ),
        const SizedBox(height: 14),
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _memberCard(),
              const SizedBox(height: 12),
              StepCard(
                step: 2,
                title: 'ปีและเดือน',
                subtitle: months.isEmpty
                    ? 'ยังไม่ได้เลือกเดือน'
                    : 'เลือก ${months.length} เดือน: ${months.map(Util.thaiMonthName).join(', ')}',
                trailing: Wrap(
                  spacing: 6,
                  children: [
                    TextButton.icon(
                      key: CashReceiptScreen.selectAllKey,
                      onPressed: busy
                          ? null
                          : () => _changed(
                              () => _months
                                ..clear()
                                ..addAll(List.generate(12, (i) => i + 1)),
                            ),
                      icon: const Icon(Icons.done_all, size: 18),
                      label: Text('ทั้งปี', style: screenText(size: 14)),
                    ),
                    TextButton.icon(
                      key: CashReceiptScreen.clearKey,
                      onPressed: busy || _months.isEmpty
                          ? null
                          : () => _changed(_months.clear),
                      icon: const Icon(Icons.clear_all, size: 18),
                      label: Text('ล้าง', style: screenText(size: 14)),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Text(
                          'ปี พ.ศ.',
                          style: screenText(weight: FontWeight.w600),
                        ),
                        const SizedBox(width: 12),
                        YearStepper(
                          year: _year,
                          min: 2550,
                          max: cy,
                          enabled: !busy,
                          onChanged: (y) => _changed(() => _year = y),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    MonthPicker(
                      selected: 0,
                      selectedMonths: _months,
                      enabled: !busy,
                      onSelected: (m) => _changed(() {
                        if (!_months.remove(m)) _months.add(m);
                      }),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              StepCard(
                step: 3,
                title: 'รหัสเปิดไฟล์ PDF',
                subtitle: _own || !_isStaff
                    ? null
                    : 'ออกให้ผู้อื่น: เลือกได้เฉพาะไม่ใส่รหัส หรือกำหนดรหัสเอง',
                child: PdfPasswordPicker(
                  value: _passwordType,
                  options: _passwordOptions,
                  customController: _custom,
                  enabled: !busy,
                  onChanged: (t) => _changed(() => _passwordType = t),
                ),
              ),
              const SizedBox(height: 12),
              for (final e in [_notice, downloadError])
                if (e != null) ...[
                  NoticeBar(
                    type: e == _notice ? NoticeType.warning : NoticeType.error,
                    text: e,
                  ),
                  const SizedBox(height: 10),
                ],
              DownloadButtons(
                key: CashReceiptScreen.downloadKey,
                label: 'ดาวน์โหลดใบเสร็จเงินสด (PDF)',
                icon: Icons.picture_as_pdf_outlined,
                busy: downloading == 'cash',
                blocked: busy,
                saved: savedOf('cash'),
                canOpen: true,
                onDownload: _download,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
