import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../services/api_service.dart';
import '../utils/util.dart';
import '../widgets/app_pagination.dart';
import '../widgets/screen_parts.dart';
import '../widgets/sheet_table.dart';
import '../widgets/work_parts.dart';

/// ประเภทบุคลากรของรายงานฌาปนกิจ (ค่า `type` ของเส้นรายงาน)
class EmpType {
  EmpType._();

  static const String g = 'G';
  static const String e = 'E';
  static const Map<String, String> names = {g: 'ข้าราชการ', e: 'ลูกจ้างประจำ'};

  static String nameOf(String type) => names[type] ?? type;
}

/// รายงาน › ฌาปนกิจ-สลิป (rep9) — ผู้ที่หักเงินฌาปนกิจไม่ได้ (ผู้นำไฟล์เข้า / ผู้ดูแล)
///
/// หน้าตาเดียวกับหน้า "รายงานฌาปนกิจ-สลิป" ของระบบหักหนี้ — ผลมาจากระบบหักหนี้ ไม่คำนวณเอง
/// เลือกงวด (ปี พ.ศ. + เดือน) + ประเภท → "ตรวจสอบ" (เรียกข้ามระบบ ใช้เวลาหลายวินาที จึงไม่เรียกอัตโนมัติ)
/// → การ์ดสรุป + ตารางผู้ที่หักไม่ได้ + ปุ่ม PDF "รายงานผู้ที่ไม่ถูกหักเงินฌาปนกิจ"
/// 503 `DPAY_API_NOT_CONFIGURED` / 404 งวดยังไม่มีรายการ = แสดง `message` ของ backend
/// **คำตอบมีเลขบัตรและชื่อ: อยู่ในหน่วยความจำของหน้าจอเท่านั้น ไม่ลง log** เลขบัตรแสดงแบบปิดบางส่วน
class ChapanaSlipScreen extends StatefulWidget {
  final ApiService apiService;
  final DateTime? today;

  const ChapanaSlipScreen({super.key, required this.apiService, this.today});

  static const String menuTitle = 'ฌาปนกิจ-สลิป';
  static const IconData menuIcon = Icons.compare_arrows;
  static const String groupTitle = 'รายงาน';

  static const Key runKey = ValueKey('slip-run');
  static const Key summaryKey = ValueKey('slip-summary');
  static const Key tableKey = ValueKey('slip-table');
  static const Key reportKey = ValueKey('slip-report');
  static const Key allPaidKey = ValueKey('slip-all-paid');
  static const Key noChapanaKey = ValueKey('slip-no-chapana');
  static const Key busyKey = ValueKey('slip-busy');
  static Key typeKey(String type) => ValueKey('slip-type-$type');
  static Key rowKey(int index) => ValueKey('slip-row-$index');

  static const String runLabel = 'ตรวจสอบ';
  static const String busyText =
      'กำลังขอผลจากระบบหักหนี้ อาจใช้เวลาหลายวินาที กรุณารอ';
  static const String mismatchLabel = 'ยอดไม่ตรง';
  static const String notInSlipLabel = 'ไม่มีในสลิป';
  static const String allPaidText = 'หักเงินฌาปนกิจได้ครบทุกคน ยอดตรงกับสลิป';
  static const String noChapanaText =
      'ยังไม่มีรายการฌาปนกิจของงวดนี้ในระบบหักหนี้ (ฝ่ายบัญชียังไม่ได้นำเข้า)';
  static const String retiredLabel = 'เกษียณ/พ้นสภาพ';
  static const String activeLabel = 'ปัจจุบัน';

  @override
  State<ChapanaSlipScreen> createState() => _ChapanaSlipScreenState();
}

class _ChapanaSlipScreenState extends State<ChapanaSlipScreen>
    with FileDownloads<ChapanaSlipScreen> {
  late final DateTime _today = widget.today ?? DateTime.now();
  late int _year = _today.year + 543;
  late int _month = _today.month;
  String _type = EmpType.g;
  Map<String, dynamic>? _data;
  List<Map<String, dynamic>> _items = [];
  bool _checking = false;
  String? _error;
  int _page = 0;
  int _pageSize = 10;

  Map<String, dynamic> get _summary => _data?['summary'] is Map
      ? Map<String, dynamic>.from(_data!['summary'] as Map)
      : const {};

  /// เปลี่ยนงวด/ประเภท: ผลเดิมไม่ตรงกับตัวเลือกแล้ว ต้องกดตรวจสอบใหม่
  void _changed(VoidCallback apply) {
    clearSaved();
    setState(() {
      _data = null;
      _items = [];
      _error = null;
      downloadError = null;
      _page = 0;
      apply();
    });
  }

  Future<void> _run() async {
    if (_checking) return;
    clearSaved();
    setState(() {
      _checking = true;
      _error = null;
      downloadError = null;
      _data = null;
      _items = [];
      _page = 0;
    });
    try {
      final data = await widget.apiService.getChapanaSlip(
        type: _type,
        month: _month,
        year: _year,
      );
      if (!mounted) return;
      setState(() {
        _data = data;
        _items = [
          for (final e in data['items'] as List? ?? const [])
            if (e is Map) Map<String, dynamic>.from(e),
        ];
        _checking = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _checking = false;
        _error = e.toString();
      });
    }
  }

  Widget _summaryCard() {
    final s = _summary;
    final slip = _data?['slip'] is Map
        ? Map<String, dynamic>.from(_data!['slip'] as Map)
        : const <String, dynamic>{};
    final notPaid = intOf(s['not_paid']);
    return StepCard(
      key: ChapanaSlipScreen.summaryKey,
      icon: Icons.summarize_outlined,
      title:
          'ผลการเทียบของ${EmpType.nameOf('${_data?['type'] ?? _type}')} '
          'งวด ${Util.thaiMonthName(_month)} $_year',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FactRow(
            'รายการฌาปนกิจทั้งหมด (ยอดที่ต้องการหัก)',
            '${countText(s['chapana_rows'])} คน · ${moneyText(s['chapana_amount'])} บาท',
          ),
          FactRow(
            'หักได้ตรงยอด',
            '${countText(s['matched'])} คน',
            color: AppTheme.successColor,
          ),
          FactRow(
            ChapanaSlipScreen.mismatchLabel,
            '${countText(s['mismatch'])} คน',
            color: intOf(s['mismatch']) > 0 ? AppTheme.warningColor : null,
          ),
          FactRow(
            ChapanaSlipScreen.notInSlipLabel,
            '${countText(s['not_in_slip'])} คน',
            color: intOf(s['not_in_slip']) > 0 ? AppTheme.dangerColor : null,
          ),
          FactRow(
            'รวมที่หักไม่ได้',
            '${countText(notPaid)} คน · ${moneyText(s['not_paid_amount'])} บาท',
            color: notPaid > 0 ? AppTheme.dangerColor : null,
          ),
          if (slip.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'ระบบสลิปภาษีส่งมา ${countText(slip['count'])} คน · '
              'มีในสลิปแต่ไม่อยู่ในรายการฌาปนกิจของงวด ${countText(slip['not_in_chapana'])} คน (ไม่อยู่ในรายงาน)',
              style: screenText(size: 13, color: AppTheme.textSecondary),
            ),
          ],
        ],
      ),
    );
  }

  Widget _text(String text, {int flex = 2, bool right = false}) => Expanded(
    flex: flex,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      child: Text(
        text,
        textAlign: right ? TextAlign.right : TextAlign.left,
        style: screenText(size: 14),
      ),
    ),
  );

  Widget _row(int index, Map<String, dynamic> r) {
    final mismatch = r['status'] == 'MISMATCH';
    final status = r['retired'] == true
        ? ChapanaSlipScreen.retiredLabel
        : ('${r['per_status'] ?? ''}'.trim() == '1'
              ? ChapanaSlipScreen.activeLabel
              : '-');
    String clean(Object? v) => '${v ?? ''}'.trim().isEmpty ? '-' : '$v'.trim();
    return Row(
      key: ChapanaSlipScreen.rowKey(index),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _text(clean(r['member_no'])),
        Expanded(
          flex: 5,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(clean(r['name']), style: screenText(size: 14.5)),
                Text(
                  Util.maskIdcard('${r['idcard'] ?? ''}'),
                  style: screenText(size: 12.5, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
        ),
        _text(
          [
            clean(r['dept_name']),
            if ('${r['org_code'] ?? ''}'.trim().isNotEmpty)
              'รหัสสังกัด ${'${r['org_code']}'.trim()}',
          ].join('\n'),
          flex: 5,
        ),
        _text(status, flex: 3),
        _text(moneyText(r['amount']), flex: 3, right: true),
        _text(moneyText(r['slip_amount']), flex: 3, right: true),
        Expanded(
          flex: 3,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            child: Align(
              alignment: Alignment.centerLeft,
              child: StatusChip(
                mismatch
                    ? ChapanaSlipScreen.mismatchLabel
                    : ChapanaSlipScreen.notInSlipLabel,
                mismatch ? AppTheme.warningColor : AppTheme.dangerColor,
              ),
            ),
          ),
        ),
        _text(clean(r['pay_for']), flex: 5),
      ],
    );
  }

  Widget _table() {
    final pages = (_items.length / _pageSize).ceil();
    final page = _page >= pages ? pages - 1 : _page;
    final start = page * _pageSize;
    final rows = _items.skip(start).take(_pageSize).toList();
    return StepCard(
      key: ChapanaSlipScreen.tableKey,
      icon: Icons.person_off_outlined,
      title: 'ผู้ที่หักเงินฌาปนกิจไม่ได้',
      subtitle:
          'เงินไม่พอให้หัก หรือเกษียณ/พ้นจากการเป็นข้าราชการ-ลูกจ้างประจำปัจจุบันแล้ว '
          '(ข้อมูลต้นทางฌาปนกิจยังไม่ได้ปรับ)',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SheetScroll(
            minWidth: 1160,
            child: SheetCard(
              header: const Row(
                children: [
                  Expanded(flex: 2, child: SheetHead('เลขสมาชิก')),
                  Expanded(flex: 5, child: SheetHead('ชื่อ')),
                  Expanded(flex: 5, child: SheetHead('สังกัด')),
                  Expanded(flex: 3, child: SheetHead('สถานะบุคคล')),
                  Expanded(
                    flex: 3,
                    child: SheetHead('ยอดที่ต้องการหัก', align: TextAlign.right),
                  ),
                  Expanded(
                    flex: 3,
                    child: SheetHead('ยอดในสลิป', align: TextAlign.right),
                  ),
                  Expanded(flex: 3, child: SheetHead('สาเหตุ')),
                  Expanded(flex: 5, child: SheetHead('จ่ายให้กับ')),
                ],
              ),
              rows: [
                for (var i = 0; i < rows.length; i++) _row(start + i, rows[i]),
              ],
            ),
          ),
          const SizedBox(height: 10),
          AppPagination(
            currentPage: page,
            totalPages: pages,
            pageSize: _pageSize,
            summary: 'ทั้งหมด ${countText(_items.length)} คน',
            onPageChanged: (p) => setState(() => _page = p),
            onPageSizeChanged: (s) => setState(() {
              _pageSize = s;
              _page = 0;
            }),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final busy = _checking || downloading != null;
    final data = _data;
    final rows = intOf(_summary['chapana_rows']);
    final notPaid = intOf(_summary['not_paid']);
    return WorkPage(
      group: ChapanaSlipScreen.groupTitle,
      maxWidth: 1240,
      children: [
        const ScreenHeader(
          icon: ChapanaSlipScreen.menuIcon,
          title: 'รายงานฌาปนกิจ-สลิป',
          subtitle:
              'เทียบเงินฌาปนกิจที่ต้องการหัก กับเงินที่หักได้จริงในสลิปเงินเดือน เพื่อหาผู้ที่หักไม่ได้',
          bullets: [
            'ผลมาจากระบบหักหนี้ ตัวเลขตรงกับหน้า "รายงานฌาปนกิจ-สลิป" ของระบบหักหนี้เสมอ',
            'ยอดต้องเท่ากันพอดีจึงถือว่าหักได้ ผลตรวจคำนวณใหม่ทุกครั้งที่กดตรวจสอบ',
          ],
        ),
        const SizedBox(height: 14),
        MonthYearPicker(
          year: _year,
          month: _month,
          enabled: !busy,
          today: _today,
          onChanged: (y, m) => _changed(() {
            _year = y;
            _month = m;
          }),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (final t in EmpType.names.entries)
              ChoiceChip(
                key: ChapanaSlipScreen.typeKey(t.key),
                label: Text(t.value, style: screenText(size: 14)),
                selected: _type == t.key,
                onSelected: busy ? null : (_) => _changed(() => _type = t.key),
              ),
            PrimaryActionButton(
              key: ChapanaSlipScreen.runKey,
              label: _checking ? 'กำลังตรวจสอบ...' : ChapanaSlipScreen.runLabel,
              icon: Icons.fact_check_outlined,
              loading: _checking,
              onPressed: busy ? null : _run,
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_checking) ...[
          const NoticeBar(
            key: ChapanaSlipScreen.busyKey,
            type: NoticeType.info,
            text: ChapanaSlipScreen.busyText,
          ),
          const SizedBox(height: 12),
        ],
        for (final e in [_error, downloadError])
          if (e != null) ...[
            NoticeBar(type: NoticeType.error, text: e),
            const SizedBox(height: 12),
          ],
        if (data != null && rows == 0)
          const NoticeBar(
            key: ChapanaSlipScreen.noChapanaKey,
            type: NoticeType.warning,
            text: ChapanaSlipScreen.noChapanaText,
          )
        else if (data != null) ...[
          if (notPaid == 0) ...[
            const NoticeBar(
              key: ChapanaSlipScreen.allPaidKey,
              type: NoticeType.success,
              title: 'ครบถ้วน',
              text: ChapanaSlipScreen.allPaidText,
            ),
            const SizedBox(height: 12),
          ],
          _summaryCard(),
          const SizedBox(height: 12),
          DownloadButtons(
            key: ChapanaSlipScreen.reportKey,
            label: 'รายงานผู้ที่ไม่ถูกหักเงินฌาปนกิจ (PDF)',
            icon: Icons.picture_as_pdf_outlined,
            busy: downloading == 'rep9',
            // ไม่มีผู้ที่หักไม่ได้ = ไม่มีรายงานให้ออก
            blocked: busy || notPaid == 0,
            saved: savedOf('rep9'),
            canOpen: true,
            onDownload: () => runDownload(
              'rep9',
              () => widget.apiService.downloadChapanaSlipPdf(
                type: _type,
                month: _month,
                year: _year,
              ),
            ),
          ),
          if (notPaid > 0) ...[const SizedBox(height: 12), _table()],
        ],
      ],
    );
  }
}
