import '../utils/roles.dart';
import '../utils/util.dart';

/// ไฟล์หนึ่งรายการของแบบฟอร์มทั่วไป / ทะเบียนคุมรายชื่อ (StoredFile ของ backend)
///
/// `GET /api/public/general-files`, `GET /api/monthyear-files`, `GET /api/upload/{kind}-files`
class StoredFile {
  /// แบบฟอร์มทั่วไป (เส้น `general-files`)
  static const String kindGeneral = 'general';

  /// ทะเบียนคุมรายชื่อ (เส้น `monthyear-files`)
  static const String kindMonthYear = 'monthyear';

  final String id;

  /// ลำดับที่ (backend นับให้)
  final int num;

  /// ประเภทไฟล์ที่แสดง เช่น แบบฟอร์ม / ประกาศ (ว่างได้)
  final String typeFile;

  /// ชื่อไฟล์ดาวน์โหลดที่แสดง
  final String title;

  /// ชื่อไฟล์เดิมตอนอัปโหลด (ใช้เป็นชื่อไฟล์ตอนบันทึก)
  final String fileName;

  /// แบบฟอร์มสำหรับ: 1 ข้าราชการ / 2 ลูกจ้างประจำ / 3 ทั้งหมด ([FileFor])
  final int fileFor;

  /// เฉพาะทะเบียนคุม: ปี พ.ศ.-เดือน เช่น "2569-10"
  final String? yearMonth;
  final int size;
  final String? contentType;
  final String? uploadedBy;

  /// ข้อความเวลาจาก backend (ค.ศ.) แสดงด้วย [Util.thaiDateOf]
  final String? uploadedAt;

  /// ย้ายมาจากระบบเดิม
  final bool legacy;

  const StoredFile({
    required this.id,
    this.num = 0,
    this.typeFile = '',
    required this.title,
    this.fileName = '',
    this.fileFor = FileFor.all,
    this.yearMonth,
    this.size = 0,
    this.contentType,
    this.uploadedBy,
    this.uploadedAt,
    this.legacy = false,
  });

  factory StoredFile.fromJson(Map<String, dynamic> j) => StoredFile(
    id: '${j['id'] ?? ''}',
    num: _int(j['num']),
    typeFile: '${j['typeFile'] ?? ''}'.trim(),
    title: '${j['title'] ?? ''}'.trim(),
    fileName: '${j['fileName'] ?? ''}'.trim(),
    fileFor: _int(j['fileFor'], FileFor.all),
    yearMonth: _str(j['yearMonth']),
    size: _int(j['size']),
    contentType: _str(j['contentType']),
    uploadedBy: _str(j['uploadedBy']),
    uploadedAt: _str(j['uploadedAt']),
    legacy: j['legacy'] == true,
  );

  /// นามสกุลไฟล์ตัวพิมพ์เล็ก (ไม่มี = ว่าง)
  String get extension {
    final i = fileName.lastIndexOf('.');
    return i < 0 ? '' : fileName.substring(i + 1).toLowerCase();
  }

  /// ข้อความค้นหา (ตัวพิมพ์เล็ก) ใช้กรองในตาราง
  String get searchText =>
      '$num $typeFile $title $fileName ${FileFor.nameOf(fileFor)}'
          .toLowerCase();

  /// วันที่นำเข้าแบบไทย
  String get uploadedText => Util.thaiDateOf(uploadedAt);

  // ช่อง [num] บังชื่อชนิด num จึงแยกตรวจ int / double เอง
  static int _int(Object? v, [int fallback = 0]) => v is int
      ? v
      : v is double
      ? v.toInt()
      : int.tryParse('${v ?? ''}') ?? fallback;

  static String? _str(Object? v) {
    final s = '${v ?? ''}'.trim();
    return s.isEmpty ? null : s;
  }
}
