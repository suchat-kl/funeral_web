// ชิ้นส่วนร่วมของหน้าจอแบบ "ตารางแก้ไขในแถว" (แนวเดียวกับใบแจ้งค่าอาหารของ HTC)
// ใช้กับ บันทึกข้อมูล (รายการหนี้) ข้อมูลหลัก และเลขบัญชีเงินกู้
import 'package:flutter/material.dart';

import '../config/theme.dart';
import 'screen_parts.dart';

/// พื้นที่ตารางกว้าง: กว้างอย่างน้อย [minWidth] จอแคบกว่านั้นเลื่อนแนวนอนได้ (ไม่บีบคอลัมน์)
class SheetScroll extends StatefulWidget {
  final double minWidth;
  final Widget child;

  /// ตัวเลื่อนแนวนอนจากผู้เรียก (ใช้ผูกหัวตารางที่ตรึงไว้ให้เลื่อนตามกัน) ไม่ส่ง = สร้างเอง
  final ScrollController? controller;

  const SheetScroll({
    super.key,
    required this.minWidth,
    required this.child,
    this.controller,
  });

  @override
  State<SheetScroll> createState() => _SheetScrollState();
}

class _SheetScrollState extends State<SheetScroll> {
  /// แถบเลื่อนที่แสดงค้างต้องผูกกับตัวเลื่อนของตัวเอง
  final ScrollController _own = ScrollController();

  ScrollController get _controller => widget.controller ?? _own;

  @override
  void dispose() {
    _own.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final narrow = c.maxWidth < widget.minWidth;
        return Scrollbar(
          controller: _controller,
          // จอแคบ: แสดงแถบเลื่อนค้างไว้ให้รู้ว่าตารางเลื่อนไปทางขวาได้
          thumbVisibility: narrow,
          child: SingleChildScrollView(
            controller: _controller,
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.only(bottom: narrow ? 10 : 0),
            child: SizedBox(
              width: narrow ? widget.minWidth : c.maxWidth,
              child: widget.child,
            ),
          ),
        );
      },
    );
  }
}

/// การ์ดขาวของตาราง: แถวหัวคอลัมน์ + แถวข้อมูล คั่นด้วยเส้นบาง
class SheetCard extends StatelessWidget {
  /// แถวหัวคอลัมน์ — null = ไม่มีหัวในการ์ด (หัวตารางถูกตรึงไว้นอกการ์ด ดู [SheetPinnedHeader])
  final Widget? header;
  final List<Widget> rows;

  /// ข้อความเมื่อไม่มีแถว
  final String emptyText;

  const SheetCard({
    super.key,
    required this.header,
    required this.rows,
    this.emptyText = 'ไม่มีรายการ',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.dividerColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (header != null)
            Container(
              color: AppTheme.primaryColor.withValues(alpha: 0.06),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: header,
            ),
          if (rows.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                emptyText,
                textAlign: TextAlign.center,
                style: screenText(size: 14.5, color: AppTheme.textSecondary),
              ),
            ),
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) Divider(height: 1, color: AppTheme.dividerColor),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: rows[i],
            ),
          ],
        ],
      ),
    );
  }
}

/// หัวตารางที่ตรึงไว้บนสุดตอนเลื่อนหน้า (ใช้เป็น sliver ใน `CustomScrollView`)
///
/// กว้างเท่าตารางใน [SheetScroll] ([minWidth] เดียวกัน) และเลื่อนแนวนอนตามตาราง:
/// ส่ง [scroll] = ตัวเลื่อนของ `SheetScroll(controller:)` ตัวเดียวกัน หัวตารางจะตามตำแหน่งนั้น (ลากที่หัวเองไม่ได้)
class SheetPinnedHeader extends StatefulWidget {
  final Widget header;
  final double minWidth;
  final double height;

  /// ระยะขอบซ้าย-ขวาของหน้า (เท่ากับของตาราง)
  final double sidePadding;
  final ScrollController scroll;

  const SheetPinnedHeader({
    super.key,
    required this.header,
    required this.minWidth,
    required this.scroll,
    this.height = 72,
    this.sidePadding = 0,
  });

  @override
  State<SheetPinnedHeader> createState() => _SheetPinnedHeaderState();
}

class _SheetPinnedHeaderState extends State<SheetPinnedHeader> {
  final ScrollController _own = ScrollController();

  @override
  void initState() {
    super.initState();
    widget.scroll.addListener(_follow);
  }

  @override
  void didUpdateWidget(SheetPinnedHeader old) {
    super.didUpdateWidget(old);
    if (old.scroll != widget.scroll) {
      old.scroll.removeListener(_follow);
      widget.scroll.addListener(_follow);
    }
  }

  void _follow() {
    if (!_own.hasClients || !widget.scroll.hasClients) return;
    final target = widget.scroll.offset.clamp(
      0.0,
      _own.position.maxScrollExtent,
    );
    if (_own.offset != target) _own.jumpTo(target);
  }

  @override
  void dispose() {
    widget.scroll.removeListener(_follow);
    _own.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SliverPersistentHeader(
    pinned: true,
    delegate: _PinnedDelegate(
      height: widget.height,
      child: Container(
        // ทึบ: แถวข้อมูลเลื่อนผ่านใต้หัวตาราง
        color: AppTheme.backgroundColor,
        padding: EdgeInsets.symmetric(horizontal: widget.sidePadding),
        child: LayoutBuilder(
          builder: (context, c) => SingleChildScrollView(
            controller: _own,
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            child: Container(
              width: c.maxWidth < widget.minWidth
                  ? widget.minWidth
                  : c.maxWidth,
              height: widget.height,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(8),
                ),
                border: Border.all(color: AppTheme.dividerColor),
              ),
              clipBehavior: Clip.antiAlias,
              child: Container(
                color: AppTheme.primaryColor.withValues(alpha: 0.06),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                alignment: Alignment.centerLeft,
                child: widget.header,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _PinnedDelegate extends SliverPersistentHeaderDelegate {
  final double height;
  final Widget child;

  const _PinnedDelegate({required this.height, required this.child});

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlaps) =>
      child;

  @override
  bool shouldRebuild(_PinnedDelegate old) =>
      old.height != height || old.child != child;
}

/// หัวคอลัมน์ ตัวหนาสีธีม [onTap] ไม่เป็น null = กดเพื่อเรียง (มีลูกศรบอกทิศเมื่อ [sorted])
class SheetHead extends StatelessWidget {
  final String text;
  final TextAlign align;
  final VoidCallback? onTap;

  /// null = ไม่ได้เรียงด้วยคอลัมน์นี้, false = น้อยไปมาก, true = มากไปน้อย
  final bool? sorted;

  const SheetHead(
    this.text, {
    super.key,
    this.align = TextAlign.left,
    this.onTap,
    this.sorted,
  });

  @override
  Widget build(BuildContext context) {
    final label = Text(
      text,
      textAlign: align,
      style: screenText(
        size: 13.5,
        weight: FontWeight.w700,
        color: AppTheme.primaryDark,
      ),
    );
    if (onTap == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: label,
      );
    }
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Row(
          mainAxisAlignment: align == TextAlign.right
              ? MainAxisAlignment.end
              : MainAxisAlignment.start,
          children: [
            Flexible(child: label),
            if (sorted != null)
              Icon(
                sorted! ? Icons.arrow_drop_down : Icons.arrow_drop_up,
                size: 18,
                color: AppTheme.primaryDark,
              ),
          ],
        ),
      ),
    );
  }
}

/// ปุ่มเล็กท้ายตาราง — สีตามชนิดงาน (ลบ = แดง, เลือกทั้งหมด = เทา, เพิ่ม = เขียว)
class SheetButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color color;
  final VoidCallback? onPressed;

  const SheetButton(
    this.label, {
    super.key,
    this.icon,
    this.color = AppTheme.neutralColor,
    required this.onPressed,
  });

  /// "ลบที่เลือก" (แดง)
  const SheetButton.delete({super.key, required this.onPressed})
    : label = deleteLabel,
      icon = Icons.delete_outline,
      color = AppTheme.deleteColor;

  /// "เลือกทั้งหมด" (เทา)
  const SheetButton.selectAll({super.key, required this.onPressed})
    : label = selectAllLabel,
      icon = Icons.checklist,
      color = AppTheme.neutralColor;

  /// "เพิ่ม" (เขียว)
  const SheetButton.add({super.key, required this.onPressed})
    : label = addLabel,
      icon = Icons.add,
      color = AppTheme.addColor;

  static const String deleteLabel = 'ลบที่เลือก';
  static const String selectAllLabel = 'เลือกทั้งหมด';
  static const String addLabel = 'เพิ่ม';

  @override
  Widget build(BuildContext context) {
    final style = ElevatedButton.styleFrom(
      backgroundColor: color,
      foregroundColor: Colors.white,
      disabledBackgroundColor: color.withValues(alpha: 0.4),
      disabledForegroundColor: Colors.white70,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      minimumSize: const Size(0, 36),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );
    final text = Text(
      label,
      style: screenText(size: 13.5, color: Colors.white),
    );
    return icon == null
        ? ElevatedButton(onPressed: onPressed, style: style, child: text)
        : ElevatedButton.icon(
            onPressed: onPressed,
            style: style,
            icon: Icon(icon, size: 17),
            label: text,
          );
  }
}

/// การตกแต่งช่องกรอกในแถวของตาราง (เล็ก พื้นขาว ขอบมน)
InputDecoration sheetInput({String? hint, bool error = false}) =>
    InputDecoration(
      isDense: true,
      filled: true,
      fillColor: Colors.white,
      hintText: hint,
      hintStyle: screenText(size: 13.5, color: AppTheme.textSecondary),
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: BorderSide(
          color: error ? AppTheme.dangerColor : AppTheme.dividerColor,
          width: error ? 1.6 : 1,
        ),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
    );

/// ช่องติ๊กหัวคอลัมน์แบบสามสถานะ: เลือกบางแถว = ขีดกลาง กดแล้วเลือก/ยกเลิกทั้งหมด
class SheetHeaderCheckbox extends StatelessWidget {
  final int selected;
  final int total;
  final VoidCallback? onToggle;

  const SheetHeaderCheckbox({
    super.key,
    required this.selected,
    required this.total,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Checkbox(
      tristate: true,
      value: total == 0 || selected == 0
          ? false
          : (selected == total ? true : null),
      onChanged: total == 0 || onToggle == null ? null : (_) => onToggle!(),
    );
  }
}
