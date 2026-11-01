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
/// เปิดหน้ามาเลือกเดือนล่าสุดที่มีไฟล์ให้ (`/api/monthyear-files/year-months`) เดือนที่มีไฟล์ตัวเลือกเป็นสีเข้ม
class MonthYearFilesScreen extends StatefulWidget {
  final ApiService apiService;

  /// วันนี้ (เทสต์ส่งวันตายตัว)
  final DateTime? today;

  const MonthYearFilesScreen({super.key, required this.apiService, this.today});

  static const String menuTitle = 'ทะเบียนคุมรายชื่อ';
  static const IconData menuIcon = Icons.list_alt_outlined;
  static const String groupTitle = 'ดาวน์โหลด';

  @override
  State<MonthYearFilesScreen> createState() => _MonthYearFilesScreenState();
}

class _MonthYearFilesScreenState extends State<MonthYearFilesScreen>
    with FileDownloads<MonthYearFilesScreen> {
  late final DateTime _today = widget.today ?? DateTime.now();
  late int _year = _today.year + 543;
  late int _month = _today.month;
  List<String> _periods = [];
  List<StoredFile> _files = [];
  bool _loading = true;
  String? _error;

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
          _month = int.parse(m.group(2)!);
        }
      }
    } catch (_) {
      // โหลดรายการเดือนไม่ได้ ใช้เดือนปัจจุบันไปก่อน (รายการไฟล์ยังโหลดได้)
    }
    await _load();
  }

  Future<void> _load() async {
    clearSaved();
    setState(() {
      _loading = true;
      _error = null;
      downloadError = null;
    });
    try {
      final files = await widget.apiService.getMonthYearFiles(
        Util.yearMonth(_year, _month),
      );
      if (!mounted) return;
      setState(() {
        _files = files;
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Text('ปี พ.ศ.', style: screenText(weight: FontWeight.w600)),
                  const SizedBox(width: 12),
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
                ],
              ),
              const SizedBox(height: 10),
              MonthPicker(
                selected: _month,
                available: _available,
                enabled: !_loading,
                onSelected: (m) {
                  setState(() => _month = m);
                  _load();
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'ทะเบียนคุมรายชื่อ ${Util.thaiMonthName(_month)} $_year',
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
            key: ValueKey('monthyear-$_year-$_month'),
            files: _files,
            emptyText: 'ไม่มีทะเบียนคุมรายชื่อของเดือนนี้',
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
}
