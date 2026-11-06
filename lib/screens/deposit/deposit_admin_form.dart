import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../config/theme.dart';
import '../../models/deposit.dart';
import '../../utils/util.dart';
import '../../widgets/screen_parts.dart';
import '../../widgets/thai_date_picker.dart';
import 'deposit_parts.dart';

/// ช่องในฟอร์มแก้ไขข้อมูลย้อนหลัง (เจ้าหน้าที่รับฝากเงินล่วงหน้า/ผู้ดูแลระบบ)
enum AdminFieldType {
  text,
  money,
  signedMoney,
  integer,
  date,
  period,
  check,
  choice,
}

class AdminField {
  final String key;
  final String label;
  final AdminFieldType type;
  final Object? initial;
  final int maxLength;
  final Map<int, String> options;
  final String? hint;

  const AdminField(
    this.key,
    this.label,
    this.type, {
    this.initial,
    this.maxLength = 100,
    this.options = const {},
    this.hint,
  });
}

/// ผลจากฟอร์ม: ค่าที่แก้ (คีย์ตาม [AdminField.key]) + เหตุผล หรือสั่งลบ
class AdminFormResult {
  final Map<String, Object?> values;
  final String reason;
  final bool delete;

  const AdminFormResult(this.values, this.reason, {this.delete = false});
}

/// ฟอร์มแก้ไขข้อมูลย้อนหลัง — ต้องกรอกเหตุผลทุกครั้ง; [deleteText] ไม่ว่าง = มีปุ่มลบ (ยืนยันอีกชั้น)
Future<AdminFormResult?> showAdminForm(
  BuildContext context, {
  required String title,
  String? note,
  required List<AdminField> fields,
  String? deleteText,
  String saveText = 'บันทึกการแก้ไข',
}) => showDialog<AdminFormResult>(
  context: context,
  barrierDismissible: false,
  builder: (_) => _AdminFormDialog(
    title: title,
    note: note,
    fields: fields,
    deleteText: deleteText,
    saveText: saveText,
  ),
);

class _AdminFormDialog extends StatefulWidget {
  final String title;
  final String? note;
  final List<AdminField> fields;
  final String? deleteText;
  final String saveText;

  const _AdminFormDialog({
    required this.title,
    required this.note,
    required this.fields,
    required this.deleteText,
    required this.saveText,
  });

  @override
  State<_AdminFormDialog> createState() => _AdminFormDialogState();
}

class _AdminFormDialogState extends State<_AdminFormDialog> {
  final Map<String, TextEditingController> _text = {};
  final Map<String, Object?> _values = {};
  final _reason = TextEditingController();
  String? _error;
  bool _confirmDelete = false;

  static const Key reasonKey = ValueKey('admin-form-reason');

  @override
  void initState() {
    super.initState();
    for (final f in widget.fields) {
      switch (f.type) {
        case AdminFieldType.text:
        case AdminFieldType.money:
        case AdminFieldType.signedMoney:
        case AdminFieldType.integer:
          _text[f.key] = TextEditingController(
            text: f.initial?.toString() ?? '',
          );
        default:
          _values[f.key] = f.initial;
      }
    }
  }

  @override
  void dispose() {
    for (final c in _text.values) {
      c.dispose();
    }
    _reason.dispose();
    super.dispose();
  }

  Object? _valueOf(AdminField f) {
    switch (f.type) {
      case AdminFieldType.text:
        final v = _text[f.key]!.text.trim();
        return v.isEmpty ? null : v;
      case AdminFieldType.money:
      case AdminFieldType.signedMoney:
        final v = _text[f.key]!.text.trim().replaceAll(',', '');
        return v.isEmpty ? null : v;
      case AdminFieldType.integer:
        return int.tryParse(_text[f.key]!.text.trim());
      default:
        return _values[f.key];
    }
  }

  void _submit({bool delete = false}) {
    final reason = _reason.text.trim();
    if (reason.isEmpty) {
      setState(() => _error = 'กรุณาระบุเหตุผลของการแก้ไข');
      return;
    }
    for (final f in widget.fields) {
      if (f.type == AdminFieldType.money ||
          f.type == AdminFieldType.signedMoney) {
        final v = _valueOf(f) as String?;
        if (v != null && double.tryParse(v) == null) {
          setState(() => _error = '${f.label} ต้องเป็นตัวเลข');
          return;
        }
      }
    }
    Navigator.of(context).pop(
      AdminFormResult(
        {for (final f in widget.fields) f.key: _valueOf(f)},
        reason,
        delete: delete,
      ),
    );
  }

  Widget _field(AdminField f) {
    switch (f.type) {
      case AdminFieldType.text:
        return TextField(
          key: ValueKey('admin-field-${f.key}'),
          controller: _text[f.key],
          maxLength: f.maxLength,
          style: screenText(size: 14),
          decoration: depositInput(f.label, hint: f.hint),
        );
      case AdminFieldType.money:
      case AdminFieldType.signedMoney:
        return TextField(
          key: ValueKey('admin-field-${f.key}'),
          controller: _text[f.key],
          textAlign: TextAlign.right,
          keyboardType: const TextInputType.numberWithOptions(
            decimal: true,
            signed: true,
          ),
          inputFormatters: [
            FilteringTextInputFormatter.allow(
              RegExp(
                f.type == AdminFieldType.signedMoney ? r'[0-9.\-]' : r'[0-9.]',
              ),
            ),
          ],
          style: screenText(size: 14),
          decoration: depositInput(f.label, hint: f.hint),
        );
      case AdminFieldType.integer:
        return TextField(
          key: ValueKey('admin-field-${f.key}'),
          controller: _text[f.key],
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: screenText(size: 14),
          decoration: depositInput(f.label, hint: f.hint),
        );
      case AdminFieldType.date:
        final iso = _values[f.key] as String?;
        return OutlinedButton.icon(
          key: ValueKey('admin-field-${f.key}'),
          onPressed: () async {
            final d = await showThaiDatePicker(
              context,
              iso == null ? null : DateTime.tryParse(iso),
              lastDate: DateTime.now(),
              helpText: f.label,
            );
            if (d != null && mounted) {
              setState(() => _values[f.key] = Util.isoDate(d));
            }
          },
          icon: const Icon(Icons.event),
          label: Text(
            '${f.label}: ${iso == null ? '-' : Util.thaiDateOf(iso)}',
            style: screenText(size: 14),
          ),
        );
      case AdminFieldType.period:
        return PeriodPicker(
          key: ValueKey('admin-field-${f.key}'),
          label: f.label,
          value: _values[f.key] as int?,
          onChanged: (p) => setState(() => _values[f.key] = p),
        );
      case AdminFieldType.check:
        return CheckboxListTile(
          key: ValueKey('admin-field-${f.key}'),
          contentPadding: EdgeInsets.zero,
          value: _values[f.key] == true,
          title: Text(f.label, style: screenText(size: 14)),
          onChanged: (v) => setState(() => _values[f.key] = v ?? false),
        );
      case AdminFieldType.choice:
        return DropdownButtonFormField<int>(
          key: ValueKey('admin-field-${f.key}'),
          initialValue: _values[f.key] as int?,
          decoration: depositInput(f.label),
          items: [
            for (final e in f.options.entries)
              DropdownMenuItem(
                value: e.key,
                child: Text(e.value, style: screenText(size: 14)),
              ),
          ],
          onChanged: (v) => setState(() => _values[f.key] = v),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.title,
        style: screenText(size: 18, weight: FontWeight.w700),
      ),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.note != null) ...[
                NoticeBar(type: NoticeType.info, text: widget.note!),
                const SizedBox(height: 12),
              ],
              for (final f in widget.fields) ...[
                _field(f),
                const SizedBox(height: 10),
              ],
              TextField(
                key: reasonKey,
                controller: _reason,
                maxLength: 200,
                style: screenText(size: 14),
                decoration: depositInput('เหตุผลของการแก้ไข (จำเป็น)'),
              ),
              if (_confirmDelete)
                NoticeBar(
                  type: NoticeType.warning,
                  text:
                      'กด "ยืนยันการลบ" อีกครั้งเพื่อลบรายการนี้ (บันทึกค่าเดิมไว้ในประวัติการแก้ไข)',
                ),
              if (_error != null) ...[
                const SizedBox(height: 6),
                NoticeBar(type: NoticeType.error, text: _error!),
              ],
            ],
          ),
        ),
      ),
      actions: [
        if (widget.deleteText != null)
          TextButton.icon(
            key: const ValueKey('admin-form-delete'),
            onPressed: () {
              if (!_confirmDelete) {
                setState(() => _confirmDelete = true);
              } else {
                _submit(delete: true);
              }
            },
            icon: const Icon(Icons.delete_outline, color: AppTheme.dangerColor),
            label: Text(
              _confirmDelete ? 'ยืนยันการลบ' : widget.deleteText!,
              style: screenText(size: 14, color: AppTheme.dangerColor),
            ),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('ยกเลิก', style: screenText(size: 14)),
        ),
        FilledButton(
          key: const ValueKey('admin-form-save'),
          onPressed: _submit,
          child: Text(
            widget.saveText,
            style: screenText(size: 14, color: Colors.white),
          ),
        ),
      ],
    );
  }
}

/// เลือกเดือน/ปี พ.ศ. ของรายงาน (ปปปปดด) — ช่วงปี 2545 ถึงปีหน้า
class PeriodPicker extends StatelessWidget {
  final String label;
  final int? value;
  final ValueChanged<int?> onChanged;

  const PeriodPicker({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final nowYear = DateTime.now().year + 543;
    final year = value == null ? null : DepositPeriod.year(value!);
    final month = value == null ? null : DepositPeriod.month(value!);
    return InputDecorator(
      decoration: depositInput(label),
      child: Row(
        children: [
          Expanded(
            child: DropdownButton<int?>(
              isExpanded: true,
              underline: const SizedBox.shrink(),
              value: month,
              hint: Text('เดือน', style: screenText(size: 14)),
              items: [
                for (var m = 1; m <= 12; m++)
                  DropdownMenuItem(
                    value: m,
                    child: Text(
                      DepositPeriod.months[m - 1],
                      style: screenText(size: 14),
                    ),
                  ),
              ],
              onChanged: (m) => m == null
                  ? null
                  : onChanged(DepositPeriod.of(year ?? nowYear, m)),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 100,
            child: DropdownButton<int?>(
              isExpanded: true,
              underline: const SizedBox.shrink(),
              value: year,
              hint: Text('ปี', style: screenText(size: 14)),
              items: [
                for (var y = nowYear + 1; y >= 2545; y--)
                  DropdownMenuItem(
                    value: y,
                    child: Text('$y', style: screenText(size: 14)),
                  ),
              ],
              onChanged: (y) =>
                  y == null ? null : onChanged(DepositPeriod.of(y, month ?? 1)),
            ),
          ),
        ],
      ),
    );
  }
}
