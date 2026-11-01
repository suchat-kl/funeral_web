import '../utils/roles.dart';

/// ผู้ใช้หนึ่งบัญชีในหน้าผู้ดูแล › ผู้ใช้ (UserAdminDTO ของ backend)
///
/// ผู้ดูแลแก้ได้เฉพาะ [personType], [assignedRoles], [active], [locked] (ชื่อ เลขบัตร เลขสมาชิกมาจาก ThaID/DPIS/ทะเบียนสมาชิก)
/// มีเลขบัตรและชื่อ: อยู่ในหน่วยความจำของหน้าจอเท่านั้น ห้าม log
class UserAdmin {
  final String id;
  final String username;
  final String? idcard;
  final String fullName;
  final String? memberNo;
  final bool member;
  final bool uploader;

  /// G / E / C หรือ null
  final String? personType;

  /// บทบาทที่ใช้งานจริง (อ่านอย่างเดียว)
  final List<String> roles;

  /// บทบาทที่ผู้ดูแลกำหนด (แก้ได้)
  final List<String> assignedRoles;
  final String? source;
  final bool active;
  final bool locked;
  final bool twoFactorEnabled;
  final bool mustChangePassword;
  final String? lastLogin;
  final String? createdAt;

  const UserAdmin({
    required this.id,
    required this.username,
    this.idcard,
    this.fullName = '',
    this.memberNo,
    this.member = false,
    this.uploader = false,
    this.personType,
    this.roles = const [],
    this.assignedRoles = const [],
    this.source,
    this.active = true,
    this.locked = false,
    this.twoFactorEnabled = false,
    this.mustChangePassword = false,
    this.lastLogin,
    this.createdAt,
  });

  factory UserAdmin.fromJson(Map<String, dynamic> j) => UserAdmin(
    id: '${j['id'] ?? ''}',
    username: '${j['username'] ?? ''}',
    idcard: _str(j['idcard']),
    fullName: '${j['fullName'] ?? ''}'.trim(),
    memberNo: _str(j['memberNo']),
    member: j['member'] == true,
    uploader: j['uploader'] == true,
    personType: PersonType.normalize(j['personType']),
    roles: Roles.listFrom(j['roles']),
    assignedRoles: Roles.listFrom(j['assignedRoles']),
    source: _str(j['source']),
    active: j['active'] != false,
    locked: j['locked'] == true,
    twoFactorEnabled: j['twoFactorEnabled'] == true,
    mustChangePassword: j['mustChangePassword'] == true,
    lastLogin: _str(j['lastLogin']),
    createdAt: _str(j['createdAt']),
  );

  /// สำเนาที่เปลี่ยนสถานะ 2FA (หลังผู้ดูแลปิด 2FA ให้)
  UserAdmin copyWith({bool? twoFactorEnabled}) => UserAdmin(
    id: id,
    username: username,
    idcard: idcard,
    fullName: fullName,
    memberNo: memberNo,
    member: member,
    uploader: uploader,
    personType: personType,
    roles: roles,
    assignedRoles: assignedRoles,
    source: source,
    active: active,
    locked: locked,
    twoFactorEnabled: twoFactorEnabled ?? this.twoFactorEnabled,
    mustChangePassword: mustChangePassword,
    lastLogin: lastLogin,
    createdAt: createdAt,
  );

  /// ตัวข้อมูลของ `PUT /api/admin/users/{id}` — เฉพาะช่องที่ผู้ดูแลแก้ได้
  static Map<String, dynamic> updateBody({
    required String? personType,
    required List<String> assignedRoles,
    required bool active,
    required bool locked,
  }) => {
    'personType': personType,
    'assignedRoles': assignedRoles,
    'active': active,
    'locked': locked,
  };

  static String? _str(Object? v) {
    final s = '${v ?? ''}'.trim();
    return s.isEmpty ? null : s;
  }
}

/// บทบาทหนึ่งรายการจาก `GET /api/admin/roles` (`assignable` = ผู้ดูแลกำหนดให้ได้)
class RoleInfo {
  final String name;
  final String description;
  final bool assignable;

  const RoleInfo({
    required this.name,
    this.description = '',
    this.assignable = false,
  });

  factory RoleInfo.fromJson(Map<String, dynamic> j) => RoleInfo(
    name: Roles.normalize('${j['name'] ?? ''}'),
    description: '${j['description'] ?? ''}'.trim(),
    assignable: j['assignable'] == true,
  );

  /// ชื่อที่แสดง: ชื่อไทยที่หน้าเว็บรู้จัก ไม่รู้จัก = คำอธิบายจาก backend
  String get label {
    final known = Roles.names[name];
    if (known != null) return known;
    return description.isNotEmpty ? description : name;
  }
}

/// หนึ่งหน้าของผลค้นผู้ใช้ (`{users[], currentPage, totalItems, totalPages, pageSize}`)
class UserPage {
  final List<UserAdmin> users;
  final int currentPage;
  final int totalItems;
  final int totalPages;
  final int pageSize;

  const UserPage({
    required this.users,
    this.currentPage = 0,
    this.totalItems = 0,
    this.totalPages = 0,
    this.pageSize = 10,
  });

  factory UserPage.fromJson(Map<String, dynamic> j) {
    int n(Object? v, int d) => v is num ? v.toInt() : int.tryParse('$v') ?? d;
    return UserPage(
      users: [
        for (final u in j['users'] as List? ?? const [])
          if (u is Map) UserAdmin.fromJson(Map<String, dynamic>.from(u)),
      ],
      currentPage: n(j['currentPage'], 0),
      totalItems: n(j['totalItems'], 0),
      totalPages: n(j['totalPages'], 0),
      pageSize: n(j['pageSize'], 10),
    );
  }
}
