import 'package:flutter/material.dart';

import '../../config/theme.dart';
import '../../models/deposit.dart';
import '../../services/api_service.dart';
import '../../utils/dialog.dart';
import '../../utils/snackbar_helper.dart';
import '../../widgets/screen_parts.dart';
import '../../widgets/work_parts.dart';
import 'deposit_parts.dart';

/// ฝากเงินชำระล่วงหน้า › ประมวลผลหักเงินประจำเดือน (หน้า 5 ของแบบ 13.1)
///
/// ไม่ต้องพิมพ์ MMYY: ระบบเลือกเดือนที่ต้องประมวลผลถัดไปให้ (ตามลำดับ) แสดงตัวอย่างผล → ยืนยัน →
/// หักเงินและเตรียมรายงานประจำเดือนในขั้นเดียว + ปุ่มยกเลิกการประมวลผลเดือนล่าสุด
class MonthlyProcessScreen extends StatefulWidget {
  final ApiService apiService;

  const MonthlyProcessScreen({super.key, required this.apiService});

  static const String menuTitle = 'ประมวลผลหักเงินประจำเดือน';
  static const IconData menuIcon = Icons.play_circle_outline;

  static const Key processKey = ValueKey('process-run');
  static const Key undoKey = ValueKey('process-undo');

  @override
  State<MonthlyProcessScreen> createState() => _MonthlyProcessScreenState();
}

class _MonthlyProcessScreenState extends State<MonthlyProcessScreen> {
  ProcessStatusData? _status;
  ProcessPreviewData? _preview;
  Map<String, dynamic>? _lastResult;
  String? _error;
  bool _busy = false;

  ApiService get _api => widget.apiService;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final st = await _api.depositProcessStatus();
      ProcessPreviewData? pv;
      if (st.pending.contains(st.openPeriod)) {
        pv = await _api.depositProcessPreview(st.openPeriod);
      }
      if (!mounted) return;
      setState(() {
        _status = st;
        _preview = pv;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _process() async {
    final p = _preview!;
    final ok = await AppDialog.showConfirm(
      context,
      'ประมวลผลหักเงินเดือน ${DepositPeriod.label(p.period)} (ศพที่ ${p.bodyBegin}-${p.bodyEnd} คนละ ${moneyText(p.amount)} บาท)?\n'
      'หักได้ ${countText(p.canPay)} คน ${moneyText(p.payTotal)} บาท · ค้างชำระ ${countText(p.willOwe)} คน\n'
      'ระบบจะสร้างรายงานประจำเดือนให้ในขั้นเดียวกัน',
      confirmText: 'ประมวลผล',
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    try {
      final r = await _api.depositProcess(p.period);
      if (!mounted) return;
      setState(() => _lastResult = r);
      context.showSuccessSnackBar(
        'ประมวลผลเดือน ${DepositPeriod.label(p.period)} เรียบร้อย',
      );
      await _load();
    } catch (e) {
      if (mounted) context.showErrorSnackBar(e.toString());
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _undo() async {
    final period = _status!.lastProcessed!;
    final ok = await AppDialog.showConfirm(
      context,
      'ยกเลิกการประมวลผลเดือน ${DepositPeriod.label(period)}?\n'
      'ยอดเงินฝากและหนี้ของทุกบัญชีจะกลับเป็นเหมือนก่อนประมวลผล และรายงานประจำเดือนนี้จะถูกยกเลิก',
      confirmText: 'ยกเลิกการประมวลผล',
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await _api.depositUndoProcess(period);
      if (!mounted) return;
      setState(() => _lastResult = null);
      context.showSuccessSnackBar(
        'ยกเลิกการประมวลผลเดือน ${DepositPeriod.label(period)} แล้ว',
      );
      await _load();
    } catch (e) {
      if (mounted) context.showErrorSnackBar(e.toString());
    }
    if (mounted) setState(() => _busy = false);
  }

  Widget _card(List<Widget> children) => Card(
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: BorderSide(color: AppTheme.dividerColor),
    ),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final st = _status;
    final p = _preview;
    final r = _lastResult;
    return WorkPage(
      group: depositGroup,
      maxWidth: 1000,
      children: [
        const ScreenHeader(
          icon: MonthlyProcessScreen.menuIcon,
          title: MonthlyProcessScreen.menuTitle,
          subtitle:
              'หักค่าฌาปนกิจจากบัญชีฝากล่วงหน้าทุกคน และเตรียมรายงานประจำเดือนในขั้นเดียว',
          bullets: [
            'ประมวลผลตามลำดับเดือน ต้องบันทึกค่าฌาปนกิจประจำเดือนก่อน',
            'เงินฝากพอ = หักทั้งเดือน, ไม่พอ = ค้างชำระทั้งเดือน (ปลดหนี้เมื่อฝากเงินเพิ่ม)',
            'บัญชีระหว่างทวงถามหนี้ยังถูกคิดหนี้ต่อ บัญชีพ้นสภาพ/ปิดแล้วไม่ถูกหัก',
          ],
        ),
        const SizedBox(height: 14),
        if (_error != null) LoadState(error: _error, onRetry: _load),
        if (st == null && _error == null) const LoadState(loading: true),
        if (st != null) ...[
          _card([
            Text(
              'เดือนที่ต้องประมวลผลถัดไป: ${DepositPeriod.label(st.openPeriod)}',
              style: screenText(size: 17, weight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            if (p == null)
              NoticeBar(
                type: NoticeType.warning,
                text:
                    'ยังไม่ได้บันทึกค่าฌาปนกิจของเดือน ${DepositPeriod.label(st.openPeriod)} '
                    'กรุณาบันทึกที่เมนู "$depositGroup › บันทึกค่าฌาปนกิจประจำเดือน" ก่อน',
              ),
            if (p != null) ...[
              Wrap(
                spacing: 10,
                runSpacing: 8,
                children: [
                  TotalChip('ศพที่', '${p.bodyBegin}-${p.bodyEnd}'),
                  TotalChip('ยอดต่อคน', '${moneyText(p.amount)} บาท'),
                  TotalChip('บัญชีที่หัก', '${countText(p.accounts)} คน'),
                  TotalChip(
                    'หักได้',
                    '${countText(p.canPay)} คน · ${moneyText(p.payTotal)} บาท',
                    color: AppTheme.successColor,
                  ),
                  TotalChip(
                    'ค้างชำระ',
                    '${countText(p.willOwe)} คน · ${moneyText(p.oweTotal)} บาท',
                    color: AppTheme.dangerColor,
                  ),
                ],
              ),
              if (!p.ready && p.reason != null) ...[
                const SizedBox(height: 10),
                NoticeBar(type: NoticeType.error, text: p.reason!),
              ],
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.icon(
                  key: MonthlyProcessScreen.processKey,
                  onPressed: _busy || !p.ready ? null : _process,
                  icon: _busy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.play_arrow),
                  label: Text(
                    _busy ? 'กำลังประมวลผล...' : 'ประมวลผลและเตรียมรายงาน',
                    style: screenText(size: 14.5, color: Colors.white),
                  ),
                ),
              ),
            ],
          ]),
          if (r != null) ...[
            const SizedBox(height: 12),
            NoticeBar(
              type: NoticeType.success,
              text:
                  'ประมวลผลเดือน ${DepositPeriod.label(intOf(r['period']))} แล้ว: หักได้ ${countText(r['paid'])} คน '
                  '${moneyText(r['paidTotal'])} บาท, ค้างชำระ ${countText(r['owed'])} คน, '
                  'รายงานประจำเดือน ${countText(r['reportRows'])} แถว',
            ),
          ],
          const SizedBox(height: 14),
          _card([
            Text(
              'ยกเลิกการประมวลผลเดือนล่าสุด',
              style: screenText(size: 16, weight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              st.lastProcessed == null
                  ? 'ยังไม่มีเดือนที่ประมวลผล'
                  : 'เดือนล่าสุดที่ประมวลผล: ${DepositPeriod.label(st.lastProcessed)}',
              style: screenText(size: 14),
            ),
            if (!st.canUndo && st.undoBlockedReason != null) ...[
              const SizedBox(height: 6),
              Text(
                st.undoBlockedReason!,
                style: screenText(size: 13.5, color: AppTheme.textSecondary),
              ),
            ],
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                key: MonthlyProcessScreen.undoKey,
                onPressed: _busy || !st.canUndo ? null : _undo,
                icon: const Icon(Icons.undo, color: AppTheme.cancelColor),
                label: Text('ยกเลิกการประมวลผล', style: screenText(size: 14)),
              ),
            ),
          ]),
        ],
      ],
    );
  }
}
