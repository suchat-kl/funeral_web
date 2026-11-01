// lib/widgets/app_pagination.dart
import 'package:flutter/material.dart';

import '../config/theme.dart';

/// แถบแบ่งหน้ามาตรฐานของระบบ — เลือกแถวต่อหน้า + ปุ่มหมายเลขหน้า
///
/// - ซ้าย: ตัวเลือกแถวต่อหน้า 5/10/15/20
/// - ขวา: หน้าแรก ย้อนกลับ เลขหน้า 5 ปุ่ม ถัดไป หน้าสุดท้าย และ "หน้า x จาก y"
///
/// [currentPage] นับจาก 0 แต่แสดงผลเป็น 1 หน้าจอที่แบ่งหน้าฝั่ง Flutter เอง
/// ส่ง setState ใน callback ส่วนหน้าจอที่ดึงทีละหน้าจาก API ให้โหลดใหม่ใน callback
class AppPagination extends StatelessWidget {
  /// หน้าที่เปิดอยู่ นับจาก 0
  final int currentPage;

  /// จำนวนหน้าทั้งหมด อย่างน้อย 1 แม้ยังไม่มีข้อมูล
  final int totalPages;

  /// แถวต่อหน้าที่เลือกอยู่
  final int pageSize;

  final ValueChanged<int> onPageChanged;
  final ValueChanged<int> onPageSizeChanged;

  /// ข้อความสรุปที่แสดงต่อท้าย เช่น "ทั้งหมด 53 รายการ" — ไม่ส่งมาก็ไม่แสดง
  final String? summary;

  /// ตัวเลือกแถวต่อหน้า — ชุดเดียวกันทั้งระบบ (ค่าเริ่มต้นของทุกหน้า = 10)
  static const List<int> pageSizeOptions = [5, 10, 15, 20];

  /// จำนวนปุ่มเลขหน้าที่แสดงพร้อมกัน
  static const int _windowSize = 5;

  const AppPagination({
    super.key,
    required this.currentPage,
    required this.totalPages,
    required this.pageSize,
    required this.onPageChanged,
    required this.onPageSizeChanged,
    this.summary,
  });

  /// เลขหน้าที่ควรแสดงในหน้าต่าง 5 ปุ่ม
  ///
  /// อยู่ต้นๆ ก็เริ่มที่หน้าแรก อยู่ท้ายๆ ก็ชิดหน้าสุดท้าย นอกนั้นให้หน้าปัจจุบัน
  /// อยู่กลาง
  List<int> get _pageWindow {
    final total = totalPages < 1 ? 1 : totalPages;
    final count = total < _windowSize ? total : _windowSize;
    return List.generate(count, (i) {
      if (total <= _windowSize) return i;
      if (currentPage < 3) return i;
      if (currentPage > total - 3) return total - _windowSize + i;
      return currentPage - 2 + i;
    });
  }

  @override
  Widget build(BuildContext context) {
    final total = totalPages < 1 ? 1 : totalPages;
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 12,
      runSpacing: 8,
      children: [
        _pageSizeField(),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _iconButton(
              icon: Icons.first_page,
              enabled: currentPage > 0,
              onTap: () => onPageChanged(0),
            ),
            _iconButton(
              icon: Icons.chevron_left,
              enabled: currentPage > 0,
              onTap: () => onPageChanged(currentPage - 1),
            ),
            for (final p in _pageWindow) _pageButton(p),
            _iconButton(
              icon: Icons.chevron_right,
              enabled: currentPage < total - 1,
              onTap: () => onPageChanged(currentPage + 1),
            ),
            _iconButton(
              icon: Icons.last_page,
              enabled: currentPage < total - 1,
              onTap: () => onPageChanged(total - 1),
            ),
            const SizedBox(width: 12),
            Text(
              'หน้า ${currentPage + 1} จาก $total',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
            if (summary != null) ...[
              const SizedBox(width: 12),
              Text(
                summary!,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _pageSizeField() {
    return SizedBox(
      width: 120,
      child: DropdownButtonFormField<int>(
        initialValue: pageSize,
        style: const TextStyle(fontFamily: 'NotoSansThai', fontSize: 13),
        decoration: InputDecoration(
          hintText: 'แสดง',
          isDense: true,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true,
          fillColor: AppTheme.fieldFillColor,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 12,
          ),
        ),
        items: [
          for (final s in pageSizeOptions)
            DropdownMenuItem<int>(
              value: s,
              child: Text('$s แถว', style: const TextStyle(fontSize: 13)),
            ),
        ],
        onChanged: (v) {
          if (v != null && v != pageSize) onPageSizeChanged(v);
        },
      ),
    );
  }

  Widget _iconButton({
    required IconData icon,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return IconButton(
      onPressed: enabled ? onTap : null,
      icon: Icon(icon, size: 20),
      padding: const EdgeInsets.all(4),
      constraints: const BoxConstraints(),
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _pageButton(int page) {
    final selected = page == currentPage;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: InkWell(
        onTap: selected ? null : () => onPageChanged(page),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: selected ? AppTheme.primaryColor : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              '${page + 1}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: selected ? Colors.white : AppTheme.textPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
