import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../services/api_service.dart';
import '../utils/util.dart';
import '../widgets/app_pagination.dart';
import '../widgets/screen_parts.dart';
import '../widgets/sheet_table.dart';
import '../widgets/work_parts.dart';
import 'chapana_slip_screen.dart' show EmpType;

/// รายงาน › ผู้เกษียณในรายการฌาปนกิจ (rep10) — ผู้นำไฟล์เข้า / ผู้ดูแล
///
/// ผู้เกษียณ/พ้นสภาพที่ยังมีรายการหักฌาปนกิจของงวด (ผลจากระบบหักหนี้ แบบเดียวกับหน้านำเข้าฌาปนกิจของหักหนี้)
/// เลือกงวด → "แสดงรายชื่อ" → ตาราง (ประเภท ชื่อ สังกัด ตำแหน่ง เลขสมาชิก สถานะ) + ปุ่ม PDF
/// **มีเลขบัตรและชื่อ: อยู่ในหน่วยความจำของหน้าจอเท่านั้น ไม่ลง log** เลขบัตรแสดงแบบปิดบางส่วน
class ChapanaRetiredScreen extends StatefulWidget {
  final ApiService apiService;
  final DateTime? today;

  const ChapanaRetiredScreen({super.key, required this.apiService, this.today});

  static const String menuTitle = 'ผู้เกษียณในรายการฌาปนกิจ';
  static const IconData menuIcon = Icons.elderly;
  static const String groupTitle = 'รายงาน';

  static const Key runKey = ValueKey('retired-run');
  static const Key tableKey = ValueKey('retired-table');
  static const Key reportKey = ValueKey('retired-report');
  static const Key emptyKey = ValueKey('retired-empty');

  static const String noRetiredText =
      'ไม่มีผู้เกษียณ/พ้นสภาพในรายการฌาปนกิจของงวดนี้';

  @override
  State<ChapanaRetiredScreen> createState() => _ChapanaRetiredScreenState();
}

class _ChapanaRetiredScreenState extends State<ChapanaRetiredScreen>
    with FileDownloads<ChapanaRetiredScreen> {
  late final DateTime _today = widget.today ?? DateTime.now();
  late int _year = _today.year + 543;
  late int _month = _today.month;
  List<Map<String, dynamic>>? _items;
  bool _loading = false;
  String? _error;
  int _page = 0;
  int _pageSize = 10;

  void _changed(VoidCallback apply) {
    clearSaved();
    setState(() {
      _items = null;
      _error = null;
      downloadError = null;
      _page = 0;
      apply();
    });
  }

  Future<void> _run() async {
    if (_loading) return;
    clearSaved();
    setState(() {
      _loading = true;
      _error = null;
      downloadError = null;
      _items = null;
      _page = 0;
    });
    try {
      final data = await widget.apiService.getChapanaRetired(
        month: _month,
        year: _year,
      );
      if (!mounted) return;
      setState(() {
        _items = [
          for (final e in data['items'] as List? ?? const [])
            if (e is Map) Map<String, dynamic>.from(e),
        ];
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

  String _status(Map<String, dynamic> r) {
    final s = '${r['per_status'] ?? ''}'.trim();
    return switch (s) {
      '1' => 'ปัจจุบัน',
      '2' => 'เกษียณ/พ้นสภาพ',
      '' => '-',
      _ => s,
    };
  }

  Widget _table(List<Map<String, dynamic>> items) {
    final pages = (items.length / _pageSize).ceil();
    final page = pages == 0 ? 0 : (_page >= pages ? pages - 1 : _page);
    final start = page * _pageSize;
    final rows = items.skip(start).take(_pageSize).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SheetScroll(
          minWidth: 760,
          child: SheetCard(
            emptyText: ChapanaRetiredScreen.noRetiredText,
            header: const Row(
              children: [
                Expanded(flex: 6, child: SheetHead('ชื่อ-สกุล')),
                Expanded(flex: 5, child: SheetHead('หน่วยงาน / ตำแหน่ง')),
                Expanded(flex: 2, child: SheetHead('เลขสมาชิก')),
                Expanded(flex: 3, child: SheetHead('สถานะ')),
              ],
            ),
            rows: [
              for (final r in rows)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 6,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${r['title'] ?? ''}${r['name'] ?? ''} ${r['surname'] ?? ''}'
                                    .trim(),
                                style: screenText(size: 14.5),
                              ),
                              Text(
                                '${EmpType.nameOf('${r['type'] ?? ''}')} · '
                                '${Util.maskIdcard('${r['idcard'] ?? ''}')}',
                                style: screenText(
                                  size: 12.5,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 5,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Text(
                            [
                              '${r['divname'] ?? ''}'.trim(),
                              '${r['pos_name'] ?? ''}'.trim(),
                            ].where((s) => s.isNotEmpty).join('\n'),
                            style: screenText(size: 13.5),
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Text(
                            '${r['member_no'] ?? ''}'.trim().isEmpty
                                ? '-'
                                : '${r['member_no']}'.trim(),
                            style: screenText(size: 14),
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Text(_status(r), style: screenText(size: 14)),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        if (items.isNotEmpty) ...[
          const SizedBox(height: 10),
          AppPagination(
            currentPage: page,
            totalPages: pages < 1 ? 1 : pages,
            pageSize: _pageSize,
            summary: 'ทั้งหมด ${countText(items.length)} คน',
            onPageChanged: (p) => setState(() => _page = p),
            onPageSizeChanged: (s) => setState(() {
              _pageSize = s;
              _page = 0;
            }),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final busy = _loading || downloading != null;
    final items = _items;
    return WorkPage(
      group: ChapanaRetiredScreen.groupTitle,
      maxWidth: 1100,
      children: [
        const ScreenHeader(
          icon: ChapanaRetiredScreen.menuIcon,
          title: ChapanaRetiredScreen.menuTitle,
          subtitle:
              'ผู้เกษียณ/พ้นสภาพที่ยังมีรายการหักเงินฌาปนกิจของงวด (ข้อมูลของรายงานแบบที่ 10)',
          bullets: [
            'ผลมาจากระบบหักหนี้ ตามที่ฝ่ายบัญชีนำเข้ารายการฌาปนกิจของงวดไว้',
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
        Align(
          alignment: Alignment.centerLeft,
          child: PrimaryActionButton(
            key: ChapanaRetiredScreen.runKey,
            label: _loading ? 'กำลังโหลด...' : 'แสดงรายชื่อ',
            icon: Icons.manage_search,
            loading: _loading,
            onPressed: busy ? null : _run,
          ),
        ),
        const SizedBox(height: 12),
        for (final e in [_error, downloadError])
          if (e != null) ...[
            NoticeBar(type: NoticeType.error, text: e),
            const SizedBox(height: 12),
          ],
        if (items != null)
          StepCard(
            key: ChapanaRetiredScreen.tableKey,
            icon: Icons.elderly,
            title:
                'ผู้เกษียณ/พ้นสภาพในรายการฌาปนกิจ งวด ${Util.thaiMonthName(_month)} $_year',
            subtitle: '${countText(items.length)} คน',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _table(items),
                const SizedBox(height: 12),
                DownloadButtons(
                  key: ChapanaRetiredScreen.reportKey,
                  label: 'รายงานผู้เกษียณในรายการฌาปนกิจ (PDF)',
                  icon: Icons.picture_as_pdf_outlined,
                  busy: downloading == 'rep10',
                  blocked: busy || items.isEmpty,
                  saved: savedOf('rep10'),
                  canOpen: true,
                  onDownload: () => runDownload(
                    'rep10',
                    () => widget.apiService.downloadChapanaRetiredPdf(
                      month: _month,
                      year: _year,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
