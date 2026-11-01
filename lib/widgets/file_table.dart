import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../models/stored_file.dart';
import '../utils/roles.dart';
import 'app_pagination.dart';
import 'screen_parts.dart';
import 'sheet_table.dart';

/// ตารางรายการไฟล์ (แบบฟอร์มทั่วไป / ทะเบียนคุมรายชื่อ / นำไฟล์เข้า) + ค้นหา + แบ่งหน้า (AppPagination)
///
/// ใช้ร่วมกันทั้งหน้าดาวน์โหลด หน้าแรก และหน้านำไฟล์เข้า — ปุ่มท้ายแถวมาจาก [actions]
class FileTable extends StatefulWidget {
  final List<StoredFile> files;

  /// ปุ่มท้ายแถวของแต่ละไฟล์ (เช่น ดาวน์โหลด หรือ แก้ไข/ลบ)
  final List<Widget> Function(StoredFile f) actions;

  /// แสดงช่องค้นหา
  final bool searchable;

  /// แสดงคอลัมน์ "สำหรับ" (ข้าราชการ/ลูกจ้างประจำ/ทั้งหมด)
  final bool showFileFor;

  /// แสดงคอลัมน์ปี-เดือน (ทะเบียนคุม)
  final bool showYearMonth;

  final String emptyText;
  final int initialPageSize;

  const FileTable({
    super.key,
    required this.files,
    required this.actions,
    this.searchable = true,
    this.showFileFor = true,
    this.showYearMonth = false,
    this.emptyText = 'ไม่มีไฟล์',
    this.initialPageSize = 10,
  });

  static const Key searchKey = ValueKey('file-search');
  static Key rowKey(String id) => ValueKey('file-row-$id');

  @override
  State<FileTable> createState() => _FileTableState();
}

class _FileTableState extends State<FileTable> {
  final _search = TextEditingController();
  int _page = 0;
  late int _pageSize = widget.initialPageSize;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<StoredFile> get _filtered {
    final q = _search.text.trim().toLowerCase();
    if (q.isEmpty) return widget.files;
    final words = q.split(RegExp(r'\s+'));
    return [
      for (final f in widget.files)
        if (words.every(f.searchText.contains)) f,
    ];
  }

  Widget _cell(String text, int flex, {TextAlign align = TextAlign.left, bool bold = false}) =>
      Expanded(
        flex: flex,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          child: Text(
            text,
            textAlign: align,
            style: screenText(
              size: 14,
              weight: bold ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final list = _filtered;
    final pages = (list.length / _pageSize).ceil();
    final page = pages == 0 ? 0 : (_page >= pages ? pages - 1 : _page);
    final start = page * _pageSize;
    final rows = list.skip(start).take(_pageSize).toList();
    final narrow = MediaQuery.of(context).size.width < 700;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.searchable) ...[
          TextField(
            key: FileTable.searchKey,
            controller: _search,
            onChanged: (_) => setState(() => _page = 0),
            style: screenText(),
            decoration: InputDecoration(
              hintText: 'ค้นหาชื่อไฟล์ / ประเภท',
              hintStyle: screenText(color: AppTheme.textSecondary),
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _search.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'ล้างคำค้น',
                      icon: const Icon(Icons.clear),
                      onPressed: () => setState(() {
                        _search.clear();
                        _page = 0;
                      }),
                    ),
              isDense: true,
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
        if (narrow)
          SheetCard(
            header: null,
            emptyText: widget.emptyText,
            rows: [for (final f in rows) _narrowRow(f)],
          )
        else
          SheetCard(
            emptyText: widget.emptyText,
            header: Row(
              children: [
                const Expanded(flex: 1, child: SheetHead('ลำดับ')),
                const Expanded(flex: 2, child: SheetHead('ประเภท')),
                const Expanded(flex: 6, child: SheetHead('ชื่อไฟล์')),
                if (widget.showYearMonth)
                  const Expanded(flex: 2, child: SheetHead('ปี-เดือน')),
                if (widget.showFileFor)
                  const Expanded(flex: 2, child: SheetHead('สำหรับ')),
                const Expanded(flex: 2, child: SheetHead('วันที่นำเข้า')),
                const Expanded(
                  flex: 3,
                  child: SheetHead('', align: TextAlign.right),
                ),
              ],
            ),
            rows: [
              for (final f in rows)
                Row(
                  key: FileTable.rowKey(f.id),
                  children: [
                    _cell(f.num > 0 ? '${f.num}' : '-', 1),
                    _cell(f.typeFile.isEmpty ? '-' : f.typeFile, 2),
                    _cell(f.title, 6, bold: true),
                    if (widget.showYearMonth)
                      _cell(f.yearMonth ?? '-', 2),
                    if (widget.showFileFor)
                      _cell(FileFor.nameOf(f.fileFor), 2),
                    _cell(f.uploadedText, 2),
                    Expanded(
                      flex: 3,
                      child: Wrap(
                        alignment: WrapAlignment.end,
                        spacing: 4,
                        children: widget.actions(f),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        if (list.length > AppPagination.pageSizeOptions.first ||
            pages > 1) ...[
          const SizedBox(height: 10),
          AppPagination(
            currentPage: page,
            totalPages: pages < 1 ? 1 : pages,
            pageSize: _pageSize,
            summary: 'ทั้งหมด ${list.length} รายการ',
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

  /// จอแคบ: หนึ่งไฟล์เป็นการ์ดสองบรรทัด ปุ่มอยู่ด้านล่าง
  Widget _narrowRow(StoredFile f) => Padding(
    key: FileTable.rowKey(f.id),
    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(f.title, style: screenText(size: 14.5, weight: FontWeight.w600)),
        Text(
          [
            if (f.typeFile.isNotEmpty) f.typeFile,
            if (widget.showYearMonth && f.yearMonth != null) f.yearMonth!,
            if (widget.showFileFor) 'สำหรับ${FileFor.nameOf(f.fileFor)}',
            f.uploadedText,
          ].join(' · '),
          style: screenText(size: 12.5, color: AppTheme.textSecondary),
        ),
        Wrap(spacing: 4, children: widget.actions(f)),
      ],
    ),
  );
}

/// ปุ่มดาวน์โหลดเล็กในแถวตาราง (หมุนระหว่างโหลด)
class RowDownloadButton extends StatelessWidget {
  final bool busy;
  final bool enabled;
  final VoidCallback onPressed;

  const RowDownloadButton({
    super.key,
    required this.onPressed,
    this.busy = false,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: busy || !enabled ? null : onPressed,
      icon: busy
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.download, size: 18),
      label: Text(
        'ดาวน์โหลด',
        style: screenText(size: 13.5, color: AppTheme.primaryColor),
      ),
    );
  }
}
