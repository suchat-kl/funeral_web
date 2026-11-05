// บทบาทของระบบฌาปนกิจ และสิทธิ์เห็นเมนูตามบทบาท (ข้อกำหนดหัวข้อ 2)

/// บทบาทที่ backend ส่งมาใน `roles[]` เป็นชื่อสั้น (ไม่มี ROLE_)
///
/// **ไม่ใช่ enum ปิด**: backend เพิ่มบทบาทใหม่ได้ภายหลัง (เช่นเจ้าหน้าที่รับฝากเงินล่วงหน้า)
/// หน้าเว็บเก็บ roles เป็นรายการข้อความตามที่ได้รับ บทบาทที่ไม่รู้จักแสดงชื่อตามรหัสเดิม
/// เพิ่มบทบาทใหม่: เพิ่มค่าคงที่ ชื่อไทยใน [names] และลำดับใน [order] แล้วเพิ่มเงื่อนไขเมนูใน [MenuAccess]
class Roles {
  Roles._();

  /// ไม่ใช่สมาชิกฌาปนกิจ (ระบบตั้งเองจากการตรวจทะเบียนสมาชิกทุกครั้งที่เข้าสู่ระบบ)
  static const String nonMember = 'NON_MEMBER';

  /// สมาชิกฌาปนกิจ (ระบบตั้งเอง — มีได้อย่างใดอย่างหนึ่งกับ [nonMember])
  static const String member = 'MEMBER';

  /// ผู้นำไฟล์เข้าระบบ (ระบบตั้งเองจากรายชื่อผู้มีสิทธิ์นำไฟล์เข้า)
  static const String uploader = 'UPLOADER';

  /// ผู้ดูแลระบบ (ผู้ดูแลกำหนด) — ได้ UPLOADER ด้วยเสมอ แต่ไม่ได้ MEMBER
  static const String admin = 'ADMIN';

  /// ชื่อภาษาไทยของบทบาทที่รู้จัก
  static const Map<String, String> names = {
    nonMember: 'ไม่ใช่สมาชิก',
    member: 'สมาชิกฌาปนกิจ',
    uploader: 'ผู้นำไฟล์เข้า',
    admin: 'ผู้ดูแลระบบ',
  };

  /// ลำดับสิทธิ์จากสูงไปต่ำ ใช้เลือกบทบาทที่แสดงบนโปรไฟล์
  static const List<String> order = [admin, uploader, member, nonMember];

  /// ชื่อไทยของรหัสบทบาทใด ๆ (ตัด ROLE_ ให้ถ้ามี) ไม่รู้จัก = รหัสเดิม
  static String nameOf(String code) {
    final c = normalize(code);
    return names[c] ?? c;
  }

  /// รหัสบทบาทแบบชื่อสั้นตัวพิมพ์ใหญ่ (backend รุ่นใดส่ง ROLE_ มาก็ตัดให้)
  static String normalize(String code) {
    final c = code.trim().toUpperCase();
    return c.startsWith('ROLE_') ? c.substring(5) : c;
  }

  /// แปลงค่าจาก JSON เป็นรายการบทบาท (ตัดค่าว่าง/ซ้ำ) — คงบทบาทที่ไม่รู้จักไว้ตามเดิม
  static List<String> listFrom(Object? value) {
    final out = <String>[];
    if (value is List) {
      for (final v in value) {
        if (v == null) continue;
        final c = normalize('$v');
        if (c.isNotEmpty && !out.contains(c)) out.add(c);
      }
    }
    return out;
  }
}

/// เงื่อนไขการเห็นเมนูตามบทบาท (ข้อกำหนดหัวข้อ 2 "เมนูและสิทธิ์") — backend ตรวจสิทธิ์ซ้ำทุกเส้นอยู่แล้ว
///
/// รับรายการบทบาท (ไม่ผูกกับ AuthProvider) จึงทดสอบได้ตรง ๆ และใช้ร่วมกันทั้งเมนูข้าง เมนูผู้ใช้บนแถบบน และหน้าแรก
class MenuAccess {
  final bool loggedIn;
  final List<String> roles;

  /// ประเภทบุคลากรของบัญชี ([PersonType]) ไม่ทราบ = null
  final String? personType;

  const MenuAccess({
    required this.loggedIn,
    required this.roles,
    this.personType,
  });

  bool _has(String r) => loggedIn && roles.contains(r);

  bool get isMember => _has(Roles.member);
  bool get isAdmin => _has(Roles.admin);

  /// ผู้นำไฟล์เข้าหรือผู้ดูแล (ADMIN ได้ UPLOADER มาด้วยเสมอ แต่เผื่อ backend รุ่นที่ไม่ส่งมา)
  bool get isStaff => _has(Roles.uploader) || isAdmin;

  /// ดาวน์โหลด › รายชื่อผู้เสียชีวิต / แบบฟอร์มทั่วไป — ทุกคน (ไม่ต้องเข้าสู่ระบบ)
  bool get generalFiles => true;

  /// ดาวน์โหลด › ทะเบียนคุมรายชื่อ — ผู้ดูแล ผู้นำไฟล์เข้า และลูกจ้างประจำ เงินนอกงบประมาณ (N)
  /// (ผู้ใช้สั่ง 5 พ.ย. 2569)
  bool get monthYearFiles =>
      isStaff || (loggedIn && personType == PersonType.nonBudget);

  /// ดาวน์โหลด › ใบเสร็จรับเงิน (รายงวด) — สมาชิกเท่านั้น (ผู้นำไฟล์เข้า/ผู้ดูแลที่ไม่ใช่สมาชิก ซ่อนเมนู)
  bool get periodReceipts => isMember;

  /// ดาวน์โหลด › ใบเสร็จรับเงิน (เงินสด) — สมาชิก (ของตัวเอง) / ผู้นำไฟล์เข้า / ผู้ดูแล (ทุกคน)
  bool get cashReceipts => isMember || isStaff;

  /// นำไฟล์เข้า › แบบฟอร์มทั่วไป / ทะเบียนคุมรายชื่อ / เอกสารหน้าแรก
  bool get upload => isStaff;

  /// นำไฟล์เข้า › เพิ่มผู้ใช้งานทะเบียนคุม (เปลี่ยนประเภท U เป็น N) — ผู้ดูแล ผู้นำไฟล์เข้า
  bool get controlUsers => isStaff;

  /// รายงาน › ฌาปนกิจ-สลิป / ผู้เกษียณในรายการฌาปนกิจ
  bool get reports => isStaff;

  /// ผู้ดูแล › ผู้ใช้ / ผู้มีสิทธิ์นำไฟล์เข้า / ลายเซ็นใบเสร็จ / นำเข้าข้อมูลเดิม
  bool get admin => isAdmin;

  /// บัญชี › เปลี่ยนรหัสผ่าน / ยืนยันตัวตนสองขั้น / ลายนิ้วมือ
  bool get account => loggedIn;
}

/// ประเภทบุคลากร (`G` ข้าราชการ / `E` ลูกจ้างประจำ / `C` อื่น ๆ /
/// `N` ลูกจ้างประจำ เงินนอกงบประมาณ / `U` ไม่ทราบ — ไม่พบใน DPIS รอเปลี่ยนเป็น N) ไม่ทราบ = null
class PersonType {
  PersonType._();

  static const String gov = 'G';
  static const String emp = 'E';
  static const String other = 'C';

  /// ลูกจ้างประจำ เงินนอกงบประมาณ (เช่น เจ้าหน้าที่ฌาปนกิจ) — ผู้ดูแล/ผู้นำไฟล์เข้าเปลี่ยนจาก [unknown]
  static const String nonBudget = 'N';

  /// ไม่ทราบ (unknown) — ลงทะเบียนแบบไม่เป็นสมาชิกแล้วไม่พบใน DPIS รอเปลี่ยนเป็น [nonBudget]
  static const String unknown = 'U';

  static const Map<String, String> names = {
    gov: 'ข้าราชการ',
    emp: 'ลูกจ้างประจำ',
    other: 'พนักงานราชการ/อื่น ๆ',
    nonBudget: 'ลูกจ้างประจำ เงินนอกงบประมาณ',
    unknown: 'ไม่ทราบประเภท (ไม่พบใน DPIS)',
  };

  /// รหัสที่รู้จัก (ตัวพิมพ์ใหญ่) ว่าง/ไม่รู้จัก = null
  static String? normalize(Object? value) {
    final v = '${value ?? ''}'.trim().toUpperCase();
    return names.containsKey(v) ? v : null;
  }

  /// ชื่อไทย ไม่ทราบ = "ไม่ทราบ"
  static String nameOf(Object? value) => names[normalize(value)] ?? 'ไม่ทราบ';
}

/// "แบบฟอร์มสำหรับ" ของไฟล์ (ค่าเดียวกับระบบเดิม)
class FileFor {
  FileFor._();

  static const int gov = 1;
  static const int emp = 2;
  static const int all = 3;

  static const Map<int, String> names = {
    gov: 'ข้าราชการ',
    emp: 'ลูกจ้างประจำ',
    all: 'ทั้งหมด',
  };

  static String nameOf(int? v) => names[v] ?? '-';
}
