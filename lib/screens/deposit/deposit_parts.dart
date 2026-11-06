// ส่วนประกอบร่วมของหน้าจองานเงินฝากฌาปนกิจล่วงหน้า (ตารางแบ่งหน้า ปุ่มส่งออก ช่องเงิน)
import 'package:flutter/material.dart';

import '../../config/theme.dart';
import '../../utils/file_download.dart';
import '../../utils/snackbar_helper.dart';
import '../../widgets/app_pagination.dart';
import '../../widgets/screen_parts.dart';
import '../../widgets/sheet_table.dart';
import '../../widgets/work_parts.dart';

/// ชื่อกลุ่มเมนู
const String depositMemberGroup = 'ข้อมูลสมาชิก';
const String depositGroup = 'ฝากเงินชำระล่วงหน้า';

/// คอลัมน์ของ [PagedSheet]
class SheetColumn {
  final String title;
  final int flex;
  final bool right;

  const SheetColumn(this.title, {this.flex = 2, this.right = false});
}

/// ตารางแบ่งหน้าฝั่งหน้าเว็บ (AppPagination 5/10/15/20) — แถวทั้งหมดโหลดมาครั้งเดียว
class PagedSheet<T> extends StatefulWidget {
  final List<SheetColumn> columns;
  final List<T> items;
  final List<Widget> Function(T item, int no) cells;
  final double minWidth;
  final String emptyText;
  final String unit;

  /// แถวรวมท้ายตาราง (แสดงทุกหน้า) null = ไม่มี
  final List<Widget>? totals;
  final void Function(T item)? onTap;
  final Key Function(T item)? rowKey;
  final int initialPageSize;

  const PagedSheet({
    super.key,
    required this.columns,
    required this.items,
    required this.cells,
    this.minWidth = 900,
    this.emptyText = 'ไม่มีรายการ',
    this.unit = 'รายการ',
    this.totals,
    this.onTap,
    this.rowKey,
    this.initialPageSize = 10,
  });

  @override
  State<PagedSheet<T>> createState() => _PagedSheetState<T>();
}

class _PagedSheetState<T> extends State<PagedSheet<T>> {
  int _page = 0;
  late int _pageSize = widget.initialPageSize;

  @override
  void didUpdateWidget(covariant PagedSheet<T> old) {
    super.didUpdateWidget(old);
    if (!identical(old.items, widget.items)) _page = 0;
  }

  Widget _line(List<Widget> cells, {bool bold = false}) => Row(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      for (var i = 0; i < widget.columns.length; i++)
        Expanded(
          flex: widget.columns[i].flex,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            child: Align(
              alignment: widget.columns[i].right
                  ? Alignment.centerRight
                  : Alignment.centerLeft,
              child: i < cells.length ? cells[i] : const SizedBox.shrink(),
            ),
          ),
        ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final items = widget.items;
    final pages = (items.length / _pageSize).ceil();
    final page = pages == 0 ? 0 : (_page >= pages ? pages - 1 : _page);
    final start = page * _pageSize;
    final rows = items.skip(start).take(_pageSize).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SheetScroll(
          minWidth: widget.minWidth,
          child: SheetCard(
            emptyText: widget.emptyText,
            header: Row(
              children: [
                for (final c in widget.columns)
                  Expanded(
                    flex: c.flex,
                    child: SheetHead(
                      c.title,
                      align: c.right ? TextAlign.right : TextAlign.left,
                    ),
                  ),
              ],
            ),
            rows: [
              for (final (i, item) in rows.indexed)
                widget.onTap == null
                    ? KeyedSubtree(
                        key: widget.rowKey?.call(item),
                        child: _line(widget.cells(item, start + i + 1)),
                      )
                    : InkWell(
                        key: widget.rowKey?.call(item),
                        onTap: () => widget.onTap!(item),
                        child: _line(widget.cells(item, start + i + 1)),
                      ),
              if (widget.totals != null && items.isNotEmpty)
                Container(
                  color: AppTheme.primaryColor.withValues(alpha: 0.05),
                  child: _line(widget.totals!, bold: true),
                ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        AppPagination(
          currentPage: page,
          totalPages: pages < 1 ? 1 : pages,
          pageSize: _pageSize,
          summary: 'ทั้งหมด ${countText(items.length)} ${widget.unit}',
          onPageChanged: (p) => setState(() => _page = p),
          onPageSizeChanged: (s) => setState(() {
            _pageSize = s;
            _page = 0;
          }),
        ),
      ],
    );
  }
}

/// ข้อความในเซลล์
Widget cellText(
  String? text, {
  double size = 14,
  FontWeight? weight,
  Color? color,
}) => Text(
  text == null || text.isEmpty ? '-' : text,
  style: screenText(
    size: size,
    weight: weight ?? FontWeight.w400,
    color: color ?? AppTheme.textPrimary,
  ),
);

/// เงินในเซลล์ (ชิดขวา 2 ตำแหน่ง) — ติดลบเป็นสีแดง
Widget cellMoney(Object? v, {bool bold = false}) {
  final t = moneyText(v);
  return Text(
    t,
    textAlign: TextAlign.right,
    style: screenText(
      size: 14,
      weight: bold ? FontWeight.w700 : FontWeight.w400,
      color: t.startsWith('-') && t != '-'
          ? AppTheme.dangerColor
          : AppTheme.textPrimary,
    ),
  );
}

/// ปุ่มส่งออก Excel: เรียก [load] แล้วส่งไฟล์ให้เบราว์เซอร์
class ExcelButton extends StatefulWidget {
  final Future<DownloadedFile> Function() load;
  final String label;

  const ExcelButton({
    super.key,
    required this.load,
    this.label = 'ส่งออก Excel',
  });

  static const Key buttonKey = ValueKey('deposit-excel');

  @override
  State<ExcelButton> createState() => _ExcelButtonState();
}

class _ExcelButtonState extends State<ExcelButton> {
  bool _busy = false;
  SavedFile? _saved;

  @override
  void dispose() {
    _saved?.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    setState(() => _busy = true);
    try {
      final f = await widget.load();
      _saved?.dispose();
      final saved = FileSaver.instance.save(f);
      if (mounted) setState(() => _saved = saved);
    } catch (e) {
      if (mounted) context.showErrorSnackBar(e.toString());
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) => KeyedSubtree(
    key: ExcelButton.buttonKey,
    child: DownloadButtons(
      label: widget.label,
      icon: Icons.table_view,
      color: AppTheme.successColor,
      busy: _busy,
      saved: _saved,
      onDownload: _run,
    ),
  );
}

/// ชิปยอดรวม "ป้าย: ค่า"
class TotalChip extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;

  const TotalChip(this.label, this.value, {super.key, this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: (color ?? AppTheme.primaryColor).withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '$label  ',
            style: screenText(size: 13.5, color: AppTheme.textSecondary),
          ),
          TextSpan(
            text: value,
            style: screenText(
              size: 15,
              weight: FontWeight.w700,
              color: color ?? AppTheme.primaryDark,
            ),
          ),
        ],
      ),
    ),
  );
}

/// ช่องกรอกแบบเดียวกันทั้งส่วนเงินฝาก
InputDecoration depositInput(String label, {String? hint, Widget? prefix}) =>
    InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: screenText(size: 14, color: AppTheme.textSecondary),
      hintStyle: screenText(size: 14, color: AppTheme.textSecondary),
      prefixIcon: prefix,
      isDense: true,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
    );
