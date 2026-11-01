import 'package:flutter/material.dart';

import '../models/stored_file.dart';
import '../services/api_service.dart';
import '../utils/roles.dart';
import '../utils/util.dart';
import 'account_form.dart';
import 'screen_parts.dart';

/// หน้าต่างแก้รายละเอียดไฟล์ที่นำเข้าแล้ว (ประเภท ชื่อไฟล์ดาวน์โหลด แบบฟอร์มสำหรับ ปี-เดือน) — ไม่เปลี่ยนตัวไฟล์
///
/// คืน [StoredFile] ที่บันทึกแล้ว (กดยกเลิก = null)
class UploadFileDialog extends StatefulWidget {
  final ApiService apiService;
  final String kind;
  final StoredFile file;

  const UploadFileDialog({
    super.key,
    required this.apiService,
    required this.kind,
    required this.file,
  });

  static const Key titleKey = ValueKey('edit-file-title');
  static const Key typeKey = ValueKey('edit-file-type');
  static const Key saveKey = ValueKey('edit-file-save');

  @override
  State<UploadFileDialog> createState() => _UploadFileDialogState();
}

class _UploadFileDialogState extends State<UploadFileDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.file.title);
  late final _type = TextEditingController(text: widget.file.typeFile);
  late int _fileFor = widget.file.fileFor;
  late int _year;
  late int _month;
  bool _busy = false;
  String? _error;

  bool get _monthYear => widget.kind == StoredFile.kindMonthYear;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _year = now.year + 543;
    _month = now.month;
    final m = RegExp(
      r'^(\d{4})-(\d{2})$',
    ).firstMatch(widget.file.yearMonth ?? '');
    if (m != null) {
      _year = int.parse(m.group(1)!);
      _month = int.parse(m.group(2)!);
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _type.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy || !_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final saved = await widget.apiService.updateUploadFile(
        widget.kind,
        widget.file.id,
        typeFile: _type.text,
        title: _title.text,
        fileFor: _fileFor,
        yearMonth: _monthYear ? Util.yearMonth(_year, _month) : null,
      );
      if (!mounted) return;
      Navigator.of(context).pop(saved);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AccountDialogShell(
      icon: Icons.edit_note,
      title: 'แก้ไขรายละเอียดไฟล์',
      subtitle: widget.file.fileName,
      onClose: _busy ? null : () => Navigator.of(context).pop(),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_error != null) ...[
              AccountBanner.error(_error!),
              const SizedBox(height: 12),
            ],
            AccountField(
              key: UploadFileDialog.typeKey,
              label: 'ประเภทไฟล์ (ไม่บังคับ)',
              hint: 'เช่น แบบฟอร์ม / ประกาศ',
              icon: Icons.category_outlined,
              controller: _type,
              enabled: !_busy,
            ),
            const SizedBox(height: 12),
            AccountField(
              key: UploadFileDialog.titleKey,
              label: 'ชื่อไฟล์ดาวน์โหลด',
              hint: 'ชื่อที่ผู้ใช้เห็นในรายการ',
              icon: Icons.title,
              controller: _title,
              enabled: !_busy,
              validator: (v) =>
                  (v ?? '').trim().isEmpty ? 'กรุณากรอกชื่อไฟล์ดาวน์โหลด' : null,
            ),
            const SizedBox(height: 12),
            Text('แบบฟอร์มสำหรับ', style: screenText(weight: FontWeight.w600)),
            const SizedBox(height: 6),
            FileForChips(
              value: _fileFor,
              enabled: !_busy,
              onChanged: (v) => setState(() => _fileFor = v),
            ),
            if (_monthYear) ...[
              const SizedBox(height: 12),
              Text('ปีและเดือน', style: screenText(weight: FontWeight.w600)),
              const SizedBox(height: 6),
              YearStepper(
                year: _year,
                min: 2550,
                max: DateTime.now().year + 544,
                enabled: !_busy,
                onChanged: (y) => setState(() => _year = y),
              ),
              const SizedBox(height: 8),
              MonthPicker(
                selected: _month,
                enabled: !_busy,
                onSelected: (m) => setState(() => _month = m),
              ),
            ],
            const SizedBox(height: 20),
            AccountActionButtons(
              key: UploadFileDialog.saveKey,
              confirmText: 'บันทึก',
              confirmIcon: Icons.save,
              loading: _busy,
              onCancel: () => Navigator.of(context).pop(),
              onConfirm: _save,
            ),
          ],
        ),
      ),
    );
  }
}

/// ตัวเลือก "แบบฟอร์มสำหรับ": ข้าราชการ / ลูกจ้างประจำ / ทั้งหมด
class FileForChips extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;
  final bool enabled;

  const FileForChips({
    super.key,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  static Key chipKey(int v) => ValueKey('file-for-$v');

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 6,
    children: [
      for (final e in FileFor.names.entries)
        ChoiceChip(
          key: chipKey(e.key),
          label: Text(e.value, style: screenText(size: 14)),
          selected: value == e.key,
          onSelected: enabled ? (_) => onChanged(e.key) : null,
        ),
    ],
  );
}
