// lib/widgets/thai_date_picker.dart
// ตัวเลือกวันที่กลางของระบบ แสดงปีเป็น พ.ศ. ทั้งหัวปฏิทินและตัวเลือกปี
//
// ปฏิทินมาตรฐานของ Flutter (showDatePicker) แสดงปีเป็น ค.ศ. เสมอแม้ตั้ง locale ไทย
// ทั้งระบบจึงใช้ตัวนี้แทน **ห้ามเรียก showDatePicker ตรง ๆ**
import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../utils/util.dart';

const String _font = 'NotoSansThai';

/// เปิดปฏิทินเลือกวันที่แบบ พ.ศ. — คืนวันที่ที่เลือก (ค.ศ. ตามปกติ ไม่มีเวลา) หรือ null เมื่อกดยกเลิก
///
/// ผู้เรียกต้องเช็ค null เองก่อนนำค่าไปใช้ เพื่อแยกว่าผู้ใช้กดยกเลิก หรือตั้งใจเลือกวันเดิม
/// ค่าที่ได้ให้แสดงด้วย `Util.formatThaiDate` และส่ง backend ด้วย `Util.formatChristianDate`
///
/// - [initialDate] null = เปิดที่วันนี้ อยู่นอกช่วงจะถูกปรับเข้าช่วงให้
/// - [firstDate] / [lastDate] ไม่ส่ง = ช่วงงานปกติ พ.ศ. 2560-2580 วันนอกช่วงกดไม่ได้
/// - [startWithYear] จริง = เปิดมาที่ตัวเลือกปีก่อน (เหมาะกับวันที่ที่ต้องย้อนไกล เช่นวันเกิด)
/// - [today] วันที่ถือเป็น "วันนี้" (มีวงเครื่องหมาย) ไม่ส่ง = วันที่จริง เทสต์ส่งวันตายตัวมาได้
Future<DateTime?> showThaiDatePicker(
  BuildContext context,
  DateTime? initialDate, {
  DateTime? firstDate,
  DateTime? lastDate,
  String helpText = 'เลือกวันที่',
  bool startWithYear = false,
  DateTime? today,
}) {
  final first = _dateOnly(firstDate ?? DateTime(2017, 1, 1)); // พ.ศ. 2560
  var last = _dateOnly(lastDate ?? DateTime(2037, 12, 31)); // พ.ศ. 2580
  if (last.isBefore(first)) last = first;
  final now = _dateOnly(today ?? DateTime.now());
  var initial = _dateOnly(initialDate ?? now);
  if (initial.isBefore(first)) initial = first;
  if (initial.isAfter(last)) initial = last;

  return showDialog<DateTime>(
    context: context,
    builder: (_) => ThaiDatePickerDialog(
      initialDate: initial,
      firstDate: first,
      lastDate: last,
      helpText: helpText,
      startWithYear: startWithYear,
      today: now,
    ),
  );
}

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

int _daysInMonth(int year, int month) => DateTime(year, month + 1, 0).day;

enum _Mode { day, year, month }

/// หน้าต่างปฏิทิน พ.ศ. — ปกติเปิดผ่าน [showThaiDatePicker]
///
/// สามมุมมอง: วัน (ตารางเดือน) → แตะชื่อเดือน/ปีที่หัวตาราง → เลือกปี → เลือกเดือน → กลับมาที่วัน
class ThaiDatePickerDialog extends StatefulWidget {
  final DateTime initialDate;
  final DateTime firstDate;
  final DateTime lastDate;
  final String helpText;
  final bool startWithYear;
  final DateTime today;

  const ThaiDatePickerDialog({
    super.key,
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
    required this.today,
    this.helpText = 'เลือกวันที่',
    this.startWithYear = false,
  });

  // ── คีย์ของ widget ใช้หาในเทสต์ ──
  /// ปุ่มชื่อเดือนและปี พ.ศ. ที่หัวตาราง (แตะเพื่อเลือกปี/เดือน)
  static const Key titleKey = ValueKey('tdp-title');

  /// วันที่ที่เลือกอยู่ (แถบหัวหน้าต่าง)
  static const Key selectedKey = ValueKey('tdp-selected');
  static const Key prevKey = ValueKey('tdp-prev');
  static const Key nextKey = ValueKey('tdp-next');
  static const Key okKey = ValueKey('tdp-ok');
  static const Key cancelKey = ValueKey('tdp-cancel');

  /// วันที่ [day] ของเดือนที่แสดงอยู่
  static Key dayKey(int day) => ValueKey('tdp-day-$day');

  /// ปี พ.ศ. [buddhistYear] ในตัวเลือกปี
  static Key yearKey(int buddhistYear) => ValueKey('tdp-year-$buddhistYear');

  /// เดือน 1-12 ในตัวเลือกเดือน
  static Key monthKey(int month) => ValueKey('tdp-month-$month');

  /// หัวคอลัมน์วันในสัปดาห์ เริ่มวันอาทิตย์
  static const List<String> weekdayLabels = [
    'อา',
    'จ',
    'อ',
    'พ',
    'พฤ',
    'ศ',
    'ส',
  ];

  @override
  State<ThaiDatePickerDialog> createState() => _ThaiDatePickerDialogState();
}

class _ThaiDatePickerDialogState extends State<ThaiDatePickerDialog> {
  late DateTime _selected = widget.initialDate;

  /// เดือนที่ตารางแสดงอยู่ (วันที่ 1 ของเดือนนั้น)
  late DateTime _shown = DateTime(_selected.year, _selected.month);
  late _Mode _mode = widget.startWithYear ? _Mode.year : _Mode.day;

  /// ตัวเลื่อนของตัวเลือกปี สร้างใหม่ทุกครั้งที่เปิดตัวเลือกปี ให้เปิดมาเห็นปีที่แสดงอยู่
  late ScrollController _yearScroll = _newYearScroll();

  ScrollController _newYearScroll() {
    final row = (_shown.year - widget.firstDate.year) ~/ _yearColumns;
    // ให้ปีที่แสดงอยู่ราวกลางพื้นที่เลื่อน
    final offset = row * _yearRowHeight - _bodyHeight / 2 + _yearRowHeight / 2;
    return ScrollController(initialScrollOffset: offset < 0 ? 0 : offset);
  }

  void _openYears() {
    _yearScroll.dispose();
    setState(() {
      _yearScroll = _newYearScroll();
      _mode = _Mode.year;
    });
  }

  @override
  void dispose() {
    _yearScroll.dispose();
    super.dispose();
  }

  static const double _bodyHeight = 288;
  static const double _yearRowHeight = 48;
  static const int _yearColumns = 3;

  bool _inRange(DateTime d) =>
      !d.isBefore(widget.firstDate) && !d.isAfter(widget.lastDate);

  /// เดือนนี้มีวันที่เลือกได้อย่างน้อยหนึ่งวัน
  bool _monthInRange(int year, int month) {
    final start = DateTime(year, month);
    final end = DateTime(year, month, _daysInMonth(year, month));
    return !end.isBefore(widget.firstDate) && !start.isAfter(widget.lastDate);
  }

  bool get _canPrev {
    final p = DateTime(_shown.year, _shown.month - 1);
    return _monthInRange(p.year, p.month);
  }

  bool get _canNext {
    final n = DateTime(_shown.year, _shown.month + 1);
    return _monthInRange(n.year, n.month);
  }

  void _shiftMonth(int delta) =>
      setState(() => _shown = DateTime(_shown.year, _shown.month + delta));

  /// ย้ายไปเดือน [month] ของปี [year] และพาวันที่เลือกตามไปด้วย
  /// วันที่เกินจำนวนวันของเดือนใหม่ (เช่น 29 ก.พ. ไปปีที่ไม่ใช่อธิกสุรทิน, 31 ไปเดือนที่มี 30 วัน)
  /// ถูกปรับเป็นวันสุดท้ายของเดือนนั้น แล้วปรับเข้าช่วง first/last
  void _jumpTo(int year, int month) {
    final days = _daysInMonth(year, month);
    var d = DateTime(year, month, _selected.day > days ? days : _selected.day);
    if (d.isBefore(widget.firstDate)) d = widget.firstDate;
    if (d.isAfter(widget.lastDate)) d = widget.lastDate;
    _selected = d;
    _shown = DateTime(d.year, d.month);
  }

  /// เลือกปีแล้วไปเลือกเดือนต่อ (เดือนเดิมถ้ายังอยู่ในช่วง ไม่งั้นเดือนที่ใกล้ที่สุดในช่วง)
  void _pickYear(int year) => setState(() {
    _jumpTo(year, _shown.month);
    _mode = _Mode.month;
  });

  void _pickMonth(int month) => setState(() {
    _jumpTo(_shown.year, month);
    _mode = _Mode.day;
  });

  void _pickDay(int day) =>
      setState(() => _selected = DateTime(_shown.year, _shown.month, day));

  String get _title =>
      '${Util.thaiMonthName(_shown.month)} ${Util.buddhistYear(_shown)}';

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return Dialog(
      backgroundColor: Colors.white,
      clipBehavior: Clip.antiAlias,
      insetPadding: EdgeInsets.symmetric(
        horizontal: width < 400 ? 12 : 40,
        vertical: 24,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        // จอเตี้ยเลื่อนทั้งหน้าต่างได้ ไม่ล้นกรอบ
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(),
              _buildNavBar(),
              SizedBox(
                height: _bodyHeight,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: switch (_mode) {
                    _Mode.day => _buildDays(),
                    _Mode.year => _buildYears(),
                    _Mode.month => _buildMonths(),
                  },
                ),
              ),
              _buildActions(),
            ],
          ),
        ),
      ),
    );
  }

  /// แถบหัว: คำอธิบาย + วันที่ที่เลือกอยู่แบบเต็ม (วันในสัปดาห์ วัน เดือน ปี พ.ศ.)
  Widget _buildHeader() {
    return Container(
      color: AppTheme.primaryColor,
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.helpText,
            style: const TextStyle(
              fontFamily: _font,
              fontSize: 13,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            Util.formatThaiDateWithWeekday(_selected),
            key: ThaiDatePickerDialog.selectedKey,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: _font,
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  /// แถวเลื่อนเดือน: ◀ ชื่อเดือน + ปี พ.ศ. (แตะเพื่อเลือกปี/เดือน) ▶
  Widget _buildNavBar() {
    final dayMode = _mode == _Mode.day;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 6, 4, 2),
      child: Row(
        children: [
          IconButton(
            key: ThaiDatePickerDialog.prevKey,
            tooltip: 'เดือนก่อนหน้า',
            icon: const Icon(Icons.chevron_left),
            color: AppTheme.primaryColor,
            onPressed: dayMode && _canPrev ? () => _shiftMonth(-1) : null,
          ),
          Expanded(
            child: Center(
              child: TextButton(
                key: ThaiDatePickerDialog.titleKey,
                // แตะซ้ำตอนอยู่ในตัวเลือกปี/เดือน = กลับไปตารางวัน
                onPressed: dayMode
                    ? _openYears
                    : () => setState(() => _mode = _Mode.day),
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.primaryDark,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        _title,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: _font,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Icon(
                      dayMode ? Icons.arrow_drop_down : Icons.arrow_drop_up,
                      size: 22,
                    ),
                  ],
                ),
              ),
            ),
          ),
          IconButton(
            key: ThaiDatePickerDialog.nextKey,
            tooltip: 'เดือนถัดไป',
            icon: const Icon(Icons.chevron_right),
            color: AppTheme.primaryColor,
            onPressed: dayMode && _canNext ? () => _shiftMonth(1) : null,
          ),
        ],
      ),
    );
  }

  /// ตารางวันของเดือนที่แสดง สัปดาห์เริ่มวันอาทิตย์
  Widget _buildDays() {
    final year = _shown.year;
    final month = _shown.month;
    final days = _daysInMonth(year, month);
    // DateTime.weekday: จันทร์ = 1 ... อาทิตย์ = 7 → คอลัมน์ของวันที่ 1 (อาทิตย์ = 0)
    final offset = DateTime(year, month, 1).weekday % 7;

    Widget cell(int index) {
      final day = index - offset + 1;
      if (day < 1 || day > days) return const SizedBox.shrink();
      final date = DateTime(year, month, day);
      return _DayCell(
        key: ThaiDatePickerDialog.dayKey(day),
        day: day,
        label: Util.formatThaiDateWithWeekday(date),
        selected: date == _selected,
        today: date == widget.today,
        enabled: _inRange(date),
        onTap: () => _pickDay(day),
      );
    }

    return Column(
      children: [
        SizedBox(
          height: 32,
          child: Row(
            children: [
              for (final w in ThaiDatePickerDialog.weekdayLabels)
                Expanded(
                  child: Center(
                    child: Text(
                      w,
                      style: const TextStyle(
                        fontFamily: _font,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        for (var row = 0; row < 6; row++)
          Expanded(
            child: Row(
              children: [
                for (var col = 0; col < 7; col++)
                  Expanded(child: cell(row * 7 + col)),
              ],
            ),
          ),
      ],
    );
  }

  /// ตัวเลือกปี พ.ศ. ทุกปีในช่วง first-last เลื่อนได้ เปิดมาเห็นปีที่แสดงอยู่
  Widget _buildYears() {
    final firstYear = widget.firstDate.year;
    final count = widget.lastDate.year - firstYear + 1;
    return GridView.builder(
      controller: _yearScroll,
      padding: const EdgeInsets.symmetric(vertical: 4),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: _yearColumns,
        mainAxisExtent: _yearRowHeight,
      ),
      itemCount: count,
      itemBuilder: (context, i) {
        final year = firstYear + i;
        return _ChoiceCell(
          key: ThaiDatePickerDialog.yearKey(year + 543),
          text: '${year + 543}',
          selected: year == _shown.year,
          marked: year == widget.today.year,
          onTap: () => _pickYear(year),
        );
      },
    );
  }

  /// ตัวเลือกเดือน 12 เดือนของปีที่เลือก เดือนที่อยู่นอกช่วงกดไม่ได้
  Widget _buildMonths() {
    return Column(
      children: [
        for (var row = 0; row < 4; row++)
          Expanded(
            child: Row(
              children: [
                for (var col = 0; col < 3; col++)
                  Expanded(
                    child: Builder(
                      builder: (context) {
                        final month = row * 3 + col + 1;
                        return _ChoiceCell(
                          key: ThaiDatePickerDialog.monthKey(month),
                          text: Util.thaiMonthName(month),
                          selected: month == _shown.month,
                          marked:
                              _shown.year == widget.today.year &&
                              month == widget.today.month,
                          onTap: _monthInRange(_shown.year, month)
                              ? () => _pickMonth(month)
                              : null,
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildActions() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            key: ThaiDatePickerDialog.cancelKey,
            onPressed: () => Navigator.of(context).pop(),
            style: TextButton.styleFrom(foregroundColor: AppTheme.cancelColor),
            child: const Text(
              'ยกเลิก',
              style: TextStyle(fontFamily: _font, fontSize: 15),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            key: ThaiDatePickerDialog.okKey,
            onPressed: () => Navigator.of(context).pop(_selected),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
            ),
            child: const Text(
              'ตกลง',
              style: TextStyle(
                fontFamily: _font,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// หนึ่งวันในตาราง: วงกลมทึบ = วันที่เลือก วงกลมเส้นขอบ = วันนี้ สีจาง = นอกช่วง (กดไม่ได้)
/// โฟกัสด้วยปุ่ม Tab และกด Enter/Space เพื่อเลือกได้ (วันที่เลือกอยู่ได้โฟกัสตอนเปิด)
class _DayCell extends StatelessWidget {
  final int day;

  /// วันที่เต็มสำหรับโปรแกรมอ่านหน้าจอ เช่น "ศุกร์ 16 มกราคม 2569"
  final String label;
  final bool selected;
  final bool today;
  final bool enabled;
  final VoidCallback onTap;

  const _DayCell({
    super.key,
    required this.day,
    required this.label,
    required this.selected,
    required this.today,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final primary = AppTheme.primaryColor;
    final color = !enabled
        ? Colors.grey.shade400
        : selected
        ? Colors.white
        : today
        ? primary
        : AppTheme.textPrimary;
    return Center(
      child: Semantics(
        button: true,
        enabled: enabled,
        selected: selected,
        label: label,
        excludeSemantics: true,
        child: Material(
          color: selected ? primary : Colors.transparent,
          shape: CircleBorder(
            side: today && !selected
                ? BorderSide(color: primary, width: 1.5)
                : BorderSide.none,
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            autofocus: selected,
            onTap: enabled ? onTap : null,
            focusColor: primary.withValues(alpha: 0.18),
            hoverColor: primary.withValues(alpha: 0.08),
            child: SizedBox(
              width: 36,
              height: 36,
              child: Center(
                child: Text(
                  '$day',
                  style: TextStyle(
                    fontFamily: _font,
                    fontSize: 14.5,
                    fontWeight: selected || today
                        ? FontWeight.w700
                        : FontWeight.w400,
                    color: color,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// หนึ่งช่องของตัวเลือกปี/เดือน: พื้นทึบ = ค่าที่เลือกอยู่ เส้นขอบ = ปี/เดือนปัจจุบัน
/// [onTap] เป็น null = นอกช่วง กดไม่ได้
class _ChoiceCell extends StatelessWidget {
  final String text;
  final bool selected;
  final bool marked;
  final VoidCallback? onTap;

  const _ChoiceCell({
    super.key,
    required this.text,
    required this.selected,
    required this.marked,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final primary = AppTheme.primaryColor;
    final enabled = onTap != null;
    return Padding(
      padding: const EdgeInsets.all(4),
      child: Material(
        color: selected ? primary : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: marked && !selected
              ? BorderSide(color: primary, width: 1.5)
              : BorderSide.none,
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          autofocus: selected,
          onTap: onTap,
          focusColor: primary.withValues(alpha: 0.18),
          hoverColor: primary.withValues(alpha: 0.08),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  text,
                  maxLines: 1,
                  style: TextStyle(
                    fontFamily: _font,
                    fontSize: 14.5,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: !enabled
                        ? Colors.grey.shade400
                        : selected
                        ? Colors.white
                        : AppTheme.textPrimary,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
