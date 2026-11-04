/// ผู้มีสิทธิ์นำไฟล์เข้าหนึ่งคน (`GET /api/admin/uploaders`) — ชื่อมาจาก DPIS ตอนเพิ่ม
/// บัญชีที่ลงทะเบียนด้วยเลขบัตรนี้ หรือผู้ดูแลกรอกเอง (ดู [nameSource])
///
/// มีเลขบัตร: หน้าจอแสดงแบบปิดบางส่วน ห้าม log
class Uploader {
  final String id;
  final String idcard;
  final String fullName;

  static const String sourceDpis = 'DPIS';
  static const String sourceAccount = 'ACCOUNT';
  static const String sourceManual = 'MANUAL';

  /// ที่มาของชื่อ: DPIS / ACCOUNT (บัญชีผู้ใช้) / MANUAL (ผู้ดูแลกรอก) — รายการเก่าไม่มีช่องนี้ = DPIS
  final String nameSource;
  final String? addedBy;
  final String? addedAt;

  const Uploader({
    required this.id,
    required this.idcard,
    this.fullName = '',
    this.nameSource = sourceDpis,
    this.addedBy,
    this.addedAt,
  });

  factory Uploader.fromJson(Map<String, dynamic> j) => Uploader(
    id: '${j['id'] ?? ''}',
    idcard: '${j['idcard'] ?? ''}',
    fullName: '${j['fullName'] ?? ''}'.trim(),
    nameSource: '${j['nameSource'] ?? sourceDpis}',
    addedBy: j['addedBy'] == null ? null : '${j['addedBy']}',
    addedAt: j['addedAt'] == null ? null : '${j['addedAt']}',
  );
}
