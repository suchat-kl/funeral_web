import 'package:intl/intl.dart';

// import 'package:flutter_localizations/flutter_localizations.dart';

class Util {
  Util();

  /// เลขบัตรประชาชน / เลขประจำตัวผู้เสียภาษี 13 หลัก ถูกต้องตามหลักตรวจสอบหรือไม่
  ///
  /// หลักที่ 13 = (11 - (ผลรวมของหลักที่ 1-12 คูณ 13 ลงไปถึง 2) mod 11) mod 10
  /// ใช้จับเลขที่พิมพ์ผิดตอนกรอกเลขบัตรของผู้ใช้งาน (ผูกบัญชีกับ ThaID)
  static bool isValidThaiId(String? value) {
    final d = (value ?? '').replaceAll(RegExp(r'[^0-9]'), '');
    if (d.length != 13) return false;
    var sum = 0;
    for (var i = 0; i < 12; i++) {
      sum += int.parse(d[i]) * (13 - i);
    }
    return (11 - sum % 11) % 10 == int.parse(d[12]);
  }

  // ✅ Thai date display
  static String formatThaiDate(DateTime date) {
    // Format using Thai locale - automatically displays year as 2569
    // return DateFormat.yMMMd('th').format(date);
    // Example output: "30 ก.ค. 2569"
    final thaiYear = date.year + 543;
    return '${date.day} ${thaiMonths[date.month - 1]} $thaiYear';
  }

  /// ชื่อเดือนภาษาไทยแบบเต็ม เรียงมกราคม-ธันวาคม
  static const List<String> thaiMonths = [
    'มกราคม',
    'กุมภาพันธ์',
    'มีนาคม',
    'เมษายน',
    'พฤษภาคม',
    'มิถุนายน',
    'กรกฎาคม',
    'สิงหาคม',
    'กันยายน',
    'ตุลาคม',
    'พฤศจิกายน',
    'ธันวาคม',
  ];

  /// ชื่อเดือนภาษาไทยแบบย่อ เรียง ม.ค.-ธ.ค.
  static const List<String> thaiMonthsShort = [
    'ม.ค.',
    'ก.พ.',
    'มี.ค.',
    'เม.ย.',
    'พ.ค.',
    'มิ.ย.',
    'ก.ค.',
    'ส.ค.',
    'ก.ย.',
    'ต.ค.',
    'พ.ย.',
    'ธ.ค.',
  ];

  /// เดือนย่อ + ปี พ.ศ. 4 หลัก จากข้อความรูป "yyyy-MM" ที่ปีเป็น พ.ศ. เช่น "2568-03" -> "มี.ค. 2568"
  /// (ปีที่น้อยกว่า 2400 ถือเป็น ค.ศ. บวก 543 ให้) ว่าง / ผิดรูป / เดือนนอกช่วง = null
  static String? formatThaiMonthYearShort(String? yearMonth) {
    final m = RegExp(
      r'^(\d{4})-(\d{1,2})$',
    ).firstMatch((yearMonth ?? '').trim());
    if (m == null) return null;
    var year = int.parse(m.group(1)!);
    final month = int.parse(m.group(2)!);
    if (month < 1 || month > 12) return null;
    if (year < 2400) year += 543;
    return '${thaiMonthsShort[month - 1]} $year';
  }

  /// วันที่ไทยแบบยาวพร้อมเวลา เช่น "12 ตุลาคม 2569 เวลา 11:22:09 น."
  static String formatThaiDateTime(DateTime d) =>
      '${formatThaiDate(d)} เวลา ${formatThaiTime(d)}';

  /// เวลา 24 ชั่วโมงถึงวินาที เช่น "11:22:09 น."
  static String formatThaiTime(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.hour)}:${two(d.minute)}:${two(d.second)} น.';
  }

  /// จำนวนเต็มมีจุลภาคคั่นหลักพัน เช่น 155613 -> "155,613"
  static String formatCount(int n) => n.toString().replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => ',',
  );

  /// ชื่อวันในสัปดาห์ เรียงจันทร์-อาทิตย์ ตาม [DateTime.weekday] (1 = จันทร์)
  static const List<String> thaiWeekdays = [
    'จันทร์',
    'อังคาร',
    'พุธ',
    'พฤหัสบดี',
    'ศุกร์',
    'เสาร์',
    'อาทิตย์',
  ];

  /// ชื่อเดือนภาษาไทยของเดือน 1-12 นอกช่วงคืนตัวเลขเดิม (ข้อมูลเดิมที่ผิดรูป)
  static String thaiMonthName(int month) =>
      month >= 1 && month <= 12 ? thaiMonths[month - 1] : '$month';

  /// วันที่ไทยพร้อมวันในสัปดาห์ เช่น "ศุกร์ 16 มกราคม 2569"
  static String formatThaiDateWithWeekday(DateTime date) =>
      '${thaiWeekdays[date.weekday - 1]} ${formatThaiDate(date)}';

  static String formatThaiDateStr(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '-';
    try {
      final date = DateTime.parse(dateStr);
      return formatThaiDate(date);
    } catch (e) {
      return dateStr;
    }
  }

  static String formatChristianDate(DateTime date) {
    return DateFormat('yyyy-MM-dd').format(date);
  }

  static String toBuddhistYearDisplay(DateTime date) {
    final int buddhistYear = date.year + 543;
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/$buddhistYear';
  }

  // Output: "30/07/2569"

  /// ปี พ.ศ. ของวันที่ (ค.ศ. + 543)
  static int buddhistYear(DateTime date) => date.year + 543;

  /// วันที่ ค.ศ. รูป yyyy-MM-dd สำหรับส่ง backend (เช่นวันเกิดที่เลือกจากปฏิทิน พ.ศ.)
  static String isoDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  /// อ่านเวลาที่ backend ส่งมา เช่น "2026-10-28T10:15:00" (เวลาท้องถิ่นไทย ไม่มีเขตเวลา)
  /// มีเขตเวลาติดมา = แปลงเป็นเวลาไทย (UTC+7) ว่าง/ผิดรูป = null
  static DateTime? parseDateTime(Object? value) {
    if (value is! String || value.trim().isEmpty) return null;
    final d = DateTime.tryParse(value.trim());
    if (d == null || !d.isUtc) return d;
    final t = d.add(const Duration(hours: 7));
    return DateTime(t.year, t.month, t.day, t.hour, t.minute, t.second);
  }

  /// วันที่ไทยของข้อความเวลาจาก backend ("28 ตุลาคม 2569") ว่าง/ผิดรูป = "-"
  static String thaiDateOf(Object? value) {
    final d = parseDateTime(value);
    return d == null ? '-' : formatThaiDate(d);
  }

  /// วันที่และเวลาไทยของข้อความเวลาจาก backend ("28 ตุลาคม 2569 10:15 น.") ว่าง/ผิดรูป = "-"
  static String thaiDateTimeOf(Object? value) {
    final d = parseDateTime(value);
    if (d == null) return '-';
    String two(int n) => n.toString().padLeft(2, '0');
    return '${formatThaiDate(d)} ${two(d.hour)}:${two(d.minute)} น.';
  }

  /// ปี พ.ศ. ปัจจุบัน
  static int currentBuddhistYear([DateTime? now]) => (now ?? DateTime.now()).year + 543;

  /// "ปี พ.ศ.-เดือน 2 หลัก" ที่ backend ใช้ เช่น (2569, 10) -> "2569-10"
  static String yearMonth(int buddhistYear, int month) =>
      '$buddhistYear-${month.toString().padLeft(2, '0')}';

  /// ชื่อเดือนเต็ม + ปี พ.ศ. จาก "2569-10" -> "ตุลาคม 2569" ผิดรูป = ค่าเดิม
  static String yearMonthName(String? yearMonth) {
    final m = RegExp(r'^(\d{4})-(\d{1,2})$').firstMatch((yearMonth ?? '').trim());
    if (m == null) return yearMonth ?? '-';
    final month = int.parse(m.group(2)!);
    if (month < 1 || month > 12) return yearMonth!;
    return '${thaiMonths[month - 1]} ${m.group(1)}';
  }

  /// เลขบัตรประชาชนแบบปิดบางส่วน เหลือหลักแรกกับสี่หลักท้าย เช่น "1-xxxx-xxxx5-67-8"
  /// ไม่ครบ 13 หลัก = แสดงเฉพาะสี่ตัวท้าย
  static String maskIdcard(String? idcard) {
    final d = (idcard ?? '').replaceAll(RegExp(r'[^0-9]'), '');
    if (d.length == 13) {
      return '${d[0]}-xxxx-xxxx${d[9]}-${d.substring(10, 12)}-${d[12]}';
    }
    if (d.length <= 4) return d.isEmpty ? '-' : 'xxxx';
    return 'xxxx${d.substring(d.length - 4)}';
  }

  /// ขนาดไฟล์อ่านง่าย เช่น 1536 -> "1.5 KB"
  static String formatFileSize(num? bytes) {
    final b = (bytes ?? 0).toDouble();
    if (b < 1024) return '${b.toInt()} B';
    if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(1)} KB';
    return '${(b / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
