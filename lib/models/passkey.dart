import '../utils/util.dart';

/// passkey (เข้าสู่ระบบด้วยลายนิ้วมือ/Windows Hello) ของบัญชีตัวเอง จาก `GET /api/account/passkeys`
///
/// ชื่อที่ backend เก็บ/แสดงในเครื่องขึ้นต้น "ฌาปนกิจ: " แยกจาก passkey ของสลิปภาษี (RP ID เดียวกัน inf.doh.go.th)
///
/// backend ไม่ส่ง credential id / public key มา มีแค่ข้อมูลไว้แสดงและลบ
class PasskeyInfo {
  /// รหัสของ passkey ใน MongoDB (ข้อความ)
  final String id;
  final String name;
  final DateTime? createdAt;

  /// เข้าสู่ระบบด้วย passkey นี้ครั้งล่าสุด (null = ยังไม่เคย)
  final DateTime? lastUsedAt;

  /// ถูก sync/สำรองข้ามเครื่องแล้ว (เช่น Google Password Manager / iCloud Keychain)
  final bool synced;

  const PasskeyInfo({
    required this.id,
    required this.name,
    this.createdAt,
    this.lastUsedAt,
    this.synced = false,
  });

  factory PasskeyInfo.fromJson(Map<String, dynamic> json) => PasskeyInfo(
    id: '${json['id'] ?? ''}',
    name: '${json['name'] ?? 'passkey'}',
    createdAt: _date(json['createdAt']),
    lastUsedAt: _date(json['lastUsedAt']),
    synced: json['synced'] == true,
  );

  static DateTime? _date(Object? v) => Util.parseDateTime(v);
}

/// รายการ passkey ของบัญชี + จำนวนสูงสุดที่เพิ่มได้ (backend กำหนดบัญชีละไม่เกิน 5 ไม่ได้ส่งค่านี้มา)
class PasskeyList {
  final List<PasskeyInfo> passkeys;
  final int max;

  const PasskeyList(this.passkeys, this.max);

  bool get full => passkeys.length >= max;
}
