import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../config/theme.dart';
import '../../models/deposit.dart';
import '../../services/api_service.dart';
import '../../utils/dialog.dart';
import '../../utils/snackbar_helper.dart';
import '../../utils/util.dart';
import '../../widgets/screen_parts.dart';
import '../../widgets/work_parts.dart';
import 'deposit_parts.dart';

/// ข้อมูลสมาชิก › รายละเอียดสมาชิก (หน้า 2 ของแบบ 13.1) หน้าเดียวหลายแท็บ
///
/// หัว: ชื่อ-สกุล (ทะเบียนสมาชิก) เลขสมาชิก สังกัด สภาพสมาชิก บันทึกช่วยจำ
/// แท็บ: บัญชีฝาก · สมาชิกพิเศษ · ประวัติชำระ · ประวัติค้างชำระ · ประวัติฝาก · ทะเบียนรายตัว
/// หน้านี้ไม่แก้ยอดเงิน — ยอดเปลี่ยนได้เฉพาะจากเมนูบันทึกเงินฝาก / ประมวลผล / จ่ายคืน
class DepositMemberScreen extends StatefulWidget {
  final ApiService apiService;
  final String memberNo;

  const DepositMemberScreen({
    super.key,
    required this.apiService,
    required this.memberNo,
  });

  static const Key memoKey = ValueKey('deposit-memo');
  static const Key saveMemoKey = ValueKey('deposit-save-memo');
  static const Key remarkKey = ValueKey('deposit-remark');
  static const Key statusKey = ValueKey('deposit-status');
  static const Key dunningKey = ValueKey('deposit-dunning');
  static const Key saveAccountKey = ValueKey('deposit-save-account');
  static const Key specialAmountKey = ValueKey('deposit-special-amount');
  static const Key specialRefKey = ValueKey('deposit-special-ref');
  static const Key saveSpecialKey = ValueKey('deposit-save-special');
  static Key tabKey(int i) => ValueKey('deposit-detail-tab-$i');

  static const List<String> tabs = [
    'บัญชีฝาก',
    'สมาชิกพิเศษ',
    'ประวัติชำระ',
    'ประวัติค้างชำระ',
    'ประวัติฝาก',
    'ทะเบียนรายตัว',
  ];

  @override
  State<DepositMemberScreen> createState() => _DepositMemberScreenState();
}

class _DepositMemberScreenState extends State<DepositMemberScreen> {
  DepositDetail? _detail;
  String? _error;
  bool _loading = true;
  bool _saving = false;
  int _tab = 0;

  final _memo = TextEditingController();
  final _remark = TextEditingController();
  final _statusText = TextEditingController();
  final _specialAmount = TextEditingController();
  final _specialRef = TextEditingController();
  int _status = 0;
  bool _dunning = false;

  // ประวัติโหลดเมื่อเปิดแท็บครั้งแรก
  List<DepositMonthItem>? _payments;
  List<DepositMonthItem>? _debts;
  List<DepositReceiptItem>? _receipts;
  List<LedgerItem>? _ledger;
  String? _historyError;

  ApiService get _api => widget.apiService;
  String get _no => widget.memberNo;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in [
      _memo,
      _remark,
      _statusText,
      _specialAmount,
      _specialRef,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final d = await _api.depositDetail(_no);
      if (!mounted) return;
      setState(() {
        _detail = d;
        _loading = false;
        _memo.text = d.memo ?? '';
        final a = d.account;
        _remark.text = a?.remark ?? '';
        _statusText.text = a?.statusText ?? '';
        _status = a?.status ?? 0;
        _dunning = a?.dunning ?? false;
        _specialAmount.text = d.special?.amount ?? '500';
        _specialRef.text = d.special?.approvalRef ?? '';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _loadTab(int i) async {
    setState(() {
      _tab = i;
      _historyError = null;
    });
    try {
      switch (i) {
        case 2:
          _payments ??= await _api.depositPayments(_no);
        case 3:
          _debts ??= await _api.depositDebts(_no);
        case 4:
          _receipts ??= await _api.depositReceipts(_no);
        case 5:
          _ledger ??= await _api.depositLedger(_no);
      }
    } catch (e) {
      _historyError = e.toString();
    }
    if (mounted) setState(() {});
  }

  Future<void> _guard(Future<void> Function() work, String done) async {
    setState(() => _saving = true);
    try {
      await work();
      if (mounted) context.showSuccessSnackBar(done);
      await _load();
    } catch (e) {
      if (mounted) context.showErrorSnackBar(e.toString());
    }
    if (mounted) setState(() => _saving = false);
  }

  Future<void> _saveMemo() => _guard(
    () => _api.depositUpdateMember(
      _no,
      memo: _memo.text,
      divCode: _detail?.member.divCode,
      status: _detail?.member.status,
    ),
    'บันทึกบันทึกช่วยจำแล้ว',
  );

  Future<void> _saveAccount() async {
    final a = _detail?.account;
    if (a == null) return;
    if (_status == DepositStatus.removed && a.status != DepositStatus.removed) {
      final ok = await AppDialog.showConfirm(
        context,
        'นำเลขสมาชิก $_no ออกจากสมาชิก?\n'
        'บัญชีจะหยุดหักค่าฌาปนกิจรายเดือน หนี้ค้าง ${moneyText(a.debt)} บาท และประวัติทั้งหมดยังเก็บไว้',
        confirmText: 'นำออกจากสมาชิก',
      );
      if (ok != true || !mounted) return;
    }
    await _guard(
      () => _api.depositUpdateAccount(
        _no,
        remark: _remark.text,
        status: _status,
        statusText: _status == 0 && !_dunning ? '.' : _statusText.text,
        dunning: _status == 0 && _dunning,
        version: a.version,
      ),
      'บันทึกบัญชีแล้ว',
    );
  }

  Future<void> _saveSpecial() => _guard(
    () => _api.depositSaveSpecial(
      _no,
      amount: _specialAmount.text,
      approvalRef: _specialRef.text,
    ),
    'บันทึกสมาชิกพิเศษแล้ว',
  );

  Future<void> _openAccount() =>
      _guard(() => _api.depositOpenAccount(_no), 'เปิดบัญชีฝากล่วงหน้าแล้ว');

  // ---------------- ส่วนแสดงผล ----------------

  Widget _header(DepositDetail d) {
    final m = d.member;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppTheme.dividerColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 10,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  m.fullName.isEmpty ? '(ไม่มีชื่อ)' : m.fullName,
                  style: screenText(size: 20, weight: FontWeight.w700),
                ),
                StatusChip('เลขสมาชิก ${m.memberNo}', AppTheme.primaryColor),
                StatusChip(
                  'สภาพสมาชิก: ${DepositStatus.nameOf(m.status)}',
                  m.status == null || m.status == 0
                      ? AppTheme.successColor
                      : AppTheme.dangerColor,
                ),
                if (!m.registered)
                  const StatusChip(
                    'ไม่มีในทะเบียนของระบบเดิม',
                    AppTheme.neutralColor,
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'สังกัด: ${m.divName ?? m.divCode ?? '-'}',
              style: screenText(size: 14, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    key: DepositMemberScreen.memoKey,
                    controller: _memo,
                    maxLines: 2,
                    maxLength: 500,
                    style: screenText(size: 14),
                    decoration: depositInput('บันทึกช่วยจำ'),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  key: DepositMemberScreen.saveMemoKey,
                  onPressed: _saving || !m.registered ? null : _saveMemo,
                  child: Text(
                    'บันทึก',
                    style: screenText(size: 14, color: Colors.white),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _accountTab(DepositDetail d) {
    final a = d.account;
    if (a == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const NoticeBar(
            type: NoticeType.info,
            text: 'สมาชิกนี้ยังไม่มีบัญชีฝากล่วงหน้า',
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: _saving ? null : _openAccount,
            icon: const Icon(Icons.add_card),
            label: Text(
              'เปิดบัญชีฝากล่วงหน้า',
              style: screenText(size: 14, color: Colors.white),
            ),
          ),
        ],
      );
    }
    final active = _status == 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 8,
          children: [
            TotalChip('ยอดเงินฝาก', '${moneyText(a.balance)} บาท'),
            TotalChip(
              'หนี้ค้างชำระ',
              '${moneyText(a.debt)} บาท',
              color: (double.tryParse(a.debt) ?? 0) > 0
                  ? AppTheme.dangerColor
                  : null,
            ),
            if (a.closedPeriod != null)
              TotalChip(
                'ปิดบัญชีเมื่อ',
                DepositPeriod.label(a.closedPeriod),
                color: AppTheme.neutralColor,
              ),
            if (a.dunning)
              TotalChip(
                'ทวงถามตั้งแต่',
                a.dunningSince == null
                    ? 'ไม่ทราบ'
                    : Util.thaiDateOf(a.dunningSince),
                color: AppTheme.warningColor,
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'ยอดเงินเปลี่ยนได้จากเมนูบันทึกเงินฝาก ประมวลผลหักเงิน และจ่ายคืนเท่านั้น',
          style: screenText(size: 12.5, color: AppTheme.textSecondary),
        ),
        const SizedBox(height: 14),
        TextField(
          key: DepositMemberScreen.remarkKey,
          controller: _remark,
          maxLength: 128,
          style: screenText(size: 14),
          decoration: depositInput('หมายเหตุ'),
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 12,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 260,
              child: DropdownButtonFormField<int>(
                key: DepositMemberScreen.statusKey,
                initialValue: _status,
                decoration: depositInput('สภาพบัญชี'),
                items: [
                  for (var i = 0; i < DepositStatus.names.length; i++)
                    DropdownMenuItem(
                      value: i,
                      child: Text(
                        i == 0 ? 'ปกติ (หักรายเดือน)' : DepositStatus.names[i],
                        style: screenText(size: 14),
                      ),
                    ),
                ],
                onChanged: (v) => setState(() => _status = v ?? 0),
              ),
            ),
            if (active)
              FilterChip(
                key: DepositMemberScreen.dunningKey,
                label: Text(
                  'ระหว่างทวงถามหนี้ (ยังคิดหนี้รายเดือนต่อ)',
                  style: screenText(size: 14),
                ),
                selected: _dunning,
                onSelected: (v) => setState(() {
                  _dunning = v;
                  if (v && _statusText.text.trim().isEmpty) {
                    _statusText.text = '.ตัดออก';
                  }
                }),
              ),
            if (!active || _dunning)
              SizedBox(
                width: 260,
                child: TextField(
                  controller: _statusText,
                  maxLength: 50,
                  style: screenText(size: 14),
                  decoration: depositInput(
                    'ข้อความในรายงาน (ช่องพ้นสภาพ)',
                    hint: 'เช่น ศพ 18099',
                  ),
                ),
              ),
          ],
        ),
        if (_status == DepositStatus.removed) ...[
          const SizedBox(height: 8),
          const NoticeBar(
            type: NoticeType.warning,
            text:
                'นำออกจากสมาชิก: หยุดหักรายเดือน ข้อมูลและประวัติยังอยู่ ค้นได้ที่แท็บฝากล่วงหน้า สถานะ "นำออกจากสมาชิกแล้ว"',
          ),
        ],
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            key: DepositMemberScreen.saveAccountKey,
            onPressed: _saving ? null : _saveAccount,
            icon: const Icon(Icons.save),
            label: Text(
              'บันทึกบัญชี',
              style: screenText(size: 14, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  Widget _specialTab(DepositDetail d) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      NoticeBar(
        type: NoticeType.info,
        text: d.special == null
            ? 'ยังไม่เป็นสมาชิกพิเศษ — สมาชิกพิเศษคือผู้สมัครหลังบรรจุเกิน 3 ปี จ่ายเงินเพิ่มครั้งเดียวตามหนังสืออนุมัติ'
            : 'เป็นสมาชิกพิเศษ จ่ายเงินเพิ่ม ${moneyText(d.special!.amount)} บาท',
      ),
      const SizedBox(height: 12),
      Wrap(
        spacing: 12,
        runSpacing: 10,
        children: [
          SizedBox(
            width: 200,
            child: TextField(
              key: DepositMemberScreen.specialAmountKey,
              controller: _specialAmount,
              textAlign: TextAlign.right,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
              style: screenText(size: 14),
              decoration: depositInput('จำนวนเงิน (บาท)'),
            ),
          ),
          SizedBox(
            width: 420,
            child: TextField(
              key: DepositMemberScreen.specialRefKey,
              controller: _specialRef,
              maxLength: 128,
              style: screenText(size: 14),
              decoration: depositInput('หนังสืออนุมัติ / หมายเหตุ'),
            ),
          ),
        ],
      ),
      Align(
        alignment: Alignment.centerLeft,
        child: FilledButton.icon(
          key: DepositMemberScreen.saveSpecialKey,
          onPressed: _saving ? null : _saveSpecial,
          icon: const Icon(Icons.save),
          label: Text(
            d.special == null ? 'บันทึกเป็นสมาชิกพิเศษ' : 'บันทึกการแก้ไข',
            style: screenText(size: 14, color: Colors.white),
          ),
        ),
      ),
    ],
  );

  Widget _monthTab(List<DepositMonthItem>? items, {required bool debt}) {
    if (items == null) return const LoadState(loading: true);
    return PagedSheet<DepositMonthItem>(
      minWidth: 820,
      unit: 'เดือน',
      items: items,
      columns: [
        const SheetColumn('ลำดับ', flex: 1),
        const SheetColumn('เดือน', flex: 3),
        const SheetColumn('ศพที่', flex: 3),
        const SheetColumn('จำนวนเงิน', flex: 2, right: true),
        SheetColumn(debt ? 'สถานะ' : 'เดือนที่จ่าย', flex: 3),
        const SheetColumn('หมายเหตุ', flex: 4),
      ],
      cells: (m, no) => [
        cellText('$no'),
        cellText(DepositPeriod.label(m.period)),
        cellText(m.bodies),
        cellMoney(m.amount),
        debt
            ? StatusChip(
                m.cleared ? 'ปลดหนี้แล้ว' : 'ค้างชำระ',
                m.cleared ? AppTheme.successColor : AppTheme.dangerColor,
              )
            : cellText(
                m.paidPeriod == null || m.paidPeriod == m.period
                    ? '-'
                    : DepositPeriod.label(m.paidPeriod),
              ),
        cellText(m.remark, size: 13),
      ],
    );
  }

  static String _dateOf(String? iso, String? legacy) =>
      iso == null ? (legacy ?? '-') : Util.thaiDateOf(iso);

  Widget _receiptTab() {
    final items = _receipts;
    if (items == null) return const LoadState(loading: true);
    return PagedSheet<DepositReceiptItem>(
      minWidth: 700,
      items: items,
      columns: const [
        SheetColumn('ลำดับ', flex: 1),
        SheetColumn('วันที่', flex: 3),
        SheetColumn('เลขที่เอกสาร', flex: 3),
        SheetColumn('จำนวนเงิน', flex: 2, right: true),
      ],
      cells: (r, no) => [
        cellText('$no'),
        cellText(_dateOf(r.date, r.legacyDate)),
        cellText(r.docNo),
        cellMoney(r.amount),
      ],
    );
  }

  Widget _ledgerTab() {
    final items = _ledger;
    if (items == null) return const LoadState(loading: true);
    return PagedSheet<LedgerItem>(
      minWidth: 1000,
      items: items,
      initialPageSize: 20,
      columns: const [
        SheetColumn('ลำดับ', flex: 1),
        SheetColumn('วันที่', flex: 3),
        SheetColumn('รายการ', flex: 5),
        SheetColumn('เลขที่เอกสาร', flex: 2),
        SheetColumn('รับ', flex: 2, right: true),
        SheetColumn('จ่ายศพที่', flex: 3),
        SheetColumn('จ่าย', flex: 2, right: true),
        SheetColumn('คงเหลือ', flex: 2, right: true),
      ],
      cells: (l, no) => [
        cellText('$no'),
        cellText(_dateOf(l.date, l.legacyDate), size: 13),
        cellText(l.text, size: 13),
        cellText(l.docNo, size: 13),
        cellMoney(l.received),
        cellText(l.bodyPay, size: 13),
        cellMoney(l.paid),
        cellMoney(l.balance),
      ],
    );
  }

  Widget _tabBody(DepositDetail d) {
    if (_historyError != null && _tab >= 2) {
      return LoadState(error: _historyError, onRetry: () => _loadTab(_tab));
    }
    return switch (_tab) {
      0 => _accountTab(d),
      1 => _specialTab(d),
      2 => _monthTab(_payments, debt: false),
      3 => _monthTab(_debts, debt: true),
      4 => _receiptTab(),
      _ => _ledgerTab(),
    };
  }

  @override
  Widget build(BuildContext context) {
    final d = _detail;
    return WorkPage(
      group: depositMemberGroup,
      maxWidth: 1240,
      children: [
        if (_loading && d == null) const LoadState(loading: true),
        if (_error != null) LoadState(error: _error, onRetry: _load),
        if (d != null) ...[
          _header(d),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < DepositMemberScreen.tabs.length; i++)
                ChoiceChip(
                  key: DepositMemberScreen.tabKey(i),
                  label: Text(
                    DepositMemberScreen.tabs[i],
                    style: screenText(size: 14),
                  ),
                  selected: _tab == i,
                  onSelected: (_) => _loadTab(i),
                ),
            ],
          ),
          const SizedBox(height: 14),
          _tabBody(d),
        ],
      ],
    );
  }
}
