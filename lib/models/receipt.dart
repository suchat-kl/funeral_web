import '../utils/util.dart';

/// งวดใบเสร็จรับเงินหนึ่งงวดของสมาชิก (`GET /api/receipts/periods`)
///
/// `{receipt_no, receipt_year, month_desc, receipt_date (ค.ศ.)}` — month_desc เช่น "ม.ค. 69 - มิ.ย. 69"
class ReceiptPeriod {
  final String receiptNo;
  final String receiptYear;
  final String monthDesc;
  final String? receiptDate;

  const ReceiptPeriod({
    required this.receiptNo,
    this.receiptYear = '',
    this.monthDesc = '',
    this.receiptDate,
  });

  factory ReceiptPeriod.fromJson(Map<String, dynamic> j) => ReceiptPeriod(
    receiptNo: '${j['receipt_no'] ?? ''}'.trim(),
    receiptYear: '${j['receipt_year'] ?? ''}'.trim(),
    monthDesc: '${j['month_desc'] ?? ''}'.trim(),
    receiptDate: j['receipt_date'] == null ? null : '${j['receipt_date']}',
  );

  /// ป้ายของปุ่ม: ช่วงเดือน (ไม่มี = เลขที่ใบเสร็จ)
  String get label => monthDesc.isNotEmpty ? monthDesc : 'ใบเสร็จ $receiptNo';

  /// วันที่ออกใบเสร็จแบบไทย ไม่มี = null
  String? get dateText {
    final t = Util.thaiDateOf(receiptDate);
    return t == '-' ? null : t;
  }
}

/// ผลค้นสมาชิก (`GET /api/members/search?q=`) สำหรับผู้นำไฟล์เข้า/ผู้ดูแลออกใบเสร็จเงินสดให้ผู้อื่น
/// `{member_no, title, firstname, lastname, org_name, membership}`
class MemberHit {
  final String memberNo;
  final String title;
  final String firstname;
  final String lastname;
  final String orgName;
  final String membership;

  const MemberHit({
    required this.memberNo,
    this.title = '',
    this.firstname = '',
    this.lastname = '',
    this.orgName = '',
    this.membership = '',
  });

  factory MemberHit.fromJson(Map<String, dynamic> j) => MemberHit(
    memberNo: '${j['member_no'] ?? ''}'.trim(),
    title: '${j['title'] ?? ''}'.trim(),
    firstname: '${j['firstname'] ?? ''}'.trim(),
    lastname: '${j['lastname'] ?? ''}'.trim(),
    orgName: '${j['org_name'] ?? ''}'.trim(),
    membership: '${j['membership'] ?? ''}'.trim(),
  );

  String get fullName => '$title$firstname $lastname'.trim();

  /// ยังเป็นสมาชิกอยู่ (ทะเบียนเดิมใช้ 'N' = ปกติ)
  bool get active => membership.isEmpty || membership.toUpperCase() == 'N';

  /// ข้อความในรายการตัวเลือก
  String get display => '$memberNo  $fullName';
}

/// วิธีกำหนดรหัสเปิดไฟล์ PDF ใบเสร็จ (`passwordType`)
class PdfPassword {
  PdfPassword._();

  static const String none = 'none';
  static const String idcard = 'idcard';
  static const String birthdate = 'birthdate';
  static const String custom = 'custom';

  static const Map<String, String> names = {
    none: 'ไม่ใส่รหัส',
    idcard: 'เลขบัตรประชาชน 13 หลัก',
    birthdate: 'วันเกิด (วันเดือนปี พ.ศ. 8 หลัก เช่น 05032533)',
    custom: 'กำหนดรหัสเอง',
  };

  /// วิธีที่ใช้ได้เมื่อออกใบเสร็จของคนอื่น (ผู้นำไฟล์เข้า/ผู้ดูแล) — backend ไม่ให้ใช้เลขบัตร/วันเกิดของผู้ขอ
  static const List<String> forOthers = [none, custom];

  /// วิธีที่ใช้ได้กับใบเสร็จของตัวเอง
  static const List<String> forSelf = [none, idcard, birthdate, custom];

  /// รหัสกำหนดเอง: 4–32 ตัว ไม่มีช่องว่างหัวท้าย ผ่าน = null
  static String? validateCustom(String? v) {
    final s = v ?? '';
    if (s.isEmpty) return 'กรุณากำหนดรหัสเปิดไฟล์';
    if (s.length < 4 || s.length > 32) {
      return 'รหัสเปิดไฟล์ต้องยาว 4 ถึง 32 ตัวอักษร';
    }
    if (s != s.trim()) return 'รหัสเปิดไฟล์ต้องไม่มีช่องว่างหน้าหรือหลัง';
    return null;
  }
}
