/// ผู้มีสิทธิ์นำไฟล์เข้าหนึ่งคน (`GET /api/admin/uploaders`) — ชื่อมาจาก DPIS ตอนเพิ่ม
/// หรือผู้ดูแลกรอกเองเมื่อไม่พบใน DPIS ([manualName])
///
/// มีเลขบัตร: หน้าจอแสดงแบบปิดบางส่วน ห้าม log
class Uploader {
  final String id;
  final String idcard;
  final String fullName;

  /// ไม่พบใน DPIS ผู้ดูแลกรอกชื่อเอง
  final bool manualName;
  final String? addedBy;
  final String? addedAt;

  const Uploader({
    required this.id,
    required this.idcard,
    this.fullName = '',
    this.manualName = false,
    this.addedBy,
    this.addedAt,
  });

  factory Uploader.fromJson(Map<String, dynamic> j) => Uploader(
    id: '${j['id'] ?? ''}',
    idcard: '${j['idcard'] ?? ''}',
    fullName: '${j['fullName'] ?? ''}'.trim(),
    manualName: j['manualName'] == true,
    addedBy: j['addedBy'] == null ? null : '${j['addedBy']}',
    addedAt: j['addedAt'] == null ? null : '${j['addedAt']}',
  );
}
