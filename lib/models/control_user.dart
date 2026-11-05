/// ผู้ใช้หนึ่งบัญชีในเมนูเพิ่มผู้ใช้งานทะเบียนคุม (`GET /api/upload/control-users`)
///
/// บัญชีประเภท U (ลงทะเบียนแบบไม่เป็นสมาชิกแล้วไม่พบใน DPIS) รอเปลี่ยนเป็น N
/// มีเลขบัตรและชื่อ: อยู่ในหน่วยความจำของหน้าจอเท่านั้น ห้าม log
class ControlUser {
  final String id;
  final String username;
  final String? idcard;
  final String fullName;
  final String? personType;
  final String? source;
  final bool active;
  final String? createdAt;

  const ControlUser({
    required this.id,
    required this.username,
    this.idcard,
    this.fullName = '',
    this.personType,
    this.source,
    this.active = true,
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
