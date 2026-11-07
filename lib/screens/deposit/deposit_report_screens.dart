import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../config/theme.dart';
import '../../models/deposit.dart';
import '../../services/api_service.dart';
import '../../utils/util.dart';
import '../../widgets/screen_parts.dart';
import '../../widgets/work_parts.dart';
import 'deposit_parts.dart';

/// รายงาน › บัญชีรายละเอียดประจำเดือน (หน้า 8 ของแบบ 13.1 = rep1 เดิม)
///
/// เลือกเดือนจากรายการเดือนที่มีรายงาน → ตาราง + บรรทัดรวม 4 ยอด + ส่งออก Excel (แทน query แปลงเป็นexcel) และ PDF
/// ค้นหาในเดือนที่เลือกด้วยเลขสมาชิกหรือชื่อ-สกุล (กรองในหน้าจอ ไฟล์ที่ส่งออกเป็นทั้งเดือนเสมอ)
class MonthlyReportScreen extends StatefulWidget {
  final ApiService apiService;

  const MonthlyReportScreen({super.key, required this.apiService});

  static const String menuTitle = 'บัญชีรายละเอียดประจำเดือน';
  static const IconData menuIcon = Icons.summarize;
  static const Key periodKey = ValueKey('monthly-report-period');
  static const Key searchKey = ValueKey('monthly-report-search');

  /// ตรงกับคำค้น: ตัวเลข = เลขสมาชิกมีเลขนี้, ข้อความ = ชื่อ-สกุลมีคำนี้ (ไม่สนช่องว่าง)
  static bool matches(MonthlyReportItem r, String query) {
    final q = query.trim();
    if (q.isEmpty) return true;
    if (RegExp(r'^\d+$').hasMatch(q)) return r.memberNo.contains(q);
    String squash(String s) => s.replaceAll(RegExp(r'\s+'), '');
    return squash(r.name).contains(squash(q)) || r.memberNo.contains(q);
  }

  @override
  State<MonthlyReportScreen> createState() => _MonthlyReportScreenState();
}

class _MonthlyReportScreenState extends State<MonthlyReportScreen> {
  List<int>? _periods;
  int? _period;
  MonthlyReportData? _data;
  String? _error;
  bool _loading = true;
  final _search = TextEditingController();

  String get _query => _search.text.trim();

  List<MonthlyReportItem> _filtered(MonthlyReportData d) => _query.isEmpty
      ? d.rows
      : [
          for (final r in d.rows)
            if (MonthlyReportScreen.matches(r, _query)) r,
        ];

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    try {
      final periods = await widget.apiService.depositReportPeriods();
      if (!mounted) return;
      setState(() => _periods = periods);
      if (periods.isNotEmpty) {
        await _show(periods.first);
      } else {
        setState(() => _loading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _show(int p) async {
    setState(() {
      _period = p;
      _loading = true;
      _error = null;
    });
    try {
      final d = await widget.apiService.depositMonthlyReport(p);
      if (mounted) setState(() => _data = d);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final d = _data;
    return WorkPage(
      group: depositGroup,
      maxWidth: 1400,
      children: [
        const ScreenHeader(
          icon: MonthlyReportScreen.menuIcon,
          title: 'รายงานเงินสงเคราะห์ล่วงหน้า ประจำเดือน',
          subtitle:
              'บัญชีรายละเอียดสมาชิกฝากชำระล่วงหน้า สร้างตอนประมวลผลหักเงินของเดือนนั้น',
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 12,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (_periods != null && _periods!.isNotEmpty)
              SizedBox(
                width: 260,
                child: DropdownButtonFormField<int>(
                  key: MonthlyReportScreen.periodKey,
                  initialValue: _period,
                  decoration: depositInput('เดือน'),
                  items: [
                    for (final p in _periods!)
                      DropdownMenuItem(
                        value: p,
                        child: Text(
                          '${DepositPeriod.label(p)} (${DepositPeriod.legacy(p)})',
                          style: screenText(size: 14),
                        ),
                      ),
                  ],
                  onChanged: (p) {
                    if (p != null) _show(p);
                  },
                ),
              ),
            if (_period != null && d != null) ...[
              ExcelButton(
                load: () =>
                    widget.apiService.depositMonthlyReportExcel(_period!),
              ),
              PdfButton(
                load: () => widget.apiService.depositMonthlyReportPdf(_period!),
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
        if (_error != null) LoadState(error: _error, onRetry: _init),
        if (_loading && d == null) const LoadState(loading: true),
        if (_periods != null && _periods!.isEmpty)
          const NoticeBar(
            type: NoticeType.info,
            text: 'ยังไม่มีรายงานประจำเดือน',
          ),
        if (d != null) ...[
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              TotalChip('จำนวน', '${countText(d.count)} คน'),
              TotalChip('ยกมา', moneyText(d.carried)),
              TotalChip(
                'รับ',
                moneyText(d.received),
                color: AppTheme.successColor,
              ),
              TotalChip('จ่าย', moneyText(d.paid), color: AppTheme.dangerColor),
              TotalChip('คงเหลือ', moneyText(d.balance)),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 360,
                child: TextField(
                  key: MonthlyReportScreen.searchKey,
                  controller: _search,
                  style: screenText(size: 14),
                  decoration: depositInput(
                    'ค้นหาเลขสมาชิก หรือชื่อ-สกุล',
                    prefix: const Icon(Icons.search),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              if (_query.isNotEmpty)
                Text(
                  'พบ ${countText(_filtered(d).length)} จาก ${countText(d.count)} คน',
                  style: screenText(size: 13.5, color: AppTheme.textSecondary),
                ),
            ],
          ),
          const SizedBox(height: 10),
          PagedSheet<MonthlyReportItem>(
            key: ValueKey('monthly-${d.period}-$_query'),
            minWidth: 1300,
            unit: 'คน',
            items: _filtered(d),
            emptyText: 'ไม่พบสมาชิกที่ค้นหา',
            initialPageSize: 20,
            columns: const [
              SheetColumn('ลำดับ', flex: 1),
              SheetColumn('เลขที่สมาชิก', flex: 2),
              SheetColumn('ชื่อ - สกุล', flex: 5),
              SheetColumn('ยกมา', flex: 3, right: true),
              SheetColumn('จำนวนเงินรับ', flex: 3, right: true),
              SheetColumn('จ่ายศพที่', flex: 3),
              SheetColumn('พ้นสภาพสมาชิก', flex: 2),
              SheetColumn('ค้างชำระ (ศพ)', flex: 3),
              SheetColumn('จำนวนเงินจ่าย', flex: 3, right: true),
              SheetColumn('ยอดคงเหลือ', flex: 3, right: true),
            ],
            cells: (r, no) => [
              cellText('$no'),
              cellText(r.memberNo),
              cellText(r.name, size: 13.5),
              cellMoney(r.carried),
              cellMoney(r.received),
              cellText(r.bodyPay, size: 13),
              cellText(r.status == '.' ? '' : r.status, size: 13),
              cellText(r.bodyDebt, size: 13),
              cellMoney(r.paid),
              cellMoney(r.balance),
            ],
            // ยอดรวมทั้งเดือนจาก backend — ระหว่างค้นหาไม่แสดง (หน้าเว็บไม่คำนวณเงินเอง)
            totals: _query.isNotEmpty
                ? null
                : [
                    const SizedBox.shrink(),
                    const SizedBox.shrink(),
                    cellText(
                      'รวม ${countText(d.count)} คน',
                      weight: FontWeight.w700,
                    ),
                    cellMoney(d.carried, bold: true),
                    cellMoney(d.received, bold: true),
                    const SizedBox.shrink(),
                    const SizedBox.shrink(),
                    const SizedBox.shrink(),
                    cellMoney(d.paid, bold: true),
                    cellMoney(d.balance, bold: true),
                  ],
          ),
        ],
      ],
    );
  }
}

/// รายงาน › สมาชิกที่ต้องฝากเงินเพิ่ม (หน้า 7 = rep2 เดิม) และ › สมาชิกระหว่างทวงถามหนี้ ([dunning] = true)
///
/// ข้อมูลปัจจุบัน ณ เวลาที่เปิด หัวรายงานแสดง "ข้อมูล ณ วันที่" บรรทัดรวมจำนวนคนและยอดหนี้
class NeedDepositScreen extends StatefulWidget {
  final ApiService apiService;
  final bool dunning;

  const NeedDepositScreen({
    super.key,
    required this.apiService,
    this.dunning = false,
  });

  static const String menuTitle = 'สมาชิกที่ต้องฝากเงินเพิ่ม';
  static const IconData menuIcon = Icons.notification_important_outlined;
  static const String dunningTitle = 'สมาชิกระหว่างทวงถามหนี้';
  static const IconData dunningIcon = Icons.gavel;
  static const Key thresholdKey = ValueKey('need-threshold');

  @override
  State<NeedDepositScreen> createState() => _NeedDepositScreenState();
}

class _NeedDepositScreenState extends State<NeedDepositScreen> {
  final _threshold = TextEditingController(text: '200');
  NeedDepositData? _data;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _threshold.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final d = widget.dunning
          ? await widget.apiService.depositDunningReport()
          : await widget.apiService.depositNeedReport(
              threshold: _threshold.text,
            );
      if (mounted) setState(() => _data = d);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final d = _data;
    return WorkPage(
      group: depositGroup,
      maxWidth: 1240,
      children: [
        ScreenHeader(
          icon: widget.dunning
              ? NeedDepositScreen.dunningIcon
              : NeedDepositScreen.menuIcon,
          title: widget.dunning
              ? 'รายชื่อสมาชิกที่อยู่ระหว่างทวงถามหนี้'
              : 'รายชื่อสมาชิกที่ควรฝากเงินสงเคราะห์ล่วงหน้าเพิ่ม',
          subtitle: widget.dunning
              ? 'บัญชีที่ทำเครื่องหมายระหว่างทวงถาม (ยังคิดหนี้รายเดือนต่อ) เรียงตามสังกัด'
              : 'บัญชีที่ยังหักรายเดือน และมีหนี้ค้าง หรือเงินฝากไม่เกินเกณฑ์ เรียงตามสังกัด',
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 12,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (!widget.dunning)
              SizedBox(
                width: 220,
                child: TextField(
                  key: NeedDepositScreen.thresholdKey,
                  controller: _threshold,
                  textAlign: TextAlign.right,
                  onSubmitted: (_) => _load(),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                  ],
                  style: screenText(size: 14),
                  decoration: depositInput('เงินฝากไม่เกิน (บาท)'),
                ),
              ),
            if (!widget.dunning)
              OutlinedButton.icon(
                onPressed: _loading ? null : _load,
                icon: const Icon(Icons.refresh, size: 18),
                label: Text('แสดง', style: screenText(size: 14)),
              ),
            if (d != null)
              ExcelButton(
                load: () => widget.dunning
                    ? widget.apiService.depositDunningReportExcel()
                    : widget.apiService.depositNeedReportExcel(
                        threshold: _threshold.text,
                      ),
              ),
            if (d != null)
              PdfButton(
                load: () => widget.dunning
                    ? widget.apiService.depositDunningReportPdf()
                    : widget.apiService.depositNeedReportPdf(
                        threshold: _threshold.text,
                      ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (_error != null) LoadState(error: _error, onRetry: _load),
        if (_loading && d == null) const LoadState(loading: true),
        if (d != null) ...[
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              TotalChip('ข้อมูล ณ วันที่', Util.thaiDateTimeOf(d.asOf)),
              TotalChip('จำนวน', '${countText(d.count)} คน'),
              TotalChip(
                'หนี้ค้างรวม',
                moneyText(d.totalDebt),
                color: AppTheme.dangerColor,
              ),
            ],
          ),
          const SizedBox(height: 12),
          PagedSheet<NeedDepositItem>(
            minWidth: 1100,
            unit: 'คน',
            items: d.rows,
            initialPageSize: 20,
            columns: const [
              SheetColumn('ลำดับ', flex: 1),
              SheetColumn('สังกัด', flex: 4),
              SheetColumn('เลขที่สมาชิก', flex: 2),
              SheetColumn('ชื่อ - สกุล', flex: 5),
              SheetColumn('ยอดคงเหลือ', flex: 2, right: true),
              SheetColumn('หนี้ค้างชำระ', flex: 2, right: true),
              SheetColumn('หมายเหตุ', flex: 5),
            ],
            cells: (r, no) => [
              cellText('$no'),
              cellText(r.divName, size: 13),
              cellText(r.memberNo),
              cellText(r.name, size: 13.5),
              cellMoney(r.balance),
              cellMoney(r.debt),
              cellText(r.remark, size: 13),
            ],
          ),
        ],
      ],
    );
  }
}

/// รายงาน › ยอดเงินฝากรายเดือน (หน้า 9 แทน query ยอดเงินฝากเดือนที่ต้องการ)
class DepositTotalsScreen extends StatefulWidget {
  final ApiService apiService;

  /// วันนี้ (เทสต์ส่งวันตายตัว)
  final DateTime? today;

  const DepositTotalsScreen({super.key, required this.apiService, this.today});

  static const String menuTitle = 'ยอดเงินฝากรายเดือน';
  static const IconData menuIcon = Icons.savings_outlined;

  @override
  State<DepositTotalsScreen> createState() => _DepositTotalsScreenState();
}

class _DepositTotalsScreenState extends State<DepositTotalsScreen> {
  late int _year;
  late int _month;
  DepositTotalsData? _data;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    final now = widget.today ?? DateTime.now();
    _year = now.year + 543;
    _month = now.month;
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final d = await widget.apiService.depositTotals(
        DepositPeriod.of(_year, _month),
      );
      if (mounted) setState(() => _data = d);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final d = _data;
    return WorkPage(
      group: depositGroup,
      maxWidth: 1100,
      children: [
        const ScreenHeader(
          icon: DepositTotalsScreen.menuIcon,
          title: DepositTotalsScreen.menuTitle,
          subtitle: 'รวมเงินฝากล่วงหน้าที่รับในเดือนที่เลือก พร้อมรายการ',
        ),
        const SizedBox(height: 14),
        MonthYearPicker(
          year: _year,
          month: _month,
          today: widget.today,
          enabled: !_loading,
          onChanged: (y, m) {
            setState(() {
              _year = y;
              _month = m;
            });
            _load();
          },
        ),
        const SizedBox(height: 12),
        if (_error != null) LoadState(error: _error, onRetry: _load),
        if (_loading && d == null) const LoadState(loading: true),
        if (d != null) ...[
          Wrap(
            spacing: 10,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              TotalChip('เดือน', DepositPeriod.label(d.period)),
              TotalChip('จำนวน', '${countText(d.count)} รายการ'),
              TotalChip(
                'ยอดเงินฝากรวม',
                moneyText(d.total),
                color: AppTheme.successColor,
              ),
              ExcelButton(
                load: () => widget.apiService.depositTotalsExcel(d.period),
              ),
              PdfButton(
                load: () => widget.apiService.depositTotalsPdf(d.period),
              ),
            ],
          ),
          const SizedBox(height: 12),
          PagedSheet<DepositReceiptItem>(
            minWidth: 900,
            items: d.rows,
            initialPageSize: 20,
            columns: const [
              SheetColumn('ลำดับ', flex: 1),
              SheetColumn('วันที่', flex: 3),
              SheetColumn('เลขที่สมาชิก', flex: 2),
              SheetColumn('ชื่อ - สกุล', flex: 5),
              SheetColumn('เลขที่เอกสาร', flex: 2),
              SheetColumn('จำนวนเงิน', flex: 2, right: true),
            ],
            cells: (r, no) => [
              cellText('$no'),
              cellText(r.date == null ? r.legacyDate : Util.thaiDateOf(r.date)),
              cellText(r.memberNo),
              cellText(r.name, size: 13.5),
              cellText(r.docNo),
              cellMoney(r.amount),
            ],
          ),
        ],
      ],
    );
  }
}
