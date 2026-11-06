import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../config/theme.dart';
import '../../models/deposit.dart';
import '../../services/api_service.dart';
import '../../utils/snackbar_helper.dart';
import '../../utils/util.dart';
import '../../widgets/screen_parts.dart';
import '../../widgets/work_parts.dart';
import 'deposit_parts.dart';

/// ฝากเงินชำระล่วงหน้า › บันทึกค่าฌาปนกิจประจำเดือน (หน้า 4 ของแบบ 13.1 แทน Frm_Body)
///
/// เดือนละหนึ่งแถว: เริ่มศพที่ ถึงศพที่ ศพละ (ตั้งต้นจากเดือนก่อน) อ้างอิงประกาศ
/// จำนวนศพและเป็นเงินคำนวณให้ดู backend คำนวณซ้ำเองเสมอ เพิ่มได้เฉพาะเดือนถัดจากล่าสุด
/// แก้ได้เฉพาะเดือนที่ยังไม่ประมวลผล
class MonthlyCostScreen extends StatefulWidget {
  final ApiService apiService;

  const MonthlyCostScreen({super.key, required this.apiService});

  static const String menuTitle = 'บันทึกค่าฌาปนกิจประจำเดือน';
  static const IconData menuIcon = Icons.event_note;

  static const Key beginKey = ValueKey('cost-begin');
  static const Key endKey = ValueKey('cost-end');
  static const Key perBodyKey = ValueKey('cost-per-body');
  static const Key refKey = ValueKey('cost-ref');
  static const Key saveKey = ValueKey('cost-save');
  static const Key previewKey = ValueKey('cost-preview');
  static Key editKey(int period) => ValueKey('cost-edit-$period');

  @override
  State<MonthlyCostScreen> createState() => _MonthlyCostScreenState();
}

class _MonthlyCostScreenState extends State<MonthlyCostScreen> {
  List<MonthlyCostItem>? _items;
  String? _error;
  bool _saving = false;

  /// เดือนที่กำลังกรอก (เพิ่มใหม่ หรือแก้แถวเดิม)
  int? _period;
  bool _create = true;
  final _begin = TextEditingController();
  final _end = TextEditingController();
  final _perBody = TextEditingController();
  final _ref = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in [_begin, _end, _perBody, _ref]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final items = await widget.apiService.depositMonthlyCosts();
      final draft = await widget.apiService.depositMonthlyCostDraft();
      if (!mounted) return;
      setState(() {
        _items = items;
        _create = true;
        _period = intOf(draft['period']) == 0 ? null : intOf(draft['period']);
        _begin.text = draft['bodyBegin'] == null ? '' : '${draft['bodyBegin']}';
        _end.text = '';
        _perBody.text = draft['perBody'] == null ? '' : '${draft['perBody']}';
        _ref.text = '${draft['announcementRef'] ?? ''}';
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  void _edit(MonthlyCostItem c) => setState(() {
    _create = false;
    _period = c.period;
    _begin.text = '${c.bodyBegin ?? ''}';
    _end.text = '${c.bodyEnd ?? ''}';
    _perBody.text = c.perBody ?? '';
    _ref.text = c.announcementRef ?? '';
  });

  int? get _count {
    final b = int.tryParse(_begin.text), e = int.tryParse(_end.text);
    return b == null || e == null || e < b ? null : e - b + 1;
  }

  /// ตัวอย่างยอดต่อคน (แสดงเท่านั้น) — คิดเป็นสตางค์ ไม่ผ่าน double
  String get _preview {
    final n = _count;
    final m = RegExp(
      r'^(\d+)(?:\.(\d{1,2}))?$',
    ).firstMatch(_perBody.text.trim());
    if (n == null || m == null) return '-';
    final satang =
        int.parse(m.group(1)!) * 100 +
        int.parse((m.group(2) ?? '').padRight(2, '0'));
    final total = satang * n;
    return '${Util.formatCount(n)} ศพ × ${_perBody.text.trim()} = '
        '${moneyText('${total ~/ 100}.${(total % 100).toString().padLeft(2, '0')}')} บาท';
  }

  Future<void> _save() async {
    final p = _period;
    final b = int.tryParse(_begin.text), e = int.tryParse(_end.text);
    if (p == null) {
      context.showErrorSnackBar('กรุณาเลือกเดือน');
      return;
    }
    if (b == null || e == null) {
      context.showErrorSnackBar('กรุณากรอกเริ่มศพที่และถึงศพที่');
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.apiService.depositSaveMonthlyCost(
        period: p,
        bodyBegin: b,
        bodyEnd: e,
        perBody: _perBody.text.trim(),
        announcementRef: _ref.text,
        create: _create,
      );
      if (!mounted) return;
      context.showSuccessSnackBar(
        'บันทึกค่าฌาปนกิจเดือน ${DepositPeriod.label(p)} แล้ว',
      );
      await _load();
    } catch (err) {
      if (mounted) context.showErrorSnackBar(err.toString());
    }
    if (mounted) setState(() => _saving = false);
  }

  Widget _numField(
    Key key,
    TextEditingController c,
    String label, {
    bool decimal = false,
    double width = 150,
  }) => SizedBox(
    width: width,
    child: TextField(
      key: key,
      controller: c,
      textAlign: TextAlign.right,
      onChanged: (_) => setState(() {}),
      inputFormatters: [
        FilteringTextInputFormatter.allow(
          RegExp(decimal ? r'[0-9.]' : r'[0-9]'),
        ),
      ],
      style: screenText(size: 14),
      decoration: depositInput(label),
    ),
  );

  Widget _form() {
    final first = (_items ?? const []).isEmpty;
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
            Text(
              _create
                  ? 'เพิ่มเดือนใหม่: ${DepositPeriod.label(_period)}'
                  : 'แก้ไขเดือน ${DepositPeriod.label(_period)}',
              style: screenText(size: 16, weight: FontWeight.w700),
            ),
            if (first && _create) ...[
              const SizedBox(height: 8),
              MonthYearPicker(
                year: _period == null
                    ? Util.currentBuddhistYear()
                    : DepositPeriod.year(_period!),
                month: _period == null
                    ? DateTime.now().month
                    : DepositPeriod.month(_period!),
                onChanged: (y, m) =>
                    setState(() => _period = DepositPeriod.of(y, m)),
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _numField(MonthlyCostScreen.beginKey, _begin, 'เริ่มศพที่'),
                _numField(MonthlyCostScreen.endKey, _end, 'ถึงศพที่'),
                _numField(
                  MonthlyCostScreen.perBodyKey,
                  _perBody,
                  'ศพละ (บาท)',
                  decimal: true,
                  width: 130,
                ),
                SizedBox(
                  width: 320,
                  child: TextField(
                    key: MonthlyCostScreen.refKey,
                    controller: _ref,
                    maxLength: 200,
                    style: screenText(size: 14),
                    decoration: depositInput('อ้างอิงประกาศอัตราศพละ'),
                  ),
                ),
              ],
            ),
            Text(
              'ยอดต่อคน: $_preview',
              key: MonthlyCostScreen.previewKey,
              style: screenText(size: 14.5, weight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: [
                FilledButton.icon(
                  key: MonthlyCostScreen.saveKey,
                  onPressed: _saving ? null : _save,
                  icon: const Icon(Icons.save),
                  label: Text(
                    'บันทึก',
                    style: screenText(size: 14, color: Colors.white),
                  ),
                ),
                if (!_create)
                  OutlinedButton(
                    onPressed: _saving ? null : _load,
                    child: Text('ยกเลิกการแก้ไข', style: screenText(size: 14)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    return WorkPage(
      group: depositGroup,
      maxWidth: 1240,
      children: [
        const ScreenHeader(
          icon: MonthlyCostScreen.menuIcon,
          title: MonthlyCostScreen.menuTitle,
          subtitle:
              'บันทึกช่วงศพของเดือนและอัตราศพละตามประกาศ ก่อนประมวลผลหักเงิน',
          bullets: [
            'เพิ่มได้เฉพาะเดือนถัดจากเดือนล่าสุด เริ่มศพที่ต้องต่อจากศพสุดท้ายของเดือนก่อน',
            'ศพละตั้งต้นจากเดือนก่อน ถ้ามีประกาศปรับอัตราให้แก้ก่อนบันทึก',
            'เดือนที่ประมวลผลแล้วแก้ไขไม่ได้',
          ],
        ),
        const SizedBox(height: 14),
        if (_error != null) LoadState(error: _error, onRetry: _load),
        if (items == null && _error == null) const LoadState(loading: true),
        if (items != null) ...[
          _form(),
          const SizedBox(height: 14),
          PagedSheet<MonthlyCostItem>(
            minWidth: 1050,
            unit: 'เดือน',
            items: items,
            columns: const [
              SheetColumn('เดือน ปี', flex: 3),
              SheetColumn('เริ่มศพที่', flex: 2, right: true),
              SheetColumn('ถึงศพที่', flex: 2, right: true),
              SheetColumn('จำนวน', flex: 2, right: true),
              SheetColumn('ศพละ', flex: 2, right: true),
              SheetColumn('เป็นเงิน', flex: 2, right: true),
              SheetColumn('อ้างอิงประกาศ', flex: 4),
              SheetColumn('สถานะ', flex: 3),
            ],
            cells: (c, _) => [
              cellText(DepositPeriod.label(c.period), weight: FontWeight.w600),
              cellText('${c.bodyBegin ?? '-'}'),
              cellText('${c.bodyEnd ?? '-'}'),
              cellText(countText(c.bodyCount)),
              cellMoney(c.perBody),
              cellMoney(c.amount, bold: true),
              cellText(c.announcementRef, size: 13),
              c.processed
                  ? const StatusChip('ประมวลผลแล้ว', AppTheme.successColor)
                  : TextButton.icon(
                      key: MonthlyCostScreen.editKey(c.period),
                      onPressed: _saving ? null : () => _edit(c),
                      icon: const Icon(Icons.edit, size: 16),
                      label: Text('แก้ไข', style: screenText(size: 13.5)),
                    ),
            ],
          ),
        ],
      ],
    );
  }
}
