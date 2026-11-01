import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../models/import_result.dart';
import '../models/stored_file.dart';
import '../services/api_service.dart';
import '../utils/file_pick.dart';
import '../utils/util.dart';
import '../widgets/screen_parts.dart';
import '../widgets/work_parts.dart';

/// ผู้ดูแล › นำเข้าข้อมูลเดิม — อัปโหลด CSV ของตาราง funeral_general / funeral_monthyear จากระบบเดิม
///
/// ไฟล์จริงต้องคัดลอกไปไว้ที่โฟลเดอร์ legacy ของ backend ก่อน (backend ตรวจทุกแถวว่ามีไฟล์จริง)
/// รันซ้ำได้ — ข้ามรายการที่นำเข้าแล้ว รายงานผล: แถวทั้งหมด / นำเข้าใหม่ / ซ้ำ / ไฟล์หาย / แถวผิดรูป / ไฟล์ที่ไม่มีแถว
class AdminImportScreen extends StatefulWidget {
  final ApiService apiService;
  final FilePicker? picker;

  const AdminImportScreen({super.key, required this.apiService, this.picker});

  static const String menuTitle = 'นำเข้าข้อมูลเดิม';
  static const IconData menuIcon = Icons.history_edu;
  static const String groupTitle = 'ผู้ดูแล';

  static Key pickKey(String kind) => ValueKey('import-pick-$kind');
  static Key runKey(String kind) => ValueKey('import-run-$kind');
  static Key resultKey(String kind) => ValueKey('import-result-$kind');

  @override
  State<AdminImportScreen> createState() => _AdminImportScreenState();
}

class _AdminImportScreenState extends State<AdminImportScreen> {
  final Map<String, PickedFile> _files = {};
  final Map<String, LegacyImportResult> _results = {};
  final Map<String, String> _errors = {};
  String? _running;

  Future<void> _pick(String kind) async {
    final f = await (widget.picker ?? pickCsvFile)();
    if (f == null || !mounted) return;
    setState(() {
      _errors.remove(kind);
      if (!f.name.toLowerCase().endsWith('.csv')) {
        _files.remove(kind);
        _errors[kind] = 'กรุณาเลือกไฟล์ .csv (ไฟล์ที่เลือก: ${f.name})';
      } else {
        _files[kind] = f;
      }
    });
  }

  Future<void> _run(String kind) async {
    final f = _files[kind];
    if (f == null || _running != null) return;
    setState(() {
      _running = kind;
      _errors.remove(kind);
      _results.remove(kind);
    });
    try {
      final r = await widget.apiService.importLegacy(
        kind,
        bytes: f.bytes,
        fileName: f.name,
      );
      if (!mounted) return;
      setState(() {
        _running = null;
        _results[kind] = r;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _running = null;
        _errors[kind] = e.toString();
      });
    }
  }

  Widget _problems(String title, List<String> items, Color color) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        initiallyExpanded: items.length <= 10,
        title: Text(
          '$title (${items.length})',
          style: screenText(weight: FontWeight.w600, color: color),
        ),
        children: [
          for (final i in items)
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: SelectableText(i, style: screenText(size: 13)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _card(String kind, String title, String table) {
    final f = _files[kind];
    final r = _results[kind];
    final err = _errors[kind];
    final busy = _running != null;
    return StepCard(
      icon: kind == StoredFile.kindGeneral
          ? Icons.description_outlined
          : Icons.list_alt_outlined,
      title: title,
      subtitle: 'CSV UTF-8 ที่ส่งออกจากตาราง $table ของระบบเดิม',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              OutlinedButton.icon(
                key: AdminImportScreen.pickKey(kind),
                onPressed: busy ? null : () => _pick(kind),
                icon: const Icon(Icons.attach_file),
                label: Text('เลือกไฟล์ CSV', style: screenText(size: 14)),
              ),
              Text(
                f == null
                    ? 'ยังไม่ได้เลือกไฟล์'
                    : '${f.name} (${Util.formatFileSize(f.size)})',
                style: screenText(size: 13.5),
              ),
              PrimaryActionButton(
                key: AdminImportScreen.runKey(kind),
                label: _running == kind ? 'กำลังนำเข้า...' : 'นำเข้า',
                icon: Icons.playlist_add_check,
                loading: _running == kind,
                onPressed: busy || f == null ? null : () => _run(kind),
              ),
            ],
          ),
          if (err != null) ...[
            const SizedBox(height: 10),
            NoticeBar(type: NoticeType.error, text: err),
          ],
          if (r != null) ...[
            const SizedBox(height: 12),
            Container(
              key: AdminImportScreen.resultKey(kind),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.backgroundColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FactRow('แถวในไฟล์', '${countText(r.rows)} แถว'),
                  FactRow(
                    'นำเข้าใหม่',
                    '${countText(r.imported)} รายการ',
                    color: AppTheme.successColor,
                  ),
                  FactRow('มีอยู่แล้ว (ข้าม)', '${countText(r.duplicates)} รายการ'),
                  FactRow(
                    'ไฟล์หาย',
                    '${countText(r.missingFiles.length)} รายการ',
                    color: r.missingFiles.isEmpty ? null : AppTheme.dangerColor,
                  ),
                  FactRow(
                    'แถวผิดรูป',
                    '${countText(r.invalidRows.length)} แถว',
                    color: r.invalidRows.isEmpty ? null : AppTheme.dangerColor,
                  ),
                  FactRow(
                    'ไฟล์ที่ไม่มีแถวอ้างถึง',
                    '${countText(r.filesWithoutRow.length)} ไฟล์',
                    color: r.filesWithoutRow.isEmpty ? null : AppTheme.warningColor,
                  ),
                  _problems('ไฟล์หาย', r.missingFiles, AppTheme.dangerColor),
                  _problems('แถวผิดรูป', r.invalidRows, AppTheme.dangerColor),
                  _problems(
                    'ไฟล์ที่ไม่มีแถวอ้างถึง',
                    r.filesWithoutRow,
                    AppTheme.warningColor,
                  ),
                  if (!r.hasProblems) ...[
                    const SizedBox(height: 8),
                    const NoticeBar(
                      type: NoticeType.success,
                      text: 'นำเข้าครบ ไม่มีรายการที่ต้องตรวจ',
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WorkPage(
      group: AdminImportScreen.groupTitle,
      children: [
        const ScreenHeader(
          icon: AdminImportScreen.menuIcon,
          title: AdminImportScreen.menuTitle,
          subtitle: 'ย้ายรายการไฟล์จากระบบเดิมเข้าระบบใหม่ (รันซ้ำได้ ข้ามรายการที่มีแล้ว)',
          bullets: [
            'คัดลอกไฟล์จริงของระบบเดิมไปไว้ที่โฟลเดอร์ข้อมูลเดิมของเครื่องแม่ข่ายก่อน',
            'ระบบตรวจทุกแถวว่ามีไฟล์จริง แถวที่ไฟล์หายจะไม่ถูกนำเข้าและแสดงในรายงานผล',
          ],
        ),
        const SizedBox(height: 14),
        _card(StoredFile.kindGeneral, 'แบบฟอร์มทั่วไป', 'funeral_general'),
        const SizedBox(height: 12),
        _card(StoredFile.kindMonthYear, 'ทะเบียนคุมรายชื่อ', 'funeral_monthyear'),
      ],
    );
  }
}
