/// ผู้มีสิทธิ์นำไฟล์เข้าหนึ่งคน (`GET /api/admin/uploaders`) — ชื่อและชื่อผู้ใช้มาจากบัญชีที่ลงทะเบียนตอนเพิ่ม
/// (รายการเก่าก่อน 4 พ.ย. 2569 ชื่อมาจาก DPIS และไม่มี [username])
///
/// มีเลขบัตร: หน้าจอแสดงแบบปิดบางส่วน ห้าม log
class Uploader {
  final String id;
  final String idcard;
  final String fullName;
  final String? username;
  final String? addedBy;
  final String? addedAt;

  const Uploader({
    required this.id,
    required this.idcard,
    this.fullName = '',
    this.username,
    this.addedBy,
    this.addedAt,
  });

  factory Uploader.fromJson(Map<String, dynamic> j) => Uploader(
    id: '${j['id'] ?? ''}',
    idcard: '${j['idcard'] ?? ''}',
    fullName: '${j['fullName'] ?? ''}'.trim(),
    username: j['username'] == null ? null : '${j['username']}',
    addedBy: j['addedBy'] == null ? null : '${j['addedBy']}',
    addedAt: j['addedAt'] == null ? null : '${j['addedAt']}',
  );
}
