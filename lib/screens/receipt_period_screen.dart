import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../models/receipt.dart';
import '../services/api_service.dart';
import '../widgets/pdf_password_picker.dart';
import '../widgets/screen_parts.dart';
import '../widgets/work_parts.dart';

/// ดาวน์โหลด › ใบเสร็จรับเงิน (รายงวด) — สมาชิกฌาปนกิจเท่านั้น ของตัวเองเท่านั้น
///
/// งวดเป็นปุ่มกดเลือกได้หลายอัน (ไม่ใช้ Ctrl/Shift ใช้บนมือถือได้) + เลือกทั้งหมด + รหัสเปิดไฟล์ → PDF ไฟล์เดียว
/// backend รับได้ไม่เกิน [maxPeriods] งวดต่อครั้ง
class ReceiptPeriodScreen extends StatefulWidget {
  final ApiService apiService;

  const ReceiptPeriodScreen({super.key, required this.apiService});

  static const String menuTitle = 'ใบเสร็จรับเงิน (รายงวด)';
  static const IconData menuIcon = Icons.receipt_long_outlined;
  static const String groupTitle = 'ดาวน์โหลด';

  /// จำนวนงวดสูงสุดต่อครั้ง (ตรงกับ backend)
  static const int maxPeriods = 24;

  static const Key selectAllKey = ValueKey('receipt-select-all');
  static const Key clearKey = ValueKey('receipt-clear');
  static const Key downloadKey = ValueKey('receipt-download');
  static Key periodKey(String receiptNo) => ValueKey('period-$receiptNo');

  @override
  State<ReceiptPeriodScreen> createState() => _ReceiptPeriodScreenState();
}

class _ReceiptPeriodScreenState extends State<ReceiptPeriodScreen>
    with FileDownloads<ReceiptPeriodScreen> {
  final _formKey = GlobalKey<FormState>();
  final _custom = TextEditingController();
  List<ReceiptPeriod> _periods = [];
  final Set<String> _selected = {};
  String _passwordType = PdfPassword.none;
  bool _loading = true;
  String? _error;
  String? _notice;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _custom.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final periods = await widget.apiService.getReceiptPeriods();
      if (!mounted) return;
      setState(() {
        _periods = periods;
        _selected.removeWhere((n) => !periods.any((p) => p.receiptNo == n));
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  void _toggle(String no) {
    clearSaved();
    setState(() {
      _notice = null;
      if (_selected.contains(no)) {
        _selected.remove(no);
      } else if (_selected.length >= ReceiptPeriodScreen.maxPeriods) {
        _notice =
            'เลือกได้ไม่เกิน ${ReceiptPeriodScreen.maxPeriods} งวดต่อครั้ง';
      } else {
        _selected.add(no);
      }
    });
  }

  void _selectAll() {
    clearSaved();
    setState(() {
      _selected
        ..clear()
        ..addAll(
          _periods.take(ReceiptPeriodScreen.maxPeriods).map((p) => p.receiptNo),
        );
      _notice = _periods.length > ReceiptPeriodScreen.maxPeriods
          ? 'มี ${_periods.length} งวด เลือกได้ไม่เกิน ${ReceiptPeriodScreen.maxPeriods} งวดต่อครั้ง '
                'ระบบเลือก ${ReceiptPeriodScreen.maxPeriods} งวดล่าสุดให้'
          : null;
    });
  }

  Future<void> _download() async {
    if (_selected.isEmpty) {
      setState(() => _notice = 'กรุณาเลือกงวดอย่างน้อย 1 งวด');
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    // เรียงตามลำดับที่แสดง (ล่าสุดก่อน)
    final nos = [
      for (final p in _periods)
        if (_selected.contains(p.receiptNo)) p.receiptNo,
    ];
    await runDownload(
      'receipt',
      () => widget.apiService.downloadPeriodReceipts(
        receiptNos: nos,
        passwordType: _passwordType,
        password: _custom.text,
      ),
    );
  }

  Widget _periodButton(ReceiptPeriod p) {
    final on = _selected.contains(p.receiptNo);
    final busy = downloading != null;
    return Tooltip(
      message: [
        'ใบเสร็จเลขที่ ${p.receiptNo}',
        if (p.dateText != null) 'ลงวันที่ ${p.dateText}',
      ].join('\n'),
      child: InkWell(
        key: ReceiptPeriodScreen.periodKey(p.receiptNo),
        onTap: busy ? null : () => _toggle(p.receiptNo),
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: 170,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            color: on ? AppTheme.primaryColor : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: on ? AppTheme.primaryColor : AppTheme.dividerColor,
              width: on ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                on ? Icons.check_box : Icons.check_box_outline_blank,
                size: 20,
                color: on ? Colors.white : AppTheme.textSecondary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.label,
                      style: screenText(
                        size: 14,
                        weight: FontWeight.w600,
                        color: on ? Colors.white : AppTheme.textPrimary,
                      ),
                    ),
                    if (p.receiptYear.isNotEmpty)
                      Text(
                        'ปี ${p.receiptYear}',
                        style: screenText(
                          size: 12,
                          color: on ? Colors.white70 : AppTheme.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final busy = downloading != null;
    return WorkPage(
      group: ReceiptPeriodScreen.groupTitle,
      children: [
        ScreenHeader(
          icon: ReceiptPeriodScreen.menuIcon,
          title: ReceiptPeriodScreen.menuTitle,
          subtitle: 'ใบเสร็จรับเงินค่าบำรุงฌาปนกิจของท่านที่หักผ่านเงินเดือน',
          bullets: [
            if (widget.apiService.memberNo != null)
              'เลขสมาชิก ${widget.apiService.memberNo}',
            'แตะงวดที่ต้องการ (เลือกได้หลายงวด) แล้วกดดาวน์โหลด จะได้ PDF ไฟล์เดียว',
          ],
        ),
        const SizedBox(height: 14),
        if (_loading || _error != null)
          LoadState(loading: _loading, error: _error, onRetry: _load)
        else if (_periods.isEmpty)
          const NoticeBar(
            type: NoticeType.info,
            text: 'ยังไม่มีใบเสร็จรับเงินรายงวดของท่าน',
          )
        else
          Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                StepCard(
                  step: 1,
                  title: 'เลือกงวด',
                  subtitle:
                      'เลือกแล้ว ${_selected.length} จาก ${_periods.length} งวด',
                  trailing: Wrap(
                    spacing: 6,
                    children: [
                      TextButton.icon(
                        key: ReceiptPeriodScreen.selectAllKey,
                        onPressed: busy ? null : _selectAll,
                        icon: const Icon(Icons.done_all, size: 18),
                        label: Text('เลือกทั้งหมด', style: screenText(size: 14)),
                      ),
                      TextButton.icon(
                        key: ReceiptPeriodScreen.clearKey,
                        onPressed: busy || _selected.isEmpty
                            ? null
                            : () {
                                clearSaved();
                                setState(() {
                                  _selected.clear();
                                  _notice = null;
                                });
                              },
                        icon: const Icon(Icons.clear_all, size: 18),
                        label: Text('ล้าง', style: screenText(size: 14)),
                      ),
                    ],
                  ),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [for (final p in _periods) _periodButton(p)],
                  ),
                ),
                if (_notice != null) ...[
                  const SizedBox(height: 10),
                  NoticeBar(type: NoticeType.warning, text: _notice!),
                ],
                const SizedBox(height: 12),
                StepCard(
                  step: 2,
                  title: 'รหัสเปิดไฟล์ PDF',
                  child: PdfPasswordPicker(
                    value: _passwordType,
                    options: PdfPassword.forSelf,
                    customController: _custom,
                    enabled: !busy,
                    onChanged: (t) {
                      clearSaved();
                      setState(() => _passwordType = t);
                    },
                  ),
                ),
                const SizedBox(height: 12),
                if (downloadError != null) ...[
                  NoticeBar(type: NoticeType.error, text: downloadError!),
                  const SizedBox(height: 10),
                ],
                DownloadButtons(
                  key: ReceiptPeriodScreen.downloadKey,
                  label: 'ดาวน์โหลดใบเสร็จ (PDF) ${_selected.length} งวด',
                  icon: Icons.picture_as_pdf_outlined,
                  busy: downloading == 'receipt',
                  blocked: busy || _selected.isEmpty,
                  saved: savedOf('receipt'),
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
