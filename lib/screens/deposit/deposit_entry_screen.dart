import 'dart:async';

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

/// ฝากเงินชำระล่วงหน้า › บันทึกเงินฝาก (หน้า 3 ของแบบ 13.1 แทน Frm_Deposit)
///
/// ตารางหลายคนต่อครั้ง: เลขสมาชิก (แสดงชื่อ ยอด หนี้) วันที่ (ปฏิทิน พ.ศ.) จำนวนเงิน เลขที่เอกสาร (กรอกเอง — มาจากระบบอื่น)
/// "บันทึก" ส่งทั้งชุดครั้งเดียว: ทั้งชุดสำเร็จหรือไม่บันทึกเลย ระบบปลดหนี้ค้างให้อัตโนมัติเมื่อเงินพอ
/// แสดงผลรายแถว (ปลดหนี้กี่เดือน คงเหลือเท่าไร) ถามก่อนออกเมื่อยังไม่บันทึก
class DepositEntryScreen extends StatefulWidget {
  final ApiService apiService;

  /// วันนี้ (เทสต์ส่งวันตายตัว)
  final DateTime? today;

  const DepositEntryScreen({super.key, required this.apiService, this.today});

  static const String menuTitle = 'บันทึกเงินฝาก';
  static const IconData menuIcon = Icons.add_card;

  static const Key addRowKey = ValueKey('entry-add-row');
  static const Key saveKey = ValueKey('entry-save');
  static const Key totalKey = ValueKey('entry-total');
  static Key memberKey(int i) => ValueKey('entry-member-$i');
  static Key amountKey(int i) => ValueKey('entry-amount-$i');
  static Key docKey(int i) => ValueKey('entry-doc-$i');
  static Key dateKey(int i) => ValueKey('entry-date-$i');
  static Key removeKey(int i) => ValueKey('entry-remove-$i');
  static Key infoKey(int i) => ValueKey('entry-info-$i');

  @override
  State<DepositEntryScreen> createState() => _DepositEntryScreenState();
}

class _Row {
  final member = TextEditingController();
  final amount = TextEditingController();
  final doc = TextEditingController();
  DateTime date;
  Timer? debounce;
  DepositDetail? info;
  String? infoError;
  bool looking = false;

  _Row(this.date);

  void dispose() {
    debounce?.cancel();
    member.dispose();
    amount.dispose();
    doc.dispose();
  }

  bool get blank =>
      member.text.trim().isEmpty &&
      amount.text.trim().isEmpty &&
      doc.text.trim().isEmpty;
}

/// จำนวนเงินเป็นสตางค์ (ไม่ผ่าน double) อ่านไม่ได้ = null
int? satangOf(String text) {
  final m = RegExp(
    r'^(\d{1,7})(?:\.(\d{1,2}))?$',
  ).firstMatch(text.trim().replaceAll(',', ''));
  if (m == null) return null;
  return int.parse(m.group(1)!) * 100 +
      int.parse((m.group(2) ?? '').padRight(2, '0'));
}

String satangText(int s) =>
    moneyText('${s ~/ 100}.${(s % 100).toString().padLeft(2, '0')}');

class _DepositEntryScreenState extends State<DepositEntryScreen> {
  final List<_Row> _rows = [];
  List<DepositSaveResult>? _results;
  bool _saving = false;

  DateTime get _today {
    final t = widget.today ?? DateTime.now();
    return DateTime(t.year, t.month, t.day);
  }

  @override
  void initState() {
    super.initState();
    _addRow();
  }

  @override
  void dispose() {
    for (final r in _rows) {
      r.dispose();
    }
    super.dispose();
  }

  bool get _dirty => _rows.any((r) => !r.blank);

  void _addRow() =>
      setState(() => _rows.add(_Row(_rows.isEmpty ? _today : _rows.last.date)));

  void _remove(int i) => setState(() {
    _rows.removeAt(i).dispose();
    if (_rows.isEmpty) _rows.add(_Row(_today));
  });

  void _lookup(_Row r) {
    r.debounce?.cancel();
    final no = r.member.text.trim();
    setState(() {
      r.info = null;
      r.infoError = null;
    });
    if (no.isEmpty) return;
    r.debounce = Timer(const Duration(milliseconds: 400), () async {
      setState(() => r.looking = true);
      try {
        final d = await widget.apiService.depositDetail(no);
        if (!mounted || r.member.text.trim() != no) return;
        setState(() {
          r.info = d;
          r.infoError = d.account == null
              ? 'ยังไม่มีบัญชีฝากล่วงหน้า'
              : d.account!.closedPeriod != null
              ? 'บัญชีปิดแล้ว'
              : null;
        });
      } catch (e) {
        if (mounted && r.member.text.trim() == no) {
          setState(() => r.infoError = 'ไม่พบเลขสมาชิกนี้');
        }
      }
      if (mounted) setState(() => r.looking = false);
    });
  }

  int get _total => _rows.fold(0, (t, r) => t + (satangOf(r.amount.text) ?? 0));

  List<_Row> get _filled => _rows.where((r) => !r.blank).toList();

  /// ข้อความผิดของหน้าจอ (null = ส่งได้) — backend ตรวจซ้ำทุกแถว
  String? _problem() {
    final rows = _filled;
    if (rows.isEmpty) return 'ยังไม่มีรายการ';
    for (var i = 0; i < _rows.length; i++) {
      final r = _rows[i];
      if (r.blank) continue;
      final at = 'แถวที่ ${i + 1}: ';
      if (r.member.text.trim().isEmpty) return '$atกรุณากรอกเลขสมาชิก';
      if (r.infoError != null) return '$at${r.infoError}';
      final s = satangOf(r.amount.text);
      if (s == null || s <= 0) return '$atจำนวนเงินไม่ถูกต้อง';
      if (r.date.isAfter(_today)) return '$atวันที่ต้องไม่เกินวันนี้';
    }
    return null;
  }

  Future<void> _save() async {
    final problem = _problem();
    if (problem != null) {
      context.showErrorSnackBar(problem);
      return;
    }
    final rows = _filled;
    final ok = await AppDialog.showConfirm(
      context,
      'บันทึกเงินฝาก ${rows.length} รายการ รวม ${satangText(_total)} บาท?\n'
      'ระบบจะปลดหนี้ค้างให้อัตโนมัติเมื่อยอดเงินพอ',
      confirmText: 'บันทึก',
    );
    if (ok != true || !mounted) return;
    setState(() => _saving = true);
    try {
      final res = await widget.apiService.depositSave([
        for (final r in rows)
          (
            memberNo: r.member.text.trim(),
            date: r.date,
            amount: r.amount.text.trim().replaceAll(',', ''),
            docNo: r.doc.text.trim().isEmpty ? null : r.doc.text.trim(),
          ),
      ]);
      if (!mounted) return;
      setState(() {
        _results = res;
        for (final r in _rows) {
          r.dispose();
        }
        _rows
          ..clear()
          ..add(_Row(_today));
      });
      context.showSuccessSnackBar(
        'บันทึกเงินฝาก ${res.length} รายการเรียบร้อย',
      );
    } catch (e) {
      if (mounted) context.showErrorSnackBar(e.toString());
    }
    if (mounted) setState(() => _saving = false);
  }

  Future<void> _pickDate(_Row r) async {
    final d = await showThaiDatePicker(
      context,
      r.date,
      lastDate: _today,
      today: _today,
      helpText: 'วันที่รับเงินฝาก',
    );
    if (d != null && mounted) setState(() => r.date = d);
  }

  Widget _info(int i, _Row r) {
    if (r.looking) {
      return const SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    if (r.infoError != null) {
      return Text(
        r.infoError!,
        key: DepositEntryScreen.infoKey(i),
        style: screenText(size: 13, color: AppTheme.dangerColor),
      );
    }
    final d = r.info;
    if (d == null) return const SizedBox.shrink();
    final a = d.account!;
    return Column(
      key: DepositEntryScreen.infoKey(i),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          d.member.fullName,
          style: screenText(size: 13.5, weight: FontWeight.w600),
        ),
        Text(
          'เงินฝาก ${moneyText(a.balance)} · หนี้ ${moneyText(a.debt)}',
          style: screenText(
            size: 12.5,
            color: (double.tryParse(a.debt) ?? 0) > 0
                ? AppTheme.dangerColor
                : AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _editRow(int i) {
    final r = _rows[i];
    final edited = !r.blank;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 36,
          child: edited
              ? const Icon(Icons.edit, size: 16, color: AppTheme.warningColor)
              : Text('${i + 1}', style: screenText(size: 13.5)),
        ),
        Expanded(
          flex: 2,
          child: TextField(
            key: DepositEntryScreen.memberKey(i),
            controller: r.member,
            onChanged: (_) => _lookup(r),
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: screenText(size: 14),
            decoration: depositInput('เลขสมาชิก'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(flex: 4, child: _info(i, r)),
        const SizedBox(width: 8),
        Expanded(
          flex: 3,
          child: OutlinedButton.icon(
            key: DepositEntryScreen.dateKey(i),
            onPressed: () => _pickDate(r),
            icon: const Icon(Icons.calendar_month, size: 16),
            label: Text(
              Util.formatThaiDate(r.date),
              style: screenText(size: 13.5),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 2,
          child: TextField(
            key: DepositEntryScreen.amountKey(i),
            controller: r.amount,
            onChanged: (_) => setState(() {}),
            textAlign: TextAlign.right,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
            ],
            style: screenText(size: 14),
            decoration: depositInput('จำนวนเงิน'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 2,
          child: TextField(
            key: DepositEntryScreen.docKey(i),
            controller: r.doc,
            onChanged: (_) => setState(() {}),
            maxLength: 20,
            buildCounter:
                (_, {required currentLength, required isFocused, maxLength}) =>
                    null,
            style: screenText(size: 14),
            decoration: depositInput('เลขที่เอกสาร'),
          ),
        ),
        IconButton(
          key: DepositEntryScreen.removeKey(i),
          tooltip: 'ลบแถว',
          onPressed: _saving ? null : () => _remove(i),
          icon: const Icon(Icons.close, color: AppTheme.deleteColor),
        ),
      ],
    );
  }

  Widget _resultTable(List<DepositSaveResult> res) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        'ผลการบันทึกครั้งล่าสุด',
        style: screenText(size: 16, weight: FontWeight.w700),
      ),
      const SizedBox(height: 8),
      PagedSheet<DepositSaveResult>(
        minWidth: 1000,
        items: res,
        columns: const [
          SheetColumn('ลำดับ', flex: 1),
          SheetColumn('เลขสมาชิก', flex: 2),
          SheetColumn('ชื่อ - สกุล', flex: 4),
          SheetColumn('เงินฝาก', flex: 2, right: true),
          SheetColumn('ปลดหนี้', flex: 4),
          SheetColumn('คงเหลือ', flex: 2, right: true),
          SheetColumn('หนี้ค้าง', flex: 2, right: true),
        ],
        cells: (r, no) => [
          cellText('$no'),
          cellText(r.memberNo),
          cellText(r.name, size: 13.5),
          cellMoney(r.amount),
          cellText(
            r.clearedPeriods.isEmpty
                ? '-'
                : '${r.clearedPeriods.length} เดือน (${moneyText(r.clearedAmount)} บาท): '
                      '${r.clearedPeriods.map(DepositPeriod.legacy).join(', ')}',
            size: 13,
            color: r.clearedPeriods.isEmpty ? null : AppTheme.successColor,
          ),
          cellMoney(r.balance),
          cellMoney(r.debt),
        ],
      ),
    ],
  );

  Future<void> _confirmLeave() async {
    final ok = await AppDialog.showConfirm(
      context,
      'ยังไม่ได้บันทึกรายการเงินฝาก ออกจากหน้านี้หรือไม่?',
      confirmText: 'ออกโดยไม่บันทึก',
    );
    if (ok == true && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final filled = _filled.length;
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmLeave();
      },
      child: WorkPage(
        group: depositGroup,
        maxWidth: 1300,
        children: [
          const ScreenHeader(
            icon: DepositEntryScreen.menuIcon,
            title: DepositEntryScreen.menuTitle,
            subtitle:
                'บันทึกเงินฝากล่วงหน้าได้หลายคนในครั้งเดียว แล้วกด "บันทึก" ทีเดียว',
            bullets: [
              'เลขที่เอกสารมาจากระบบอื่น ให้กรอกตามเอกสาร',
              'ระบบปลดหนี้ค้างให้อัตโนมัติ เดือนเก่าก่อน เมื่อยอดเงินพอทั้งเดือน',
              'ถ้ามีแถวใดบันทึกไม่ได้ จะไม่บันทึกทั้งชุด ให้แก้แถวนั้นแล้วกดบันทึกใหม่',
            ],
          ),
          const SizedBox(height: 14),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.dividerColor),
            ),
            padding: const EdgeInsets.all(8),
            child: Column(
              children: [
                for (var i = 0; i < _rows.length; i++) ...[
                  if (i > 0) const SizedBox(height: 8),
                  _editRow(i),
                ],
              ],
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              OutlinedButton.icon(
                key: DepositEntryScreen.addRowKey,
                onPressed: _saving ? null : _addRow,
                icon: const Icon(Icons.add, color: AppTheme.addColor),
                label: Text('เพิ่มแถว', style: screenText(size: 14)),
              ),
              KeyedSubtree(
                key: DepositEntryScreen.totalKey,
                child: TotalChip(
                  'รวม $filled รายการ',
                  '${satangText(_total)} บาท',
                  color: AppTheme.successColor,
                ),
              ),
              FilledButton.icon(
                key: DepositEntryScreen.saveKey,
                onPressed: _saving || filled == 0 ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save),
                label: Text(
                  'บันทึก',
                  style: screenText(size: 14, color: Colors.white),
                ),
              ),
            ],
          ),
          if (_results != null) ...[
            const SizedBox(height: 18),
            _resultTable(_results!),
          ],
        ],
      ),
    );
  }
}
