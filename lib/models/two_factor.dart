/// ขั้นที่สองของการเข้าสู่ระบบที่ยังค้างอยู่ (บัญชีที่เปิด 2FA)
///
/// `POST /api/auth/login` ตอบ `{two_factor_required:true, challenge, expires_in}` แทน token
/// ต้องส่ง [challenge] คู่กับรหัส 6 หลักไปที่ `/api/auth/login/2fa` จึงจะได้ token
/// (backend ฌาปนกิจไม่ส่ง expires_in มากับ challenge — [expiresIn] จึงมักเป็น null)
///
/// เก็บไว้ในหน่วยความจำของหน้าต่างเข้าสู่ระบบเท่านั้น ห้ามเขียนลงที่เก็บของเบราว์เซอร์หรือ log
class TwoFactorChallenge {
  final String challenge;

  /// อายุของ [challenge] เป็นวินาที (backend ไม่ส่งมา = null)
  final int? expiresIn;

  const TwoFactorChallenge({required this.challenge, this.expiresIn});

  /// อายุปัดขึ้นเป็นนาที สำหรับข้อความบนหน้าจอ (ไม่ทราบ = null)
  int? get expiresInMinutes =>
      expiresIn == null || expiresIn! <= 0 ? null : (expiresIn! / 60).ceil();

  /// อ่านจากผลของ `/api/auth/login` — ไม่ใช่ผลที่ต้องใช้ 2FA คืน null
  static TwoFactorChallenge? fromLoginResponse(dynamic data) {
    if (data is! Map || data['two_factor_required'] != true) return null;
    final challenge = data['challenge'];
    if (challenge is! String || challenge.isEmpty) return null;
    final expires = data['expires_in'];
    return TwoFactorChallenge(
      challenge: challenge,
      expiresIn: expires is num ? expires.toInt() : null,
    );
  }
}

/// ข้อมูลตั้งค่าแอป Authenticator จาก `POST /api/account/2fa/setup` (`{secret, otpauth_uri}`)
///
/// รูป QR สร้างในเครื่องจาก [otpauthUri] (widgets/qr_view.dart) **ห้ามส่งค่านี้ไปบริการภายนอก**
/// เป็นความลับของบัญชี อยู่ใน state ของหน้าต่างตั้งค่าเท่านั้น
/// ห้ามเก็บลงที่เก็บของเบราว์เซอร์ ห้าม log และต้องทิ้งเมื่อปิดหน้าต่าง
class TwoFactorSetup {
  /// รหัสตั้งค่า (Base32) สำหรับพิมพ์เองในแอป
  final String secret;

  /// ลิงก์ `otpauth://` (ข้อมูลเดียวกับใน QR)
  final String otpauthUri;

  const TwoFactorSetup({required this.secret, required this.otpauthUri});

  factory TwoFactorSetup.fromJson(Map<String, dynamic> j) => TwoFactorSetup(
    secret: '${j['secret'] ?? ''}',
    otpauthUri: '${j['otpauth_uri'] ?? j['otpauthUri'] ?? ''}',
  );

  /// รหัสตั้งค่าแบ่งกลุ่มละ 4 ตัว ให้อ่านและพิมพ์ตามได้ง่าย
  String get secretGrouped {
    final s = secret.replaceAll(RegExp(r'\s'), '');
    final parts = <String>[];
    for (var i = 0; i < s.length; i += 4) {
      parts.add(s.substring(i, i + 4 > s.length ? s.length : i + 4));
    }
    return parts.join(' ');
  }
}
