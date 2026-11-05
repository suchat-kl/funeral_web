/// ผู้ใช้หนึ่งบัญชีในเมนูเพิ่มผู้ใช้งานทะเบียนคุม (`GET /api/upload/control-users`)
///
/// บัญชีที่ยังใช้เมนูทะเบียนคุมไม่ได้ (ไม่ใช่สมาชิก ไม่ใช่ผู้นำไฟล์เข้า/ผู้ดูแล ไม่มีบทบาท MONTHYEAR)
/// มีเลขบัตรและชื่อ: อยู่ในหน่วยความจำของหน้าจอเท่านั้น ห้าม log
class ControlUser {
  final String id;
  final String username;
  final String? idcard;
  final String fullName;
  final String? personType;
  final String? source;
  final bool active;

  /// ใช้เมนูทะเบียนคุมได้แล้ว (หลังให้สิทธิ์)
  final bool monthYearAccess;
  final String? createdAt;

  const ControlUser({
    required this.id,
    required this.username,
    this.idcard,
    this.fullName = '',
    this.personType,
    this.source,
    this.active = true,
    this.monthYearAccess = false,
    this.createdAt,
  });

  factory ControlUser.fromJson(Map<String, dynamic> j) => ControlUser(
    id: '${j['id'] ?? ''}',
    username: '${j['username'] ?? ''}',
    idcard: j['idcard']?.toString(),
    fullName: '${j['fullName'] ?? ''}'.trim(),
    personType: j['personType']?.toString(),
    source: j['source']?.toString(),
    active: j['active'] != false,
    monthYearAccess: j['monthYearAccess'] == true,
    createdAt: j['createdAt']?.toString(),
  );
}

/// ผลค้นหา: [limited] = ได้ครบเพดานของ backend (500 รายการ) ควรค้นให้แคบลง
class ControlUserList {
  final List<ControlUser> users;
  final bool limited;

  const ControlUserList(this.users, {this.limited = false});

  factory ControlUserList.fromJson(Map<String, dynamic> j) => ControlUserList([
    for (final m in (j['users'] as List? ?? const []))
      if (m is Map) ControlUser.fromJson(Map<String, dynamic>.from(m)),
  ], limited: j['limited'] == true);
}
