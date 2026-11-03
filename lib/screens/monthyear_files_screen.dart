import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../models/stored_file.dart';
import '../services/api_service.dart';
import '../utils/util.dart';
import '../widgets/file_table.dart';
import '../widgets/screen_parts.dart';
import '../widgets/work_parts.dart';

/// ดาวน์โหลด › ทะเบียนคุมรายชื่อ (เข้าสู่ระบบแล้ว) — เลือกปี พ.ศ. + เดือน (ชื่อเดือนไทย) แล้วแสดงตาราง + ดาวน์โหลด
///
/// เลือกได้หลายเดือนในปีเดียวกันแบบหน้ารายงานสลิปของ sliptax (แตะ = เลือก/ยกเลิก ต้องเหลืออย่างน้อยหนึ่งเดือน)
/// ตารางรวมไฟล์ทุกเดือนที่เลือก เลือกมากกว่าหนึ่งเดือนแล้วมีคอลัมน์ปี-เดือน
/// เปิดหน้ามาเลือกเดือนล่าสุดที่มีไฟล์ให้ (`/api/monthyear-files/year-months`) เดือนที่มีไฟล์มีเครื่องหมายถูก
class MonthYearFilesScreen extends StatefulWidget {
  final ApiService apiService;

  /// วันนี้ (เทสต์ส่งวันตายตัว)
  final DateTime? today;

  const MonthYearFilesScreen({super.key, required this.apiService, this.today});

  static const String menuTitle = 'ทะเบียนคุมรายชื่อ';
  static const IconData menuIcon = Icons.list_alt_outlined;
  static const String groupTitle = 'ดาวน์โหลด';

  static const Key selectAllKey = ValueKey('monthyear-months-all');
  static const Key selectLatestKey = ValueKey('monthyear-months-latest');
  static const Key periodCountKey = ValueKey('monthyear-period-count');

  /// ข้อความเดือนที่เลือก เช่น "มกราคม, มีนาคม 2569"
  static String monthsLabel(int year, Iterable<int> months) {
    final list = months.toSet().toList()..sort();
    return '${list.map(Util.thaiMonthName).join(', ')} $year';
  }

  @override
  State<MonthYearFilesScreen> createState() => _MonthYearFilesScreenState();
}

class _MonthYearFilesScreenState extends State<MonthYearFilesScreen>
    with FileDownloads<MonthYearFilesScreen> {
  late final DateTime _today = widget.today ?? DateTime.now();
  late int _year = _today.year + 543;

  /// เดือนที่เลือก มีอย่างน้อยหนึ่งเดือนเสมอ
  late Set<int> _months = {_today.month};
  List<String> _periods = [];
  List<StoredFile> _files = [];
  bool _loading = true;
  String? _error;

  List<int> get _sortedMonths => _months.toList()..sort();

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final periods = await widget.apiService.getMonthYearPeriods();
      if (!mounted) return;
      _periods = periods;
      if (periods.isNotEmpty) {
        final m = RegExp(r'^(\d{4})-(\d{2})$').firstMatch(periods.first);
        if (m != null) {
          _year = int.parse(m.group(1)!);
          _months = {int.parse(m.group(2)!)};
        }
      }
    } catch (_) {
      // โหลดรายการเดือนไม่ได้ ใช้เดือนปัจจุบันไปก่อน (รายการไฟล์ยังโหลดได้)
    }
    await _load();
  }

  /// โหลดไฟล์ทุกเดือนที่เลือก (เส้นเดิมทีละเดือน) แล้วรวมตามลำดับเดือน
  Future<void> _load() async {
    clearSaved();
    setState(() {
      _loading = true;
      _error = null;
      downloadError = null;
    });
    try {
      final lists = await Future.wait([
        for (final m in _sortedMonths)
          widget.apiService.getMonthYearFiles(Util.yearMonth(_year, m)),
      ]);
      if (!mounted) return;
      setState(() {
        _files = [for (final l in lists) ...l];
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _files = [];
        _error = e.toString();
      });
    }
  }

  void _setMonths(Set<int> months) {
    setState(() => _months = months);
    _load();
  }

  /// แตะ = เลือก/ยกเลิก; เดือนสุดท้ายที่เหลือยกเลิกไม่ได้
  void _toggle(int m) {
    if (_months.contains(m)) {
      if (_months.length > 1) _setMonths({..._months}..remove(m));
    } else {
      _setMonths({..._months, m});
    }
  }

  /// เดือนของปีที่เลือกที่มีไฟล์ (null = ไม่ทราบ ไม่ทำสีจาง)
  Set<int>? get _available {
    if (_periods.isEmpty) return null;
    return {
      for (final p in _periods)
        if (p.startsWith('$_year-')) int.parse(p.substring(5)),
    };
  }

  @override
  Widget build(BuildContext context) {
    final available = _available;
    final months = _sortedMonths;
    final multi = months.length > 1;
    return WorkPage(
      group: MonthYearFilesScreen.groupTitle,
      maxWidth: 1200,
      children: [
        const ScreenHeader(
          icon: MonthYearFilesScreen.menuIcon,
          title: MonthYearFilesScreen.menuTitle,
          subtitle:
              'ทะเบียนคุมรายชื่อสมาชิกฌาปนกิจรายเดือน เลือกปีและเดือนแล้วดาวน์โหลด',
        ),
        const SizedBox(height: 14),
        StepCard(
          icon: Icons.event_note,
          title: 'เลือกปีและเดือน',
          subtitle:
              'เดือนที่เลือก: ${MonthYearFilesScreen.monthsLabel(_year, months)}',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _label('ปี พ.ศ.'),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  YearStepper(
                    year: _year,
                    min: 2550,
                    max: _today.year + 543,
                    enabled: !_loading,
                    onChanged: (y) {
                      setState(() => _year = y);
                      _load();
                    },
                  ),
                  if (available != null && available.isNotEmpty)
                    StatusChip(
                      'มีไฟล์ ${available.length} เดือน',
                      AppTheme.successColor,
                      icon: Icons.check_circle,
                      key: MonthYearFilesScreen.periodCountKey,
                    ),
                ],
              ),
              const SizedBox(height: 14),
              _label('เดือน'),
              MonthPicker(
                selected: months.first,
                selectedMonths: _months,
                available: available,
                enabled: !_loading,
                onSelected: _toggle,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (available != null && available.length > 1)
                    TextButton.icon(
                      key: MonthYearFilesScreen.selectAllKey,
                      onPressed: _loading
                          ? null
                          : () => _setMonths({...available}),
                      icon: const Icon(Icons.done_all, size: 18),
                      label: const Text('เลือกทุกเดือนที่มีไฟล์'),
                    ),
                  if (multi)
                    TextButton.icon(
                      key: MonthYearFilesScreen.selectLatestKey,
                      onPressed: _loading
                          ? null
                          : () => _setMonths({
                              (available != null && available.isNotEmpty)
                                  ? (available.toList()..sort()).last
                                  : months.last,
                            }),
                      icon: const Icon(Icons.filter_1, size: 18),
                      label: const Text('เลือกเดือนเดียว'),
                    ),
                ],
              ),
              Text(
                available != null && available.isNotEmpty
                    ? 'แตะเพื่อเลือกหรือยกเลิกได้หลายเดือน — เดือนที่มีเครื่องหมายคือเดือนที่มีไฟล์'
                    : 'แตะเพื่อเลือกหรือยกเลิกได้หลายเดือน',
                style: screenText(size: 13, color: AppTheme.textSecondary),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'ทะเบียนคุมรายชื่อ ${MonthYearFilesScreen.monthsLabel(_year, months)}',
          key: const ValueKey('monthyear-title'),
          style: screenText(
            size: 16,
            weight: FontWeight.w700,
            color: AppTheme.primaryDark,
          ),
        ),
        const SizedBox(height: 8),
        if (downloadError != null) ...[
          NoticeBar(type: NoticeType.error, text: downloadError!),
          const SizedBox(height: 10),
        ],
        if (_loading || _error != null)
          LoadState(loading: _loading, error: _error, onRetry: _load)
        else
          FileTable(
            key: ValueKey('monthyear-$_year-${months.join('_')}'),
            files: _files,
            showYearMonth: multi,
            emptyText: multi
                ? 'ไม่มีทะเบียนคุมรายชื่อของเดือนที่เลือก'
                : 'ไม่มีทะเบียนคุมรายชื่อของเดือนนี้',
            actions: (f) => [
              RowDownloadButton(
                key: ValueKey('download-${f.id}'),
                busy: downloading == f.id,
                enabled: downloading == null,
                onPressed: () => runDownload(
                  f.id,
                  () => widget.apiService.downloadMonthYearFile(f),
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(text, style: screenText(weight: FontWeight.w600)),
  );
}
