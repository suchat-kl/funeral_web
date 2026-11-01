// lib/widgets/screen_parts.dart
// ส่วนประกอบร่วมของหน้าจอที่เปิดจากเมนู (ยกจากระบบสลิปภาษี/หักหนี้)
// หัวเรื่องมีไอคอน การ์ดมุมมนเงาเบา แถบข้อความพื้นสีอ่อน ตัวเลือกปี พ.ศ. / เดือน และปุ่มหลัก
import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../utils/util.dart';

/// ฟอนต์เนื้อความของหน้าจอ
const String kScreenFont = 'NotoSansThai';

/// ฟอนต์หัวเรื่อง
const String kScreenTitleFont = 'Kanit';

/// ตัวหนังสือเนื้อความ (ระบุฟอนต์ไทยเสมอ)
TextStyle screenText({
  double size = 15,
  FontWeight weight = FontWeight.w400,
  Color color = AppTheme.textPrimary,
  FontStyle? style,
}) => TextStyle(
  fontFamily: kScreenFont,
  fontSize: size,
  fontWeight: weight,
  color: color,
  fontStyle: style,
  height: 1.35,
);

/// แถบบนของหน้าจอที่เปิดจากเมนู: ปุ่มปิด + ชื่อเมนู
PreferredSizeWidget screenAppBar(BuildContext context, String title) => AppBar(
  leading: IconButton(
    icon: const Icon(Icons.close, size: 28),
    onPressed: () => Navigator.maybePop(context),
    tooltip: 'ปิด',
  ),
  title: Text(
    title,
    style: const TextStyle(
      fontFamily: kScreenFont,
      fontSize: 18,
      fontWeight: FontWeight.bold,
    ),
  ),
  backgroundColor: AppTheme.primaryColor,
  foregroundColor: Colors.white,
  elevation: 4,
);

/// ส่วนหัวของหน้าจอ: ไอคอนบนพื้นไล่สี ชื่อหน้า คำอธิบาย และรายการย่อย
class ScreenHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final List<String> bullets;

  const ScreenHeader({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.bullets = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppTheme.primaryColor, AppTheme.primaryDark],
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryColor.withValues(alpha: 0.28),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(icon, color: Colors.white, size: 28),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontFamily: kScreenTitleFont,
                  fontSize: 24,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.primaryDark,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 4),
              Text(subtitle, style: screenText(color: AppTheme.textSecondary)),
              for (final b in bullets)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 7, right: 8),
                        child: Icon(
                          Icons.circle,
                          size: 6,
                          color: AppTheme.primaryLight,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          b,
                          style: screenText(
                            size: 14,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// การ์ดเนื้อหาของหนึ่งขั้นตอน: วงกลมเลขขั้น (หรือไอคอน) + หัวข้อ + เนื้อหา
class StepCard extends StatelessWidget {
  /// เลขขั้นตอน null = ใช้ [icon] แทน
  final int? step;
  final IconData? icon;
  final String title;
  final String? subtitle;

  /// ส่วนท้ายแถวหัวข้อ (เช่นปุ่มโหลดใหม่ หรือป้ายสรุป)
  final Widget? trailing;
  final Widget child;

  const StepCard({
    super.key,
    this.step,
    this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.dividerColor),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryDark.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor,
                  shape: BoxShape.circle,
                ),
                child: step != null
                    ? Text(
                        '$step',
                        style: const TextStyle(
                          fontFamily: kScreenTitleFont,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                          height: 1.1,
                        ),
                      )
                    : Icon(icon, size: 18, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text(
                        title,
                        style: TextStyle(
                          fontFamily: kScreenTitleFont,
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.primaryDark,
                          height: 1.25,
                        ),
                      ),
                    ),
                    if (subtitle != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          subtitle!,
                          style: screenText(
                            size: 14,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 8), trailing!],
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

/// ชนิดของแถบข้อความ
enum NoticeType { success, info, warning, error }

/// แถบข้อความพื้นสีอ่อน มีไอคอนตามชนิด ข้อความยาวหลายบรรทัดได้
class NoticeBar extends StatelessWidget {
  final NoticeType type;
  final String text;

  /// หัวข้อตัวหนาเหนือข้อความ (ไม่บังคับ)
  final String? title;
  final VoidCallback? onClose;

  /// ปุ่มท้ายข้อความ (เช่น "เปิดดู")
  final Widget? action;

  const NoticeBar({
    super.key,
    required this.type,
    required this.text,
    this.title,
    this.onClose,
    this.action,
  });

  static (IconData, Color) styleOf(NoticeType type) => switch (type) {
    NoticeType.success => (Icons.check_circle_outline, AppTheme.successColor),
    NoticeType.info => (Icons.info_outline, AppTheme.infoColor),
    NoticeType.warning => (Icons.warning_amber_rounded, AppTheme.warningColor),
    NoticeType.error => (Icons.error_outline, AppTheme.dangerColor),
  };

  @override
  Widget build(BuildContext context) {
    final (icon, color) = styleOf(type);
    return Container(
      decoration: BoxDecoration(
        color: Color.alphaBlend(color.withValues(alpha: 0.09), Colors.white),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null)
                  Text(
                    title!,
                    style: screenText(size: 15, weight: FontWeight.w700),
                  ),
                Text(text, style: screenText(size: 14.5)),
                if (action != null) ...[const SizedBox(height: 8), action!],
              ],
            ),
          ),
          if (onClose != null)
            IconButton(
              tooltip: 'ปิดข้อความ',
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.close, size: 18),
              color: AppTheme.textSecondary,
              onPressed: onClose,
            )
          else
            const SizedBox(width: 8),
        ],
      ),
    );
  }
}

/// ป้ายมุมมน [solid] = พื้นทึบตัวหนังสือขาว ไม่งั้นพื้นสีอ่อน
class StatusChip extends StatelessWidget {
  final String text;
  final Color color;
  final IconData? icon;
  final bool solid;

  const StatusChip(
    this.text,
    this.color, {
    super.key,
    this.icon,
    this.solid = false,
  });

  @override
  Widget build(BuildContext context) {
    final fg = solid ? Colors.white : color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: solid ? color : color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 15, color: fg),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              text,
              style: screenText(size: 12.5, weight: FontWeight.w500, color: fg),
            ),
          ),
        ],
      ),
    );
  }
}

/// ตัวเลือกแบบการ์ด (ใช้แทน radio): ไอคอน ชื่อ คำอธิบาย และเครื่องหมายถูกเมื่อเลือก
///
/// [onTap] เป็น null = เลือกไม่ได้ (จางลง) ใช้คู่กับ [badge] เช่น "เร็ว ๆ นี้"
class ChoiceCard extends StatefulWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final bool selected;
  final String? badge;
  final VoidCallback? onTap;

  /// เน้นเป็นสีแดง (ตัวเลือกนี้เป็นต้นเหตุของข้อผิดพลาดจาก backend)
  final bool hasError;

  const ChoiceCard({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    required this.selected,
    this.badge,
    this.onTap,
    this.hasError = false,
  });

  /// ป้ายของตัวเลือกที่ยังไม่เปิดใช้
  static const String comingSoon = 'เร็ว ๆ นี้';

  @override
  State<ChoiceCard> createState() => _ChoiceCardState();
}

class _ChoiceCardState extends State<ChoiceCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    final selected = widget.selected;
    final accent = widget.hasError
        ? AppTheme.dangerColor
        : AppTheme.primaryColor;
    final borderColor = selected || widget.hasError
        ? accent
        : _hovered && enabled
        ? AppTheme.primaryLight
        : AppTheme.dividerColor;

    return Semantics(
      button: true,
      selected: selected,
      enabled: enabled,
      label: widget.title,
      child: Opacity(
        opacity: enabled ? 1 : 0.6,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          decoration: BoxDecoration(
            color: selected
                ? AppTheme.primaryPale.withValues(alpha: 0.7)
                : enabled
                ? Colors.white
                : AppTheme.surfaceAlt,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor, width: selected ? 2 : 1),
            boxShadow: [
              if (selected || (_hovered && enabled))
                BoxShadow(
                  color: accent.withValues(alpha: selected ? 0.16 : 0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: widget.onTap,
              onHover: (h) => setState(() => _hovered = h),
              child: Padding(
                // ขอบหนา 2 ตอนเลือก ลดระยะในลง 1 ไม่ให้เนื้อหาขยับ
                padding: EdgeInsets.all(selected ? 11 : 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: selected
                            ? accent
                            : AppTheme.primaryColor.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        widget.icon,
                        size: 21,
                        color: selected ? Colors.white : AppTheme.primaryColor,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.title,
                            style: screenText(
                              size: 15.5,
                              weight: selected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: selected
                                  ? AppTheme.primaryDark
                                  : AppTheme.textPrimary,
                            ),
                          ),
                          if (widget.subtitle != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 1),
                              child: Text(
                                widget.subtitle!,
                                style: screenText(
                                  size: 13,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ),
                          if (widget.badge != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 5),
                              child: StatusChip(
                                widget.badge!,
                                AppTheme.neutralColor,
                                icon: Icons.schedule,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      selected
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      size: 20,
                      color: selected ? accent : Colors.grey.shade400,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// จัดลูกเป็นตารางตามความกว้างที่มี ทุกช่องในแถวเดียวกันสูงเท่ากัน
///
/// จำนวนคอลัมน์ = มากที่สุดที่แต่ละช่องยังกว้างไม่น้อยกว่า [minItemWidth] (ไม่เกิน [maxColumns])
class ResponsiveGrid extends StatelessWidget {
  final double minItemWidth;
  final int maxColumns;
  final double spacing;
  final List<Widget> children;

  const ResponsiveGrid({
    super.key,
    required this.minItemWidth,
    required this.children,
    this.maxColumns = 4,
    this.spacing = 10,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final cols = ((c.maxWidth + spacing) / (minItemWidth + spacing))
            .floor()
            .clamp(1, maxColumns);
        final rows = <Widget>[];
        for (var i = 0; i < children.length; i += cols) {
          if (i > 0) rows.add(SizedBox(height: spacing));
          rows.add(
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var j = 0; j < cols; j++) ...[
                    if (j > 0) SizedBox(width: spacing),
                    Expanded(
                      child: i + j < children.length
                          ? children[i + j]
                          : const SizedBox.shrink(),
                    ),
                  ],
                ],
              ),
            ),
          );
        }
        return Column(children: rows);
      },
    );
  }
}

/// ตัวเลือกปี พ.ศ. แบบลูกศรซ้าย/ขวา อยู่ในช่วง [min] - [max]
class YearStepper extends StatelessWidget {
  final int year;
  final int min;
  final int max;
  final bool enabled;
  final ValueChanged<int> onChanged;

  const YearStepper({
    super.key,
    required this.year,
    required this.min,
    required this.max,
    required this.onChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.fieldFillColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.dividerColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'ปีก่อนหน้า',
            icon: const Icon(Icons.chevron_left),
            color: AppTheme.primaryColor,
            onPressed: enabled && year > min ? () => onChanged(year - 1) : null,
          ),
          SizedBox(
            width: 64,
            child: Text(
              '$year',
              key: const ValueKey('year-value'),
              textAlign: TextAlign.center,
              style: screenText(size: 18, weight: FontWeight.w700),
            ),
          ),
          IconButton(
            tooltip: 'ปีถัดไป',
            icon: const Icon(Icons.chevron_right),
            color: AppTheme.primaryColor,
            onPressed: enabled && year < max ? () => onChanged(year + 1) : null,
          ),
        ],
      ),
    );
  }
}

/// ตัวเลือกเดือน 12 ปุ่ม (ชื่อเดือนไทย) คีย์ของแต่ละปุ่มคือ `month-<1-12>`
///
/// [available] ไม่เป็น null = เดือนในชุดนี้มีข้อมูล (มีเครื่องหมายถูก) เดือนที่เหลือเป็นสีจางแต่ยังเลือกได้
class MonthPicker extends StatelessWidget {
  final int selected;
  final ValueChanged<int> onSelected;
  final Set<int>? available;
  final bool enabled;

  /// เลือกได้หลายเดือน: เดือนที่อยู่ในชุดนี้แสดงเป็นเลือกแล้ว (ไม่ดู [selected]) ผู้เรียกสลับเดือนเองใน [onSelected]
  final Set<int>? selectedMonths;

  const MonthPicker({
    super.key,
    required this.selected,
    required this.onSelected,
    this.available,
    this.enabled = true,
    this.selectedMonths,
  });

  @override
  Widget build(BuildContext context) {
    return ResponsiveGrid(
      minItemWidth: 118,
      maxColumns: 6,
      spacing: 8,
      children: [for (var m = 1; m <= 12; m++) _button(m)],
    );
  }

  Widget _button(int month) {
    final isSelected = selectedMonths?.contains(month) ?? month == selected;
    final has = available?.contains(month);
    final faded = has == false && !isSelected;
    final fg = isSelected
        ? Colors.white
        : faded
        ? AppTheme.textSecondary.withValues(alpha: 0.6)
        : AppTheme.textPrimary;
    return Semantics(
      button: true,
      selected: isSelected,
      child: Material(
        key: ValueKey('month-$month'),
        color: isSelected
            ? AppTheme.primaryColor
            : faded
            ? AppTheme.surfaceAlt.withValues(alpha: 0.6)
            : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(
            color: isSelected
                ? AppTheme.primaryColor
                : has == true
                ? AppTheme.primaryLight
                : AppTheme.dividerColor,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: enabled ? () => onSelected(month) : null,
          hoverColor: AppTheme.primaryColor.withValues(alpha: 0.06),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (has == true) ...[
                  Icon(
                    Icons.check_circle,
                    size: 15,
                    color: isSelected ? Colors.white : AppTheme.successColor,
                  ),
                  const SizedBox(width: 4),
                ],
                Flexible(
                  child: Text(
                    Util.thaiMonthName(month),
                    overflow: TextOverflow.ellipsis,
                    style: screenText(
                      size: 14.5,
                      weight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: fg,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// ปุ่มหลักของหน้าจอ ระหว่าง [loading] แสดงวงหมุนแทนไอคอนและกดไม่ได้
class PrimaryActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool loading;
  final VoidCallback? onPressed;
  final Color? color;

  const PrimaryActionButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.loading = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final bg = color ?? AppTheme.primaryColor;
    return ElevatedButton.icon(
      onPressed: loading ? null : onPressed,
      icon: loading
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : Icon(icon, size: 21),
      label: Text(
        label,
        style: screenText(
          size: 16,
          color: Colors.white,
          weight: FontWeight.w500,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: bg,
        foregroundColor: Colors.white,
        disabledBackgroundColor: bg.withValues(alpha: 0.45),
        disabledForegroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: onPressed == null ? 0 : 2,
      ),
    );
  }
}
