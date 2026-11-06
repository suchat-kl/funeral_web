import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../config/theme.dart';
import '../../models/deposit.dart';
import '../../services/api_service.dart';
import '../../utils/dialog.dart';
import '../../utils/snackbar_helper.dart';
import '../../utils/util.dart';
import '../../widgets/screen_parts.dart';
import '../../widgets/thai_date_picker.dart';
import '../../widgets/work_parts.dart';
import 'deposit_parts.dart';

/// ฝากเงินชำระล่วงหน้า › จ่ายคืนเงินฝาก (หน้า 6 ของแบบ 13.1 แทน Frm_Payback, Frm_PayRepeat)
///
///  - จ่ายเงินล่วงหน้าคงเหลือคืน: คืนยอดคงเหลือทั้งหมด แล้วปิดบัญชี (เลือกสภาพหลังปิด)
///  - คืนกรณีเก็บซ้ำซ้อน: เลือกเดือนที่ถูกหักซ้ำ (เช่นหักผ่านเงินเดือนแล้ว) เงินคืนเข้าบัญชีฝาก
/// ยืนยันด้วยกล่องที่แสดงยอดก่อน-หลัง ส่ง version ของบัญชีที่เห็น (มีคนแก้ก่อน = ต้องโหลดใหม่)
class DepositRefundScreen extends StatefulWidget {
  final ApiService apiService;
  final DateTime? today;

  const DepositRefundScreen({super.key, required this.apiService, this.today});

  static const String menuTitle = 'จ่ายคืนเงินฝาก';
  static const IconData menuIcon = Icons.currency_exchange;

  static const Key memberKey = ValueKey('refund-member');
  static const Key findKey = ValueKey('refund-find');
  static const Key closeKey = ValueKey('refund-type-close');
  static const Key duplicateKey = ValueKey('refund-type-duplicate');
  static const Key docKey = ValueKey('refund-doc');
  static const Key reasonKey = ValueKey('refund-reason');
  static const Key submitKey = ValueKey('refund-submit');
  static Key monthKey(int period) => ValueKey('refund-month-$period');

  @override
  State<DepositRefundScreen> createState() => _DepositRefundScreenState();
}

class _DepositRefundScreenState extends State<DepositRefundScreen> {
  final _member = TextEditingController();
  final _doc = TextEditingController();
  final _reason = TextEditingController();
  final _statusText = TextEditingController();
  DepositDetail? _detail;
  List<DepositMonthItem>? _payments;
  String? _error;
  bool _busy = false;
  bool _close = true;
  int _status = 1;
  late DateTime _date;
  final Set<int> _months = {};

  ApiService get _api => widget.apiService;

  DateTime get _today {
    final t = widget.today ?? DateTime.now();
    return DateTime(t.year, t.month, t.day);
  }

  @override
  void initState() {
    super.initState();
    _date = _today;
  }

  @override
  void dispose() {
    for (final c in [_member, _doc, _reason, _statusText]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _find() async {
    final no = _member.text.trim();
    if (no.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
      _detail = null;
      _payments = null;
      _months.clear();
    });
    try {
      final d = await _api.depositDetail(no);
      final pays = d.account == null ? null : await _api.depositPayments(no);
      if (!mounted) return;
      setState(() {
        _detail = d;
        _payments = pays;
        if (d.account == null) _error = 'สมาชิกนี้ยังไม่มีบัญชีฝากล่วงหน้า';
        if (d.account?.closedPeriod != null) {
          _error =
              'บัญชีนี้ปิดแล้วเมื่อ ${DepositPeriod.label(d.account!.closedPeriod)}';
        }
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
    if (mounted) setState(() => _busy = false);
  }

  int _satang(String v) {
    final m = RegExp(r'^(-?)(\d+)(?:\.(\d{1,2}))?').firstMatch(v.trim());
    if (m == null) return 0;
    final s =
        int.parse(m.group(2)!) * 100 +
        int.parse((m.group(3) ?? '').padRight(2, '0'));
    return m.group(1) == '-' ? -s : s;
  }

  String _baht(int s) => moneyText(
    '${s < 0 ? '-' : ''}${s.abs() ~/ 100}.${(s.abs() % 100).toString().padLeft(2, '0')}',
  );

  List<DepositMonthItem> get _eligible => [
    for (final p in _payments ?? const <DepositMonthItem>[])
      if (p.reversedPeriod == null && _satang(p.amount) > 0) p,
  ];

  int get _dupTotal => _eligible
      .where((p) => p.period != null && _months.contains(p.period))
      .fold(0, (t, p) => t + _satang(p.amount));

  Future<void> _submit() async {
    final d = _detail!;
    final a = d.account!;
    final before = _satang(a.balance);
    final amount = _close ? before : _dupTotal;
    if (!_close && _months.isEmpty) {
      context.showErrorSnackBar('กรุณาเลือกเดือนที่เก็บซ้ำซ้อน');
      return;
    }
    final after = _close ? 0 : before + amount;
    final ok = await AppDialog.showConfirm(
      context,
      '${_close ? 'จ่ายเงินล่วงหน้าคงเหลือคืน และปิดบัญชี' : 'คืนเงินกรณีเก็บซ้ำซ้อน ${_months.length} เดือน เข้าบัญชีฝาก'}\n'
      'เลขสมาชิก ${d.member.memberNo} ${d.member.fullName}\n'
      'จำนวนเงิน ${_baht(amount)} บาท\n'
      'ยอดเงินฝาก ${_baht(before)} → ${_baht(after)} บาท'
      '${_close ? '\nสภาพหลังปิด: ${DepositStatus.nameOf(_status)}' : ''}',
      confirmText: _close ? 'จ่ายคืนและปิดบัญชี' : 'คืนเงิน',
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    try {
      final r = await _api.depositRefund(
        d.member.memberNo,
        type: _close ? 'CLOSE' : 'DUPLICATE',
        version: a.version,
        docNo: _doc.text.trim().isEmpty ? null : _doc.text.trim(),
        reason: _reason.text.trim().isEmpty ? null : _reason.text.trim(),
        date: _date,
        status: _close ? _status : null,
        statusText: _close && _statusText.text.trim().isNotEmpty
            ? _statusText.text.trim()
            : null,
        periods: _close ? null : _months.toList(),
      );
      if (!mounted) return;
      context.showSuccessSnackBar(
        'บันทึกการจ่ายคืน ${moneyText(r.amount)} บาทแล้ว ยอดคงเหลือ ${moneyText(r.balance)} บาท',
      );
      _doc.clear();
      _reason.clear();
      await _find();
    } catch (e) {
      if (mounted) context.showErrorSnackBar(e.toString());
    }
    if (mounted) setState(() => _busy = false);
  }

  Widget _form(DepositDetail d) {
    final a = d.account!;
    final eligible = _eligible;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              '${d.member.memberNo}  ${d.member.fullName}',
              style: screenText(size: 17, weight: FontWeight.w700),
            ),
            TotalChip('ยอดเงินฝาก', '${moneyText(a.balance)} บาท'),
            TotalChip(
              'หนี้ค้าง',
              '${moneyText(a.debt)} บาท',
              color: _satang(a.debt) > 0 ? AppTheme.dangerColor : null,
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          children: [
            ChoiceChip(
              key: DepositRefundScreen.closeKey,
              label: Text(
                'จ่ายเงินคงเหลือคืน (ปิดบัญชี)',
                style: screenText(size: 14),
              ),
              selected: _close,
              onSelected: (_) => setState(() => _close = true),
            ),
            ChoiceChip(
              key: DepositRefundScreen.duplicateKey,
              label: Text('คืนกรณีเก็บซ้ำซ้อน', style: screenText(size: 14)),
              selected: !_close,
              onSelected: (_) => setState(() => _close = false),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_close) ...[
          if (_satang(a.debt) > 0)
            const NoticeBar(
              type: NoticeType.warning,
              text:
                  'บัญชีนี้มีหนี้ค้าง ถ้ายอดเงินพอปลดหนี้ ระบบจะให้ปลดหนี้ก่อน หนี้ที่เหลือยังบันทึกไว้หลังปิดบัญชี',
            ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 10,
            children: [
              SizedBox(
                width: 240,
                child: DropdownButtonFormField<int>(
                  initialValue: _status,
                  decoration: depositInput('สภาพหลังปิดบัญชี'),
                  items: [
                    for (var i = 1; i < DepositStatus.names.length; i++)
                      DropdownMenuItem(
                        value: i,
                        child: Text(
                          DepositStatus.names[i],
                          style: screenText(size: 14),
                        ),
                      ),
                  ],
                  onChanged: (v) => setState(() => _status = v ?? 1),
                ),
              ),
              SizedBox(
                width: 260,
                child: TextField(
                  controller: _statusText,
                  maxLength: 50,
                  style: screenText(size: 14),
                  decoration: depositInput(
                    'ข้อความในรายงาน (ไม่ใส่ = ชื่อสภาพ)',
                    hint: 'เช่น ศพ 18099',
                  ),
                ),
              ),
            ],
          ),
        ] else ...[
          Text(
            'เลือกเดือนที่ถูกหักซ้ำซ้อน (${eligible.length} เดือนที่คืนได้)',
            style: screenText(size: 14, weight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 280),
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final p in eligible)
                  CheckboxListTile(
                    key: DepositRefundScreen.monthKey(p.period ?? 0),
                    dense: true,
                    controlAffinity: ListTileControlAffinity.leading,
                    value: _months.contains(p.period),
                    onChanged: (v) => setState(() {
                      if (v == true) {
                        _months.add(p.period!);
                      } else {
                        _months.remove(p.period);
                      }
                    }),
                    title: Text(
                      '${DepositPeriod.label(p.period)}  ศพที่ ${p.bodies}  ${moneyText(p.amount)} บาท',
                      style: screenText(size: 14),
                    ),
                  ),
              ],
            ),
          ),
          TotalChip(
            'รวมเงินคืน',
            '${_baht(_dupTotal)} บาท',
            color: AppTheme.successColor,
          ),
        ],
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            OutlinedButton.icon(
              onPressed: () async {
                final v = await showThaiDatePicker(
                  context,
                  _date,
                  lastDate: _today,
                  today: _today,
                );
                if (v != null && mounted) setState(() => _date = v);
              },
              icon: const Icon(Icons.calendar_month, size: 16),
              label: Text(
                'วันที่ ${Util.formatThaiDate(_date)}',
                style: screenText(size: 14),
              ),
            ),
            SizedBox(
              width: 180,
              child: TextField(
                key: DepositRefundScreen.docKey,
                controller: _doc,
                maxLength: 20,
                style: screenText(size: 14),
                decoration: depositInput('เลขที่เอกสาร'),
              ),
            ),
            SizedBox(
              width: 360,
              child: TextField(
                key: DepositRefundScreen.reasonKey,
                controller: _reason,
                maxLength: 200,
                style: screenText(size: 14),
                decoration: depositInput('เหตุผล'),
              ),
            ),
          ],
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            key: DepositRefundScreen.submitKey,
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.cancelColor,
            ),
            onPressed: _busy ? null : _submit,
            icon: const Icon(Icons.payments_outlined),
            label: Text(
              _close ? 'จ่ายคืนและปิดบัญชี' : 'คืนเงินเข้าบัญชีฝาก',
              style: screenText(size: 14, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final d = _detail;
    final usable =
        d != null && d.account != null && d.account!.closedPeriod == null;
    return WorkPage(
      group: depositGroup,
      maxWidth: 1100,
      children: [
        const ScreenHeader(
          icon: DepositRefundScreen.menuIcon,
          title: DepositRefundScreen.menuTitle,
          subtitle:
              'จ่ายเงินล่วงหน้าคงเหลือคืน (ปิดบัญชี) หรือคืนเงินกรณีเก็บซ้ำซ้อน',
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            SizedBox(
              width: 220,
              child: TextField(
                key: DepositRefundScreen.memberKey,
                controller: _member,
                onSubmitted: (_) => _find(),
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: screenText(size: 14),
                decoration: depositInput('เลขสมาชิก'),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              key: DepositRefundScreen.findKey,
              onPressed: _busy ? null : _find,
              icon: const Icon(Icons.search),
              label: Text(
                'ค้นหา',
                style: screenText(size: 14, color: Colors.white),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_error != null) NoticeBar(type: NoticeType.error, text: _error!),
        if (usable) _form(d),
      ],
    );
  }
}
