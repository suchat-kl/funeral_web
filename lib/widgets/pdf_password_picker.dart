import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../models/receipt.dart';
import 'screen_parts.dart';

/// ตัวเลือกรหัสเปิดไฟล์ PDF ใบเสร็จ: ไม่ใส่ / เลขบัตรประชาชน / วันเกิด / กำหนดเอง
///
/// [options] = วิธีที่ใช้ได้ (ใบเสร็จของผู้อื่นใช้ได้เฉพาะ [PdfPassword.forOthers])
/// ช่องกำหนดเองตรวจ 4–32 ตัว ไม่มีช่องว่างหัวท้าย ผ่าน `Form` ของผู้เรียก — ห้าม log ค่ารหัส
class PdfPasswordPicker extends StatefulWidget {
  final String value;
  final List<String> options;
  final ValueChanged<String> onChanged;
  final TextEditingController customController;
  final bool enabled;

  const PdfPasswordPicker({
    super.key,
    required this.value,
    required this.options,
    required this.onChanged,
    required this.customController,
    this.enabled = true,
  });

  static Key optionKey(String type) => ValueKey('pdf-password-$type');
  static const Key customFieldKey = ValueKey('pdf-password-custom');

  @override
  State<PdfPasswordPicker> createState() => _PdfPasswordPickerState();
}

class _PdfPasswordPickerState extends State<PdfPasswordPicker> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final t in widget.options)
              ChoiceChip(
                key: PdfPasswordPicker.optionKey(t),
                label: Text(
                  PdfPassword.names[t] ?? t,
                  style: screenText(size: 14),
                ),
                selected: widget.value == t,
                onSelected: widget.enabled ? (_) => widget.onChanged(t) : null,
              ),
          ],
        ),
        if (widget.value == PdfPassword.custom) ...[
          const SizedBox(height: 10),
          TextFormField(
            key: PdfPasswordPicker.customFieldKey,
            controller: widget.customController,
            enabled: widget.enabled,
            obscureText: _obscure,
            autocorrect: false,
            enableSuggestions: false,
            style: screenText(),
            validator: PdfPassword.validateCustom,
            decoration: InputDecoration(
              labelText: 'รหัสเปิดไฟล์ (4-32 ตัวอักษร)',
              labelStyle: screenText(color: AppTheme.textSecondary),
              errorStyle: screenText(size: 12.5, color: AppTheme.dangerColor),
              prefixIcon: const Icon(Icons.key),
              suffixIcon: IconButton(
                tooltip: _obscure ? 'แสดงรหัส' : 'ซ่อนรหัส',
                icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
              isDense: true,
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
        const SizedBox(height: 6),
        Text(
          widget.value == PdfPassword.none
              ? 'ไฟล์ PDF จะเปิดได้โดยไม่ต้องใส่รหัส'
              : 'ต้องใส่รหัสนี้ทุกครั้งที่เปิดไฟล์ PDF',
          style: screenText(size: 12.5, color: AppTheme.textSecondary),
        ),
      ],
    );
  }
}
