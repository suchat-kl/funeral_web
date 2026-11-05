import 'package:flutter/foundation.dart';

import '../models/two_factor.dart';
import '../services/api_service.dart';
import '../utils/passkey.dart';
import '../utils/roles.dart';
import '../utils/thaid.dart';

/// สถานะ login/session ของทั้งแอป — ห่อ [ApiService] และแจ้งผู้ฟังเมื่อสถานะเปลี่ยน
///
/// สิทธิ์เห็นเมนูอยู่ที่ [access] ([MenuAccess]) ตามบทบาทใน `roles[]` (ไม่มีสิทธิ์รายหน้าจอแบบสลิปภาษี)
class AuthProvider extends ChangeNotifier {
  final ApiService _api = ApiService();

  AuthProvider() {
    _api.onLoginStateChanged = (_) => notifyListeners();
  }

  bool get isLoggedIn => _api.isLoggedIn;
  String? get username => _api.username;
  String? get fullName => _api.fullName;
  String? get memberNo => _api.memberNo;
  String? get personType => _api.personType;
  List<String> get roles => _api.roles;
  DateTime? get previousLogin => _api.previousLogin;
  bool hasRole(String role) => _api.hasRole(role);

  /// สิทธิ์เห็นเมนูของ session นี้
  MenuAccess get access =>
      MenuAccess(loggedIn: isLoggedIn, roles: roles, personType: personType);

  bool get isMember => access.isMember;
  bool get isAdmin => access.isAdmin;

  /// ผู้นำไฟล์เข้า หรือผู้ดูแล
  bool get isStaff => access.isStaff;

  bool get isThaidLogin => _api.isThaidLogin;
  bool get isPasskeyLogin => _api.isPasskeyLogin;
  bool get mustChangePassword => _api.mustChangePassword;

  /// ชื่อที่แสดง: ชื่อ-สกุล ไม่มี = ชื่อผู้ใช้
  String get displayName {
    final name = (fullName ?? '').trim();
    return name.isNotEmpty ? name : (username ?? 'ผู้ใช้');
  }

  /// อักษรย่อบนรูปโปรไฟล์ (ตัดช่องว่างซ้อนก่อน กันชิ้นว่าง)
  String get initials {
    final parts = displayName
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return parts[0][0].toUpperCase();
  }

  /// ชื่อบทบาทที่สูงสุดของผู้ใช้ (แสดงบนโปรไฟล์) — ไม่มีบทบาทที่รู้จัก = บทบาทแรกตามรหัส
  String get highestRole {
    for (final r in Roles.order) {
      if (hasRole(r)) return Roles.nameOf(r);
    }
    return roles.isEmpty ? 'ผู้ใช้งาน' : Roles.nameOf(roles.first);
  }

  /// ชื่อไทยของทุกบทบาท (บทบาทใหม่ที่ไม่รู้จักแสดงรหัส)
  List<String> get roleDisplayNames => [for (final r in roles) Roles.nameOf(r)];

  // ── เข้าสู่ระบบ ───────────────────────────────────────────────────

  /// เข้าสู่ระบบด้วยชื่อผู้ใช้/รหัสผ่าน: null = สำเร็จ, [TwoFactorChallenge] = ต้องส่งรหัส 6 หลักต่อ
  Future<TwoFactorChallenge?> login(String username, String password) async {
    final data = await _api.login(username, password);
    final challenge = TwoFactorChallenge.fromLoginResponse(data);
    notifyListeners();
    return challenge;
  }

  Future<void> loginTwoFactor(TwoFactorChallenge challenge, String code) async {
    await _api.loginTwoFactor(challenge.challenge, code);
    notifyListeners();
  }

  bool _thaidBusy = false;

  /// กำลังรอสแกน ThaID เพื่อเข้าสู่ระบบ — ระหว่างนี้ปุ่มเข้าสู่ระบบแบบอื่นกดไม่ได้
  bool get thaidBusy => _thaidBusy;

  /// เข้าสู่ระบบด้วย ThaID คืน false ถ้าผู้ใช้ยกเลิก ไม่สำเร็จโยน [ApiException]
  /// (ยังไม่ลงทะเบียน = code `NOT_REGISTERED`) ต้องเรียกจากการกดปุ่มโดยตรง (เปิดหน้าต่างใหม่)
  Future<bool> loginWithThaid({ThaidAuthorizer? authorizer}) async {
    if (_thaidBusy || isLoggedIn) return false;
    _thaidBusy = true;
    notifyListeners();
    try {
      final state = await (authorizer ?? currentThaidAuthorizer)(
        _api,
        purpose: ApiService.thaidPurposeLogin,
      );
      if (state == null) return false;
      await _api.loginWithThaid(state);
      return true;
    } finally {
      _thaidBusy = false;
      notifyListeners();
    }
  }

  bool _passkeyBusy = false;
  bool get passkeyBusy => _passkeyBusy;

  /// เข้าสู่ระบบด้วย passkey: [username] ที่พิมพ์ไว้ (ถ้ามี) ส่งให้ backend จำกัดเฉพาะ passkey ของบัญชีนั้น
  /// คืน false ถ้าผู้ใช้กดยกเลิก
  Future<bool> loginWithPasskey(
    PasskeyAuthenticator authenticator, {
    String? username,
  }) async {
    if (_passkeyBusy || isLoggedIn) return false;
    _passkeyBusy = true;
    notifyListeners();
    try {
      final options = await _api.passkeyLoginOptions(username: username);
      final credential = await authenticator.get(options);
      if (credential == null) return false;
      await _api.loginWithPasskey(credential);
      return true;
    } finally {
      _passkeyBusy = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    await _api.logout();
    notifyListeners();
  }

  /// กู้ session ตอนเปิดหน้าเว็บ แล้วอ่านบทบาทล่าสุดจาก backend (บทบาทเปลี่ยนได้ทุกครั้งที่เข้าสู่ระบบ)
  Future<bool> loadSession() async {
    final ok = await _api.loadSession();
    if (ok) await _api.refreshProfile();
    notifyListeners();
    return ok;
  }
}
