import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../config/app_config.dart';
import '../models/control_user.dart';
import '../models/home_document.dart';
import '../models/import_result.dart';
import '../models/passkey.dart';
import '../models/receipt.dart';
import '../models/register_ticket.dart';
import '../models/signature.dart';
import '../models/stats.dart';
import '../models/stored_file.dart';
import '../models/two_factor.dart';
import '../models/uploader.dart';
import '../models/user_admin.dart';
import '../utils/file_download.dart';
import '../utils/logger.dart';
import '../utils/roles.dart';
import '../utils/util.dart';
import 'auth_interceptor.dart';

/// รหัสข้อผิดพลาดของ backend (ช่อง `code` ของ `{code, message, success:false}`)
/// หน้าจอใช้แยกกรณีโดยไม่ต้องเทียบข้อความ — ข้อความที่แสดงใช้ `message` ของ backend (เป็นภาษาไทยอยู่แล้ว)
class ErrorCodes {
  ErrorCodes._();

  static const String unauthenticated = 'UNAUTHENTICATED';
  static const String badCredentials = 'BAD_CREDENTIALS';
  static const String accountLocked = 'ACCOUNT_LOCKED';
  static const String accountDisabled = 'ACCOUNT_DISABLED';
  static const String forbidden = 'FORBIDDEN';
  static const String passwordChangeRequired = 'PASSWORD_CHANGE_REQUIRED';
  static const String duplicate = 'DUPLICATE';
  static const String dpisError = 'DPIS_ERROR';
  static const String thaidError = 'THAID_ERROR';
  static const String dpayApiNotConfigured = 'DPAY_API_NOT_CONFIGURED';
  static const String dpayApiError = 'DPAY_API_ERROR';
  static const String passkeyInvalid = 'PASSKEY_INVALID';
  static const String twoFactorRejected = 'TWO_FACTOR_REJECTED';
  static const String twoFactorCodeWrong = 'TWO_FACTOR_CODE_WRONG';
  static const String notRegistered = 'NOT_REGISTERED';
  static const String tooManyRequests = 'TOO_MANY_REQUESTS';
  static const String registerNotMatch = 'REGISTER_NOT_MATCH';
  static const String alreadyRegistered = 'ALREADY_REGISTERED';
  static const String registerTicketInvalid = 'REGISTER_TICKET_INVALID';
  static const String notInDpis = 'NOT_IN_DPIS';
  static const String notMember = 'NOT_MEMBER';
  static const String badRequest = 'BAD_REQUEST';
  static const String notFound = 'NOT_FOUND';
}

/// ทุก endpoint ของ backend ฌาปนกิจ (Spring Boot `/funeralapi`) — ใช้ตัวเดียวทั้งแอป (singleton)
///
/// - `dio` แนบ token ผ่าน [AuthInterceptor] (เจอ 401 ต่ออายุแล้วยิงซ้ำ)
/// - `publicDio` ไม่มี interceptor ใช้กับเส้นที่ไม่ต้องเข้าสู่ระบบ
/// - **ห้าม log** token, รหัสผ่าน, challenge, ticket, เลขบัตร, ชื่อ, วันเกิด (ใช้ [AppLogger.redact])
class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;

  late final Dio dio;
  late final Dio publicDio;
  late final FlutterSecureStorage storage;

  /// URL ของ API — เลือกตอน run/build ด้วย `--dart-define=API_BASE=...`
  ///
  /// ไม่ส่งมาจะเป็น production เสมอ ลืมใส่ตอน build ขึ้นเซิร์ฟเวอร์จึงไม่พัง
  /// development (nginx บน WSL): `--dart-define=API_BASE=https://suchat-dev.doh.go.th/funeralapi`
  /// ต้องมี "127.0.0.1 suchat-dev.doh.go.th" ใน hosts ของ Windows ก่อน
  /// ไม่ต้องใส่ / ปิดท้าย เพราะ path ที่ต่อท้ายขึ้นต้นด้วย / อยู่แล้ว
  static const String baseUrl = String.fromEnvironment(
    'API_BASE',
    defaultValue: 'https://backupdoh.doh.go.th/funeralapi',
  );

  static const String accessTokenKey = 'access_token';
  static const String refreshTokenKey = 'refresh_token';

  /// ข้อมูลผู้ใช้ของ session (JSON: username, full_name, member_no, person_type, roles)
  static const String userDataKey = 'user_data';

  /// วิธีเข้าสู่ระบบของ session: password / thaid / passkey
  static const String loginMethodKey = 'login_method';

  /// ต้องเปลี่ยนรหัสผ่านก่อนใช้งาน เก็บไว้ให้รอดการโหลดหน้าใหม่
  static const String mustChangePasswordKey = 'must_change_password';

  // ── วัตถุประสงค์ของ ThaID (query `purpose` ของ public-thaid/start) ── state ใช้ข้ามวัตถุประสงค์ไม่ได้
  static const String thaidPurposeLogin = 'login';
  static const String thaidPurposeRegister = 'register';
  static const String thaidPurposeReset = 'reset';

  // ── ทางลงทะเบียนผ่าน ThaID (`mode` ของ public-thaid/register) ──
  static const String registerModeMember = 'MEMBER';
  static const String registerModeNonMember = 'NON_MEMBER';

  // ── ชนิดของสถานะคำขอ ThaID ──
  static const String thaidPending = 'PENDING';
  static const String thaidDone = 'DONE';
  static const String thaidErrorStatus = 'ERROR';
  static const String thaidGone = 'GONE';

  String? _username;
  String? _fullName;
  String? _memberNo;
  String? _personType;
  List<String> _roles = [];
  String? _loginMethod;
  bool _mustChangePassword = false;
  bool _isLoggedIn = false;
  DateTime? _previousLogin;

  /// แจ้งเมื่อสถานะเข้าสู่ระบบเปลี่ยน (AuthProvider ฟังอยู่)
  void Function(bool isLoggedIn)? onLoginStateChanged;

  ApiService._internal() {
    // ที่เก็บของระบบนี้เอง — ค่าเริ่มต้นของ package ใช้ชื่อเดียวกันทุกแอปใน origin เดียวกัน
    // (inf.doh.go.th มีสลิปภาษีและหักหนี้ด้วย) ถ้าไม่แยก token จะปนกัน และ deleteAll() ตอนออกจากระบบ
    // จะลบ token ของอีกระบบไปด้วย
    storage = const FlutterSecureStorage(
      webOptions: WebOptions(
        dbName: AppConfig.secureDbName,
        publicKey: AppConfig.securePublicKey,
      ),
    );
    BaseOptions options() => BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 30),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      receiveDataWhenStatusError: true,
    );
    publicDio = Dio(options());
    dio = Dio(options());

    if (kDebugMode) {
      // ไม่ใช้ LogInterceptor: พิมพ์ URI ทุกคำขอ ซึ่งมี query ที่ห้าม log (เช่น state ของ ThaID)
      // จดเฉพาะข้อผิดพลาด ตัวข้อมูลผ่าน redact()
      dio.interceptors.add(
        InterceptorsWrapper(
          onError: (e, handler) {
            if (AppLogger.on) {
              AppLogger.lazy(
                () =>
                    '🔴 ${e.response?.statusCode} ${e.requestOptions.method} '
                    '${e.requestOptions.path}\n${AppLogger.redact(e.response?.data)}',
                tag: 'API',
              );
            }
            handler.next(e);
          },
        ),
      );
    }
    dio.interceptors.add(AuthInterceptor(this));
  }

  // ===================================================================
  // สถานะของ session
  // ===================================================================

  bool get isLoggedIn => _isLoggedIn;
  String? get username => _username;
  String? get fullName => _fullName;

  /// เลขสมาชิกฌาปนกิจ (null = ไม่ใช่สมาชิก)
  String? get memberNo => _isLoggedIn ? _memberNo : null;

  /// ประเภทบุคลากร G / E / C (null = ไม่ทราบ)
  String? get personType => _isLoggedIn ? _personType : null;

  /// บทบาทชื่อสั้น (MEMBER / NON_MEMBER / UPLOADER / ADMIN / บทบาทใหม่ในอนาคต)
  List<String> get roles => _isLoggedIn ? List.unmodifiable(_roles) : const [];
  bool hasRole(String role) => roles.contains(role);

  /// วิธีเข้าสู่ระบบของ session: 'password' / 'thaid' / 'passkey' (ไม่ทราบ = null)
  String? get loginMethod => _loginMethod;
  bool get isThaidLogin => _loginMethod == 'thaid';
  bool get isPasskeyLogin => _loginMethod == 'passkey';

  /// ต้องเปลี่ยนรหัสผ่านก่อนใช้งาน (ผู้ดูแลตั้งรหัสให้) หน้าเว็บเปิดหน้าเปลี่ยนรหัสผ่านแบบปิดไม่ได้
  bool get mustChangePassword => _isLoggedIn && _mustChangePassword;

  /// เวลาเข้าสู่ระบบครั้งก่อน (จาก `/api/auth/me`) null = ครั้งแรก/ไม่ทราบ
  DateTime? get previousLogin => _isLoggedIn ? _previousLogin : null;

  /// เก็บข้อมูลผู้ใช้จากผล login / `/me` ลงหน่วยความจำและที่เก็บของเบราว์เซอร์
  Future<void> _applyProfile(Map data) async {
    if (data['username'] != null) _username = '${data['username']}';
    _fullName = _strOrNull(data['full_name']);
    _memberNo = _strOrNull(data['member_no']);
    _personType = PersonType.normalize(data['person_type']);
    _roles = Roles.listFrom(data['roles']);
    if (data.containsKey('must_change_password')) {
      _mustChangePassword = data['must_change_password'] == true;
    }
    if (data.containsKey('previous_login')) {
      _previousLogin = Util.parseDateTime(data['previous_login']);
    }
    await storage.write(
      key: userDataKey,
      value: jsonEncode({
        'username': _username,
        'full_name': _fullName,
        'member_no': _memberNo,
        'person_type': _personType,
        'roles': _roles,
      }),
    );
    if (_mustChangePassword) {
      await storage.write(key: mustChangePasswordKey, value: 'true');
    } else {
      await storage.delete(key: mustChangePasswordKey);
    }
  }

  /// เก็บ token และข้อมูลผู้ใช้หลังเข้าสู่ระบบสำเร็จ ([method] = password / thaid / passkey)
  Future<void> _applyLogin(Map data, String method) async {
    final access = data['access_token'];
    if (access is! String || access.isEmpty) {
      throw const ApiException('ไม่พบ access token ในคำตอบของระบบ');
    }
    await storage.write(key: accessTokenKey, value: access);
    await storage.write(
      key: refreshTokenKey,
      value: '${data['refresh_token']}',
    );
    _loginMethod = method;
    await storage.write(key: loginMethodKey, value: method);
    _previousLogin = null;
    await _applyProfile(data);
    _isLoggedIn = true;
    onLoginStateChanged?.call(true);
    if (AppLogger.on) {
      AppLogger.i('🟢 เข้าสู่ระบบ: $_username ($method) $_roles');
    }
  }

  /// กู้ session จากที่เก็บของเบราว์เซอร์ตอนเปิดหน้าเว็บ (ยังไม่ตรวจกับ backend — ดู [refreshProfile])
  Future<bool> loadSession() async {
    try {
      final token = await storage.read(key: accessTokenKey);
      final raw = await storage.read(key: userDataKey);
      if (token == null || raw == null) return false;
      final data = jsonDecode(raw);
      if (data is! Map || data['username'] == null) return false;
      _username = '${data['username']}';
      _fullName = _strOrNull(data['full_name']);
      _memberNo = _strOrNull(data['member_no']);
      _personType = PersonType.normalize(data['person_type']);
      _roles = Roles.listFrom(data['roles']);
      _loginMethod = await storage.read(key: loginMethodKey);
      _mustChangePassword =
          await storage.read(key: mustChangePasswordKey) == 'true';
      _isLoggedIn = true;
      onLoginStateChanged?.call(true);
      if (AppLogger.on) AppLogger.i('🟢 กู้ session: $_username');
      return true;
    } catch (e) {
      if (AppLogger.on) AppLogger.w('⚠️ กู้ session ไม่สำเร็จ: $e');
      return false;
    }
  }

  /// อ่านข้อมูลผู้ใช้ล่าสุดจาก `GET /api/auth/me` (บทบาทเปลี่ยนตามทะเบียนสมาชิก/รายชื่อผู้นำไฟล์เข้า)
  /// ไม่สำเร็จ (เครือข่าย) คงค่าเดิม — token ใช้ไม่ได้แล้ว interceptor ออกจากระบบให้
  Future<void> refreshProfile() async {
    if (!_isLoggedIn) return;
    try {
      final r = await _authedRequest('GET', '/api/auth/me');
      if (r.statusCode == 200 && r.data is Map) {
        await _applyProfile(r.data as Map);
        onLoginStateChanged?.call(_isLoggedIn);
      }
    } catch (e) {
      if (AppLogger.on) AppLogger.w('⚠️ โหลดข้อมูลผู้ใช้ไม่สำเร็จ: $e');
    }
  }

  Future<String?> getAccessToken() => storage.read(key: accessTokenKey);

  // ===================================================================
  // เข้าสู่ระบบ / ออกจากระบบ
  // ===================================================================

  /// เข้าสู่ระบบด้วยชื่อผู้ใช้/รหัสผ่าน คืนตัวข้อมูลที่ backend ตอบ
  ///
  /// บัญชีที่เปิด 2FA: ได้ `two_factor_required: true` + `challenge` **ไม่มี token** — ยังไม่ถือว่าเข้าสู่ระบบ
  /// ผู้เรียกแยกด้วย `TwoFactorChallenge.fromLoginResponse` แล้วส่งรหัส 6 หลักต่อด้วย [loginTwoFactor]
  /// ไม่สำเร็จโยน [ApiException] (401 รหัสผิด / บัญชีถูกล็อก / ถูกระงับ — ข้อความของ backend)
  Future<Map<String, dynamic>> login(String username, String password) async {
    if (AppLogger.on) AppLogger.d('🔵 เข้าสู่ระบบ: $username');
    final r = await _publicPost('/api/auth/login', {
      'username': username,
      'password': password,
    });
    if (r.statusCode == 200 && r.data is Map) {
      final data = Map<String, dynamic>.from(r.data as Map);
      if (data['two_factor_required'] == true) {
        if (TwoFactorChallenge.fromLoginResponse(data) == null) {
          throw const ApiException('ไม่พบรหัสอ้างอิงสำหรับยืนยันตัวตนสองขั้น');
        }
        return data;
      }
      await _applyLogin(data, 'password');
      return data;
    }
    throw _apiError(
      r.statusCode,
      r.data,
      r.statusCode == 401
          ? 'ชื่อผู้ใช้หรือรหัสผ่านไม่ถูกต้อง'
          : 'เข้าสู่ระบบไม่สำเร็จ',
    );
  }

  /// ขั้นที่สองของการเข้าสู่ระบบ: [challenge] จาก [login] + รหัส 6 หลัก
  /// 401 `TWO_FACTOR_CODE_WRONG` กรอกใหม่ได้ด้วย challenge เดิม; 400 `TWO_FACTOR_REJECTED` ต้องเริ่มใหม่
  Future<Map<String, dynamic>> loginTwoFactor(
    String challenge,
    String code,
  ) async {
    final r = await _publicPost('/api/auth/login/2fa', {
      'challenge': challenge,
      'code': code,
    });
    if (r.statusCode == 200 && r.data is Map) {
      final data = Map<String, dynamic>.from(r.data as Map);
      await _applyLogin(data, 'password');
      return data;
    }
    throw _apiError(r.statusCode, r.data, switch (r.statusCode) {
      401 => 'รหัส 6 หลักไม่ถูกต้อง กรุณาลองใหม่',
      400 => 'หมดเวลายืนยันตัวตน กรุณาเข้าสู่ระบบใหม่อีกครั้ง',
      _ => 'ยืนยันตัวตนสองขั้นไม่สำเร็จ',
    });
  }

  /// เข้าสู่ระบบด้วยผล ThaID ของ [state] (ใช้ได้ครั้งเดียว) — ไม่มีขั้น 2FA
  /// ยังไม่ลงทะเบียน = 404 `NOT_REGISTERED`
  Future<Map<String, dynamic>> loginWithThaid(String state) async {
    final r = await _publicPost('/api/auth/public-thaid/login', {
      'state': state,
    });
    if (r.statusCode == 200 && r.data is Map) {
      final data = Map<String, dynamic>.from(r.data as Map);
      await _applyLogin(data, 'thaid');
      return data;
    }
    throw _apiError(r.statusCode, r.data, 'เข้าสู่ระบบด้วย ThaID ไม่สำเร็จ');
  }

  /// options ของการเข้าสู่ระบบด้วย passkey (`publicKey` ของ navigator.credentials.get)
  /// ส่ง [username] ที่ผู้ใช้พิมพ์ไว้ (ถ้ามี) backend จะใส่ allowCredentials เฉพาะ passkey ของบัญชีนั้น
  Future<Map<String, dynamic>> passkeyLoginOptions({String? username}) async {
    final name = username?.trim() ?? '';
    final r = await _publicPost('/api/public/passkey/options', {
      if (name.isNotEmpty) 'username': name,
    });
    return _publicKeyOf(r, 'เริ่มเข้าสู่ระบบด้วย passkey ไม่สำเร็จ');
  }

  /// เข้าสู่ระบบด้วยผลของ navigator.credentials.get (ส่งเป็นข้อความ JSON ตามที่ backend รับ)
  Future<Map<String, dynamic>> loginWithPasskey(
    Map<String, dynamic> credential,
  ) async {
    final r = await _publicPost('/api/public/passkey/login', {
      'credential': jsonEncode(credential),
    });
    if (r.statusCode == 200 && r.data is Map) {
      final data = Map<String, dynamic>.from(r.data as Map);
      await _applyLogin(data, 'passkey');
      return data;
    }
    throw _apiError(r.statusCode, r.data, 'เข้าสู่ระบบด้วย passkey ไม่สำเร็จ');
  }

  bool _isRefreshing = false;

  /// ต่ออายุ token ด้วย refresh token — ไม่สำเร็จ = ออกจากระบบแล้วโยนข้อผิดพลาด
  Future<void> refreshToken() async {
    if (_isRefreshing) {
      await Future.doWhile(() async {
        await Future.delayed(const Duration(milliseconds: 100));
        return _isRefreshing;
      });
      if (!_isLoggedIn) throw const ApiException('กรุณาเข้าสู่ระบบใหม่');
      return;
    }
    _isRefreshing = true;
    try {
      final old = await storage.read(key: refreshTokenKey);
      if (old == null || old.isEmpty) {
        throw const ApiException('ไม่มี refresh token');
      }
      final r = await publicDio.post(
        '/api/auth/refresh-token',
        data: {'refresh_token': old},
        options: Options(validateStatus: (_) => true),
      );
      if (r.statusCode != 200 || r.data is! Map) {
        throw ApiException('ต่ออายุ token ไม่สำเร็จ (${r.statusCode})');
      }
      final data = r.data as Map;
      await storage.write(
        key: accessTokenKey,
        value: '${data['access_token']}',
      );
      await storage.write(
        key: refreshTokenKey,
        value: '${data['refresh_token']}',
      );
      if (AppLogger.on) AppLogger.i('🟢 ต่ออายุ token แล้ว');
    } catch (e) {
      if (AppLogger.on) AppLogger.e('🔴 ต่ออายุ token ไม่สำเร็จ: $e');
      await logout();
      throw const ApiException('หมดเวลาการใช้งาน กรุณาเข้าสู่ระบบใหม่');
    } finally {
      _isRefreshing = false;
    }
  }

  /// ออกจากระบบ: แจ้ง backend ให้ยกเลิก access token (header) และ refresh token (body) แล้วล้างในเครื่อง
  ///
  /// ยิงผ่าน [publicDio] และแนบ header เอง ไม่ให้ interceptor ไปต่ออายุ token ที่กำลังจะทิ้ง
  Future<void> logout() async {
    final refresh = await storage.read(key: refreshTokenKey);
    final access = await storage.read(key: accessTokenKey);
    if (refresh != null || access != null) {
      try {
        await publicDio.post(
          '/api/auth/logout',
          data: {'refresh_token': refresh},
          options: Options(
            headers: {if (access != null) 'Authorization': 'Bearer $access'},
            validateStatus: (_) => true,
          ),
        );
      } catch (e) {
        if (AppLogger.on) AppLogger.w('⚠️ แจ้งออกจากระบบไม่สำเร็จ: $e');
      }
    }
    _username = null;
    _fullName = null;
    _memberNo = null;
    _personType = null;
    _roles = [];
    _loginMethod = null;
    _mustChangePassword = false;
    _previousLogin = null;
    final was = _isLoggedIn;
    _isLoggedIn = false;
    // ลบเฉพาะที่เก็บของระบบนี้ (ฐานชื่อ FuneralEncryptedStorage) ไม่แตะระบบอื่นบนโดเมนเดียวกัน
    await storage.deleteAll();
    if (was || access != null) onLoginStateChanged?.call(false);
  }

  /// token ใกล้หมดอายุ (เหลือไม่ถึง 60 วินาที) หรืออ่านไม่ได้
  Future<bool> isTokenExpired() async {
    try {
      final token = await getAccessToken();
      if (token == null) return true;
      final parts = token.split('.');
      if (parts.length != 3) return true;
      final map = json.decode(
        utf8.decode(base64.decode(base64.normalize(parts[1]))),
      );
      final exp = map is Map ? map['exp'] : null;
      if (exp is! num) return true;
      final expiry = DateTime.fromMillisecondsSinceEpoch(exp.toInt() * 1000);
      return DateTime.now().add(const Duration(seconds: 60)).isAfter(expiry);
    } catch (_) {
      return true;
    }
  }

  /// ต่ออายุ token ก่อนยิงคำขอถ้าใกล้หมดอายุ — เมธอดที่ต้องเข้าสู่ระบบทุกตัวเรียกก่อน
  Future<void> _ensureToken() async {
    if (await isTokenExpired()) {
      try {
        await refreshToken();
      } catch (_) {
        throw const ApiException('กรุณาเข้าสู่ระบบใหม่', statusCode: 401);
      }
    }
  }

  /// เปลี่ยนรหัสผ่านของตัวเอง (บัญชีจาก token) — ผู้ที่ต้องเปลี่ยนรหัสผ่านใช้เส้นนี้ได้
  Future<String> changePassword(String oldPassword, String newPassword) async {
    final r = await _authedRequest(
      'POST',
      '/api/auth/changepassword',
      data: {'oldPassword': oldPassword, 'newPassword': newPassword},
    );
    if (r.statusCode == 200 && r.data is Map && r.data['success'] != false) {
      _mustChangePassword = false;
      await storage.delete(key: mustChangePasswordKey);
      return _messageFrom(r.data) ?? 'เปลี่ยนรหัสผ่านสำเร็จ';
    }
    throw _apiError(r.statusCode, r.data, 'เปลี่ยนรหัสผ่านไม่สำเร็จ');
  }

  // ===================================================================
  // ThaID (ไม่ต้องเข้าสู่ระบบ)
  // ===================================================================

  /// เริ่มยืนยันตัวตน ThaID: ได้ URL ของ ThaID กับ state (ห้าม log state)
  /// [returnUrl] ต้องเป็นหน้า thaid_callback.html ของเว็บนี้ (backend ตรวจโดเมน)
  Future<({String url, String state})> thaidStart(
    String returnUrl, {
    String purpose = thaidPurposeLogin,
  }) async {
    final r = await _publicRequest(
      'GET',
      '/api/auth/public-thaid/start',
      query: {'returnUrl': returnUrl, 'purpose': purpose},
    );
    final data = r.data;
    if (r.statusCode == 200 &&
        data is Map &&
        data['url'] is String &&
        data['state'] is String) {
      return (url: data['url'] as String, state: data['state'] as String);
    }
    throw _apiError(r.statusCode, data, 'เริ่มยืนยันตัวตนด้วย ThaID ไม่สำเร็จ');
  }

  /// สถานะของคำขอ ThaID: PENDING / DONE / ERROR / GONE — ถามไม่ได้ = null
  /// (มือถือ: แอป ThaID เปิดหน้า callback ในแท็บใหม่ หน้านี้จึงถามเป็นระยะ)
  Future<String?> thaidStatus(String state) async {
    try {
      final r = await _publicRequest(
        'GET',
        '/api/auth/public-thaid/status',
        query: {'state': state},
      );
      final s = r.data is Map ? r.data['status'] : null;
      return r.statusCode == 200 && s is String ? s : null;
    } catch (_) {
      return null;
    }
  }

  /// ลงทะเบียนผ่าน ThaID ([mode] = [registerModeMember] / [registerModeNonMember]) ได้ใบผ่าน
  /// code ที่เป็นไปได้: NOT_MEMBER, ALREADY_REGISTERED, THAID_ERROR, TOO_MANY_REQUESTS, DPIS_ERROR
  /// (NOT_IN_DPIS เลิกใช้ 5 พ.ย. 2569: ไม่พบใน DPIS ลงทะเบียนได้เป็นประเภท N)
  Future<RegisterTicket> thaidRegister(String state, String mode) async {
    final r = await _publicPost('/api/auth/public-thaid/register', {
      'state': state,
      'mode': mode,
    });
    return _ticketOf(r, 'ลงทะเบียนผ่าน ThaID ไม่สำเร็จ');
  }

  /// ลืมรหัสผ่าน: ตั้งรหัสใหม่ด้วยผล ThaID ของ [state] คืนข้อความของ backend (มีชื่อผู้ใช้)
  /// backend ยกเลิก token ทั้งหมดของบัญชีนั้น
  Future<String> thaidReset(String state, String newPassword) async {
    final r = await _publicPost('/api/auth/public-thaid/reset', {
      'state': state,
      'newPassword': newPassword,
    });
    if (r.statusCode == 200 && r.data is Map && r.data['success'] != false) {
      return _messageFrom(r.data) ?? 'ตั้งรหัสผ่านใหม่สำเร็จ';
    }
    throw _apiError(r.statusCode, r.data, 'ตั้งรหัสผ่านใหม่ไม่สำเร็จ');
  }

  // ===================================================================
  // ลงทะเบียน (ไม่ต้องเข้าสู่ระบบ)
  // ===================================================================

  /// เป็นสมาชิก แบบเดิม: เลขบัตร + เลขสมาชิก ได้ใบผ่าน
  /// ไม่ตรง = 400 REGISTER_NOT_MATCH (ไม่บอกช่อง), เคยลงทะเบียน = ALREADY_REGISTERED, ถี่ไป = 429
  Future<RegisterTicket> registerLegacyVerify({
    required String idcard,
    required String memberNo,
  }) async {
    final r = await _publicPost('/api/public/register/legacy-verify', {
      'idcard': idcard,
      'memberNo': memberNo,
    });
    return _ticketOf(r, 'ตรวจสอบข้อมูลสมาชิกไม่สำเร็จ');
  }

  /// ขั้นสุดท้ายของทุกทาง: ตั้งชื่อผู้ใช้ + รหัสผ่านด้วยใบผ่าน คืน (ชื่อผู้ใช้, ข้อความ)
  /// 409 DUPLICATE = ชื่อซ้ำ (ใบผ่านยังใช้ได้), 400 REGISTER_TICKET_INVALID = ต้องเริ่มใหม่
  Future<({String username, String message})> registerComplete({
    required String ticket,
    required String username,
    required String password,
  }) async {
    final r = await _publicPost('/api/public/register/complete', {
      'ticket': ticket,
      'username': username,
      'password': password,
    });
    if (r.statusCode == 200 && r.data is Map && r.data['success'] != false) {
      return (
        username: '${r.data['username'] ?? username}',
        message: _messageFrom(r.data) ?? 'ลงทะเบียนสำเร็จ',
      );
    }
    throw _apiError(r.statusCode, r.data, 'ลงทะเบียนไม่สำเร็จ');
  }

  RegisterTicket _ticketOf(Response<dynamic> r, String fallback) {
    if (r.statusCode == 200 && r.data is Map) {
      final t = RegisterTicket.fromJson(Map<String, dynamic>.from(r.data));
      if (t.ticket.isNotEmpty) return t;
    }
    throw _apiError(r.statusCode == 200 ? 500 : r.statusCode, r.data, fallback);
  }

  // ===================================================================
  // บัญชี › ยืนยันตัวตนสองขั้น / passkey
  // ===================================================================

  Future<bool> twoFactorStatus() async {
    final r = await _authedRequest('GET', '/api/account/2fa');
    if (r.statusCode == 200 && r.data is Map) return r.data['enabled'] == true;
    throw _apiError(r.statusCode, r.data, 'โหลดสถานะ 2FA ไม่สำเร็จ');
  }

  /// เริ่มเปิด 2FA (ต้องยืนยันรหัสผ่านปัจจุบัน) ได้รหัสตั้งค่า + otpauth_uri (QR สร้างในเครื่อง)
  Future<TwoFactorSetup> twoFactorSetup(String currentPassword) async {
    final r = await _authedRequest(
      'POST',
      '/api/account/2fa/setup',
      data: {'currentPassword': currentPassword},
    );
    if (r.statusCode == 200 && r.data is Map) {
      final s = TwoFactorSetup.fromJson(Map<String, dynamic>.from(r.data));
      if (s.secret.isNotEmpty) return s;
    }
    throw _apiError(r.statusCode, r.data, 'เริ่มตั้งค่า 2FA ไม่สำเร็จ');
  }

  Future<String> twoFactorEnable(String code) async {
    final r = await _authedRequest(
      'POST',
      '/api/account/2fa/enable',
      data: {'code': code},
    );
    if (r.statusCode == 200) {
      return _messageFrom(r.data) ?? 'เปิดใช้การยืนยันตัวตนสองขั้นเรียบร้อย';
    }
    throw _apiError(r.statusCode, r.data, 'เปิดใช้ 2FA ไม่สำเร็จ');
  }

  Future<String> twoFactorDisable({
    required String currentPassword,
    required String code,
  }) async {
    final r = await _authedRequest(
      'POST',
      '/api/account/2fa/disable',
      data: {'currentPassword': currentPassword, 'code': code},
    );
    if (r.statusCode == 200) {
      return _messageFrom(r.data) ?? 'ปิดการยืนยันตัวตนสองขั้นเรียบร้อย';
    }
    throw _apiError(r.statusCode, r.data, 'ปิดใช้ 2FA ไม่สำเร็จ');
  }

  /// passkey ของบัญชีตัวเอง (backend จำกัดบัญชีละ 5)
  Future<PasskeyList> passkeyList() async {
    final r = await _authedRequest('GET', '/api/account/passkeys');
    if (r.statusCode == 200 && r.data is List) {
      return PasskeyList([
        for (final p in r.data as List)
          if (p is Map) PasskeyInfo.fromJson(Map<String, dynamic>.from(p)),
      ], 5);
    }
    throw _apiError(r.statusCode, r.data, 'โหลดรายการ passkey ไม่สำเร็จ');
  }

  /// options ของการเพิ่ม passkey (ยืนยันรหัสผ่านปัจจุบัน) — `publicKey` ของ navigator.credentials.create
  Future<Map<String, dynamic>> passkeyRegisterOptions(
    String currentPassword,
  ) async {
    final r = await _authedRequest(
      'POST',
      '/api/account/passkeys/options',
      data: {'currentPassword': currentPassword},
    );
    return _publicKeyOf(r, 'เริ่มเพิ่ม passkey ไม่สำเร็จ');
  }

  /// ส่งผลของ navigator.credentials.create (เป็นข้อความ JSON) ให้ backend เก็บ
  Future<PasskeyInfo> passkeyRegister(
    Map<String, dynamic> credential, {
    String? name,
  }) async {
    final r = await _authedRequest(
      'POST',
      '/api/account/passkeys',
      data: {'name': (name ?? '').trim(), 'credential': jsonEncode(credential)},
    );
    if (r.statusCode == 200 && r.data is Map) {
      return PasskeyInfo.fromJson(Map<String, dynamic>.from(r.data));
    }
    throw _apiError(r.statusCode, r.data, 'เพิ่ม passkey ไม่สำเร็จ');
  }

  Future<String> passkeyDelete(String id) async {
    final r = await _authedRequest('DELETE', '/api/account/passkeys/$id');
    if (r.statusCode == 200) {
      return _messageFrom(r.data) ?? 'ลบ passkey เรียบร้อย';
    }
    throw _apiError(r.statusCode, r.data, 'ลบ passkey ไม่สำเร็จ');
  }

  // ===================================================================
  // หน้าแรก / ไฟล์
  // ===================================================================

  /// สถิติหน้าแรก (ไม่แนบ token)
  Future<PublicStats> getPublicStats() async {
    final r = await _publicRequest('GET', '/api/public/stats');
    if (r.statusCode == 200 && r.data is Map) {
      return PublicStats.fromJson(Map<String, dynamic>.from(r.data));
    }
    throw _apiError(r.statusCode, r.data, 'โหลดสถิติไม่สำเร็จ');
  }

  /// เอกสาร PDF สองช่องบนหน้าแรก (ทุกคน)
  Future<List<HomeDocument>> getHomeDocuments() async {
    final r = await _publicRequest('GET', '/api/public/home-documents');
    if (r.statusCode == 200 && r.data is List) {
      return [
        for (final m in r.data as List)
          if (m is Map) HomeDocument.fromJson(Map<String, dynamic>.from(m)),
      ];
    }
    throw _apiError(r.statusCode, r.data, 'โหลดเอกสารหน้าแรกไม่สำเร็จ');
  }

  /// บันทึกเอกสารหน้าแรก (ผู้นำไฟล์เข้า/ผู้ดูแล): [bytes] null = แก้แค่ข้อความบนปุ่ม
  Future<HomeDocument> saveHomeDocument(
    String slot, {
    required String title,
    Uint8List? bytes,
    String? fileName,
  }) async {
    final r = await _multipart('/api/upload/home-documents/$slot', () {
      final form = FormData();
      form.fields.add(MapEntry('title', title.trim()));
      if (bytes != null) {
        form.files.add(
          MapEntry(
            'file',
            MultipartFile.fromBytes(
              bytes,
              filename: fileName ?? 'document.pdf',
              contentType: DioMediaType.parse('application/pdf'),
            ),
          ),
        );
      }
      return form;
    }, timeout: const Duration(minutes: 5));
    if (r.statusCode == 200 && r.data is Map) {
      return HomeDocument.fromJson(Map<String, dynamic>.from(r.data));
    }
    throw _apiError(r.statusCode, r.data, 'บันทึกเอกสารหน้าแรกไม่สำเร็จ');
  }

  /// เอาไฟล์ออก (ปุ่มหายจากหน้าแรก)
  Future<String> removeHomeDocument(String slot) async {
    final r = await _authedRequest(
      'DELETE',
      '/api/upload/home-documents/$slot',
    );
    if (r.statusCode == 200) {
      return _messageFrom(r.data) ?? 'เอาเอกสารออกจากหน้าแรกเรียบร้อย';
    }
    throw _apiError(r.statusCode, r.data, 'เอาเอกสารออกไม่สำเร็จ');
  }

  /// แบบฟอร์มทั่วไป — เข้าสู่ระบบอยู่แนบ token (backend กรองตามประเภทบุคลากร) ไม่เข้าสู่ระบบ = เฉพาะ "ทั้งหมด"
  /// แบบฟอร์มทั่วไป — [category] ([FileCategory]) กรองตามเมนู ไม่ส่ง = ทุกหมวด
  Future<List<StoredFile>> getGeneralFiles({String? category}) async {
    final query = category == null ? null : {'category': category};
    final r = _isLoggedIn
        ? await _authedRequest('GET', '/api/public/general-files', query: query)
        : await _publicRequest(
            'GET',
            '/api/public/general-files',
            query: query,
          );
    return _files(r, 'โหลดรายการแบบฟอร์มไม่สำเร็จ');
  }

  Future<DownloadedFile> downloadGeneralFile(StoredFile f) => _download(
    'GET',
    '/api/public/general-files/${f.id}/download',
    fallbackName: f.fileName.isEmpty ? '${f.title}.${f.extension}' : f.fileName,
    failMessage: 'ดาวน์โหลดไฟล์ไม่สำเร็จ',
    public: !_isLoggedIn,
  );

  /// ปี-เดือนที่มีทะเบียนคุมรายชื่อ ("2569-10" ...) ใหม่ก่อน
  Future<List<String>> getMonthYearPeriods() async {
    final r = await _authedRequest('GET', '/api/monthyear-files/year-months');
    if (r.statusCode == 200 && r.data is List) {
      final list = [for (final v in r.data as List) '$v']..sort();
      return list.reversed.toList();
    }
    throw _apiError(r.statusCode, r.data, 'โหลดรายการเดือนไม่สำเร็จ');
  }

  Future<List<StoredFile>> getMonthYearFiles(String yearMonth) async {
    final r = await _authedRequest(
      'GET',
      '/api/monthyear-files',
      query: {'yearMonth': yearMonth},
    );
    return _files(r, 'โหลดทะเบียนคุมรายชื่อไม่สำเร็จ');
  }

  Future<DownloadedFile> downloadMonthYearFile(StoredFile f) => _download(
    'GET',
    '/api/monthyear-files/${f.id}/download',
    fallbackName: f.fileName.isEmpty ? f.title : f.fileName,
    failMessage: 'ดาวน์โหลดไฟล์ไม่สำเร็จ',
  );

  // ===================================================================
  // นำไฟล์เข้า (UPLOADER / ADMIN) — kind = general / monthyear
  // ===================================================================

  /// ขนาดไฟล์สูงสุดที่ backend รับ
  static const int maxUploadBytes = 20 * 1024 * 1024;

  /// นามสกุลที่ backend รับ
  static const List<String> uploadExtensions = [
    'pdf',
    'doc',
    'docx',
    'xls',
    'xlsx',
    'zip',
  ];

  Future<List<StoredFile>> getUploadFiles(
    String kind, {
    String? yearMonth,
  }) async {
    final r = await _authedRequest(
      'GET',
      '/api/upload/$kind-files',
      query: {
        if (yearMonth != null && yearMonth.isNotEmpty) 'yearMonth': yearMonth,
      },
    );
    return _files(r, 'โหลดรายการไฟล์ไม่สำเร็จ');
  }

  /// นำไฟล์ใหม่เข้า (multipart) [yearMonth] ส่งเฉพาะทะเบียนคุม
  Future<StoredFile> uploadFile(
    String kind, {
    required Uint8List bytes,
    required String fileName,
    String? typeFile,
    required String title,
    required int fileFor,
    String? yearMonth,
    String? category,
  }) async {
    final r = await _multipart('/api/upload/$kind-files', () {
      return FormData.fromMap({
        if ((typeFile ?? '').trim().isNotEmpty) 'typeFile': typeFile!.trim(),
        'title': title.trim(),
        'fileFor': '$fileFor',
        'category': ?category,
        if (yearMonth != null && yearMonth.isNotEmpty) 'yearMonth': yearMonth,
        'file': MultipartFile.fromBytes(bytes, filename: fileName),
      });
    });
    if (r.statusCode == 200 && r.data is Map) {
      return StoredFile.fromJson(Map<String, dynamic>.from(r.data));
    }
    throw _apiError(r.statusCode, r.data, 'นำไฟล์เข้าไม่สำเร็จ');
  }

  /// แก้รายละเอียดของไฟล์ (ไม่เปลี่ยนตัวไฟล์)
  Future<StoredFile> updateUploadFile(
    String kind,
    String id, {
    String? typeFile,
    required String title,
    required int fileFor,
    String? yearMonth,
    String? category,
  }) async {
    final r = await _authedRequest(
      'PUT',
      '/api/upload/$kind-files/$id',
      data: {
        'typeFile': (typeFile ?? '').trim().isEmpty ? null : typeFile!.trim(),
        'title': title.trim(),
        'fileFor': fileFor,
        'yearMonth': yearMonth,
        'category': category,
      },
    );
    if (r.statusCode == 200 && r.data is Map) {
      return StoredFile.fromJson(Map<String, dynamic>.from(r.data));
    }
    throw _apiError(r.statusCode, r.data, 'บันทึกรายละเอียดไฟล์ไม่สำเร็จ');
  }

  Future<String> deleteUploadFile(String kind, String id) async {
    final r = await _authedRequest('DELETE', '/api/upload/$kind-files/$id');
    if (r.statusCode == 200) return _messageFrom(r.data) ?? 'ลบไฟล์เรียบร้อย';
    throw _apiError(r.statusCode, r.data, 'ลบไฟล์ไม่สำเร็จ');
  }

  // ===================================================================
  // ใบเสร็จรับเงิน
  // ===================================================================

  /// งวดใบเสร็จของสมาชิกที่เข้าสู่ระบบ (MEMBER)
  Future<List<ReceiptPeriod>> getReceiptPeriods() async {
    final r = await _authedRequest('GET', '/api/receipts/periods');
    if (r.statusCode == 200 && r.data is List) {
      return [
        for (final p in r.data as List)
          if (p is Map) ReceiptPeriod.fromJson(Map<String, dynamic>.from(p)),
      ];
    }
    throw _apiError(r.statusCode, r.data, 'โหลดงวดใบเสร็จไม่สำเร็จ');
  }

  /// PDF ใบเสร็จรายงวดที่เลือก (ไม่เกิน 24 งวด) ห้าม log [password]
  Future<DownloadedFile> downloadPeriodReceipts({
    required List<String> receiptNos,
    required String passwordType,
    String? password,
  }) => _download(
    'POST',
    '/api/receipts/pdf',
    data: {'receiptNos': receiptNos, ..._pdfPassword(passwordType, password)},
    fallbackName: 'receipt.pdf',
    failMessage: 'สร้างใบเสร็จไม่สำเร็จ',
  );

  /// ค้นสมาชิก (UPLOADER / ADMIN) พิมพ์อย่างน้อย 2 ตัว
  Future<List<MemberHit>> searchMembers(String q) async {
    final r = await _authedRequest(
      'GET',
      '/api/members/search',
      query: {'q': q.trim()},
    );
    if (r.statusCode == 200 && r.data is List) {
      return [
        for (final m in r.data as List)
          if (m is Map) MemberHit.fromJson(Map<String, dynamic>.from(m)),
      ];
    }
    throw _apiError(r.statusCode, r.data, 'ค้นหาสมาชิกไม่สำเร็จ');
  }

  /// PDF ใบเสร็จเงินสดของปี [year] (พ.ศ.) เดือน [months]
  /// [memberNo] ส่งเฉพาะผู้นำไฟล์เข้า/ผู้ดูแลที่ออกให้ผู้อื่น (สมาชิก backend ใช้เลขของบัญชีเสมอ)
  Future<DownloadedFile> downloadCashReceipts({
    String? memberNo,
    required int year,
    required List<int> months,
    required String passwordType,
    String? password,
  }) {
    final ms = months.toSet().toList()..sort();
    return _download(
      'POST',
      '/api/cash-receipts/pdf',
      data: {
        if (memberNo != null && memberNo.trim().isNotEmpty)
          'memberNo': memberNo.trim(),
        'year': '$year',
        'months': ms,
        ..._pdfPassword(passwordType, password),
      },
      fallbackName: 'cash-receipt.pdf',
      failMessage: 'สร้างใบเสร็จเงินสดไม่สำเร็จ',
    );
  }

  static Map<String, dynamic> _pdfPassword(String type, String? password) => {
    'passwordType': type,
    if (type == PdfPassword.custom) 'password': password ?? '',
  };

  // ===================================================================
  // รายงานฌาปนกิจจากระบบหักหนี้ (UPLOADER / ADMIN)
  // ===================================================================

  static Map<String, dynamic> _period(int month, int year, [String? type]) => {
    'type': ?type,
    'month': month.toString().padLeft(2, '0'),
    'year': '$year',
  };

  /// rep9 (JSON): `{month, year, type, summary{...}, slip{...}, items[]}` — คำตอบมีเลขบัตร/ชื่อ ห้าม log
  Future<Map<String, dynamic>> getChapanaSlip({
    required String type,
    required int month,
    required int year,
  }) async {
    final r = await _authedRequest(
      'GET',
      '/api/reports/chapana-slip',
      query: _period(month, year, type),
      receiveTimeout: const Duration(minutes: 3),
    );
    if (r.statusCode == 200 && r.data is Map) {
      return Map<String, dynamic>.from(r.data);
    }
    throw _apiError(r.statusCode, r.data, 'ตรวจสอบฌาปนกิจกับสลิปไม่สำเร็จ');
  }

  Future<DownloadedFile> downloadChapanaSlipPdf({
    required String type,
    required int month,
    required int year,
  }) => _download(
    'GET',
    '/api/reports/chapana-slip/pdf',
    query: _period(month, year, type),
    fallbackName: 'rep9-${month.toString().padLeft(2, '0')}$year-$type.pdf',
    failMessage: 'ออกรายงานไม่สำเร็จ',
  );

  /// rep10 (JSON): `{month, year, items[]}` — ผู้เกษียณ/พ้นสภาพที่ยังมีรายการหักฌาปนกิจ
  Future<Map<String, dynamic>> getChapanaRetired({
    required int month,
    required int year,
  }) async {
    final r = await _authedRequest(
      'GET',
      '/api/reports/chapana-retired',
      query: _period(month, year),
      receiveTimeout: const Duration(minutes: 2),
    );
    if (r.statusCode == 200 && r.data is Map) {
      return Map<String, dynamic>.from(r.data);
    }
    throw _apiError(r.statusCode, r.data, 'โหลดรายชื่อผู้เกษียณไม่สำเร็จ');
  }

  Future<DownloadedFile> downloadChapanaRetiredPdf({
    required int month,
    required int year,
  }) => _download(
    'GET',
    '/api/reports/chapana-retired/pdf',
    query: _period(month, year),
    fallbackName: 'rep10-${month.toString().padLeft(2, '0')}$year.pdf',
    failMessage: 'ออกรายงานไม่สำเร็จ',
  );

  // ===================================================================
  // ผู้ดูแล (ADMIN)
  // ===================================================================

  Future<UserPage> searchUsers({
    String? keyword,
    int page = 0,
    int size = 10,
  }) async {
    final r = await _authedRequest(
      'GET',
      '/api/admin/users',
      query: {
        if ((keyword ?? '').trim().isNotEmpty) 'keyword': keyword!.trim(),
        'page': page,
        'size': size,
      },
    );
    if (r.statusCode == 200 && r.data is Map) {
      return UserPage.fromJson(Map<String, dynamic>.from(r.data));
    }
    throw _apiError(r.statusCode, r.data, 'โหลดรายชื่อผู้ใช้ไม่สำเร็จ');
  }

  Future<UserAdmin> updateUser(
    String id, {
    required String? personType,
    required List<String> assignedRoles,
    required bool active,
    required bool locked,
  }) async {
    final r = await _authedRequest(
      'PUT',
      '/api/admin/users/$id',
      data: UserAdmin.updateBody(
        personType: personType,
        assignedRoles: assignedRoles,
        active: active,
        locked: locked,
      ),
    );
    if (r.statusCode == 200 && r.data is Map) {
      return UserAdmin.fromJson(Map<String, dynamic>.from(r.data));
    }
    throw _apiError(r.statusCode, r.data, 'บันทึกข้อมูลผู้ใช้ไม่สำเร็จ');
  }

  Future<String> adminResetPassword(String id, String newPassword) =>
      _adminAction('/api/admin/users/$id/reset-password', {
        'newPassword': newPassword,
      }, 'ตั้งรหัสผ่านใหม่ไม่สำเร็จ');

  Future<String> adminDisableTwoFactor(String id) => _adminAction(
    '/api/admin/users/$id/disable-2fa',
    const {},
    'ปิด 2FA ของผู้ใช้ไม่สำเร็จ',
  );

  Future<String> adminDeletePasskeys(String id) => _adminAction(
    '/api/admin/users/$id/delete-passkeys',
    const {},
    'ลบ passkey ของผู้ใช้ไม่สำเร็จ',
  );

  Future<String> _adminAction(
    String path,
    Map<String, dynamic> data,
    String fallback,
  ) async {
    final r = await _authedRequest('POST', path, data: data);
    if (r.statusCode == 200 && r.data is Map && r.data['success'] != false) {
      return _messageFrom(r.data) ?? 'บันทึกเรียบร้อย';
    }
    throw _apiError(r.statusCode, r.data, fallback);
  }

  Future<List<RoleInfo>> getRoles() async {
    final r = await _authedRequest('GET', '/api/admin/roles');
    if (r.statusCode == 200 && r.data is List) {
      return [
        for (final m in r.data as List)
          if (m is Map) RoleInfo.fromJson(Map<String, dynamic>.from(m)),
      ];
    }
    throw _apiError(r.statusCode, r.data, 'โหลดรายการบทบาทไม่สำเร็จ');
  }

  Future<List<Uploader>> getUploaders() async {
    final r = await _authedRequest('GET', '/api/admin/uploaders');
    if (r.statusCode == 200 && r.data is List) {
      return [
        for (final m in r.data as List)
          if (m is Map) Uploader.fromJson(Map<String, dynamic>.from(m)),
      ];
    }
    throw _apiError(
      r.statusCode,
      r.data,
      'โหลดรายชื่อผู้มีสิทธิ์นำไฟล์เข้าไม่สำเร็จ',
    );
  }

  /// เพิ่มผู้มีสิทธิ์นำไฟล์เข้าด้วยเลขบัตร ห้าม log [idcard]
  ///
  /// เพิ่มได้เฉพาะเลขบัตรที่มีบัญชีลงทะเบียนแล้ว (ชื่อจากบัญชี) ยังไม่ลงทะเบียน = code `NOT_REGISTERED`
  Future<Uploader> addUploader(String idcard) async {
    final r = await _authedRequest(
      'POST',
      '/api/admin/uploaders',
      data: {'idcard': idcard},
    );
    if (r.statusCode == 200 && r.data is Map) {
      return Uploader.fromJson(Map<String, dynamic>.from(r.data));
    }
    throw _apiError(
      r.statusCode,
      r.data,
      'เพิ่มผู้มีสิทธิ์นำไฟล์เข้าไม่สำเร็จ',
    );
  }

  Future<String> deleteUploader(String id) async {
    final r = await _authedRequest('DELETE', '/api/admin/uploaders/$id');
    if (r.statusCode == 200) {
      return _messageFrom(r.data) ?? 'ลบผู้มีสิทธิ์นำไฟล์เข้าเรียบร้อย';
    }
    throw _apiError(r.statusCode, r.data, 'ลบผู้มีสิทธิ์นำไฟล์เข้าไม่สำเร็จ');
  }

  // ===================================================================
  // เพิ่มผู้ใช้งานทะเบียนคุม (ADMIN, UPLOADER)
  // ===================================================================

  /// บัญชีประเภท U เรียงวันสร้างใหม่ไปเก่า [keyword] ค้นชื่อ นามสกุล เลขบัตร บางส่วนได้ ห้าม log [keyword]
  Future<ControlUserList> getControlUsers({String? keyword}) async {
    final k = (keyword ?? '').trim();
    final r = await _authedRequest(
      'GET',
      '/api/upload/control-users',
      query: {if (k.isNotEmpty) 'q': k},
    );
    if (r.statusCode == 200 && r.data is Map) {
      return ControlUserList.fromJson(Map<String, dynamic>.from(r.data));
    }
    throw _apiError(r.statusCode, r.data, 'โหลดรายชื่อผู้ใช้ไม่สำเร็จ');
  }

  /// เปลี่ยนประเภทบุคลากร U → N (ใช้เมนูทะเบียนคุมได้ตั้งแต่เข้าสู่ระบบครั้งถัดไป)
  Future<ControlUser> grantControlUser(String id) async {
    final r = await _authedRequest(
      'PUT',
      '/api/upload/control-users/$id/grant',
    );
    if (r.statusCode == 200 && r.data is Map) {
      return ControlUser.fromJson(Map<String, dynamic>.from(r.data));
    }
    throw _apiError(r.statusCode, r.data, 'เปลี่ยนประเภทผู้ใช้ไม่สำเร็จ');
  }

  Future<List<SignatureItem>> getSignatures() async {
    final r = await _authedRequest('GET', '/api/admin/signatures');
    if (r.statusCode == 200 && r.data is List) {
      return [
        for (final m in r.data as List)
          if (m is Map) SignatureItem.fromJson(Map<String, dynamic>.from(m)),
      ];
    }
    throw _apiError(r.statusCode, r.data, 'โหลดรายการลายเซ็นไม่สำเร็จ');
  }

  /// บันทึกลายเซ็น (รูป JPEG/PNG ≤ 2 MB) [positionLines] ส่งซ้ำได้หลายค่า (บรรทัดละค่า)
  Future<SignatureItem> saveSignature({
    required String kind,
    required String name,
    required List<String> positionLines,
    required String effectiveFrom,
    required Uint8List bytes,
    required String fileName,
  }) async {
    final lower = fileName.toLowerCase();
    final mime = lower.endsWith('.png') ? 'image/png' : 'image/jpeg';
    final r = await _multipart('/api/admin/signatures', () {
      final form = FormData();
      form.fields
        ..add(MapEntry('kind', kind))
        ..add(MapEntry('name', name.trim()))
        ..add(MapEntry('effectiveFrom', effectiveFrom));
      for (final l in positionLines) {
        if (l.trim().isNotEmpty) {
          form.fields.add(MapEntry('positionLines', l.trim()));
        }
      }
      form.files.add(
        MapEntry(
          'file',
          MultipartFile.fromBytes(
            bytes,
            filename: fileName,
            contentType: DioMediaType.parse(mime),
          ),
        ),
      );
      return form;
    });
    if (r.statusCode == 200 && r.data is Map) {
      return SignatureItem.fromJson(Map<String, dynamic>.from(r.data));
    }
    throw _apiError(r.statusCode, r.data, 'บันทึกลายเซ็นไม่สำเร็จ');
  }

  Future<String> deleteSignature(String id) async {
    final r = await _authedRequest('DELETE', '/api/admin/signatures/$id');
    if (r.statusCode == 200) {
      return _messageFrom(r.data) ?? 'ลบลายเซ็นเรียบร้อย';
    }
    throw _apiError(r.statusCode, r.data, 'ลบลายเซ็นไม่สำเร็จ');
  }

  Future<Uint8List> getSignatureImage(String id) async {
    final r = await _authedRequest(
      'GET',
      '/api/admin/signatures/$id/image',
      responseType: ResponseType.bytes,
    );
    final bytes = _bytesOf(r.data);
    if (r.statusCode == 200 && bytes != null && bytes.isNotEmpty) return bytes;
    throw _apiError(
      r.statusCode,
      _decodeBody(r.data),
      'โหลดรูปลายเซ็นไม่สำเร็จ',
    );
  }

  /// นำเข้า CSV ข้อมูลเดิม ([kind] = general / monthyear) รันซ้ำได้ (ข้ามรายการที่มีแล้ว)
  Future<LegacyImportResult> importLegacy(
    String kind, {
    required Uint8List bytes,
    required String fileName,
  }) async {
    final r = await _multipart(
      '/api/admin/import/$kind',
      () => FormData.fromMap({
        'file': MultipartFile.fromBytes(
          bytes,
          filename: fileName,
          contentType: DioMediaType.parse('text/csv'),
        ),
      }),
      timeout: const Duration(minutes: 10),
    );
    if (r.statusCode == 200 && r.data is Map) {
      return LegacyImportResult.fromJson(Map<String, dynamic>.from(r.data));
    }
    throw _apiError(r.statusCode, r.data, 'นำเข้าข้อมูลเดิมไม่สำเร็จ');
  }

  // ===================================================================
  // ตัวช่วยภายใน
  // ===================================================================

  List<StoredFile> _files(Response<dynamic> r, String fallback) {
    if (r.statusCode == 200 && r.data is List) {
      return [
        for (final f in r.data as List)
          if (f is Map) StoredFile.fromJson(Map<String, dynamic>.from(f)),
      ];
    }
    throw _apiError(r.statusCode, r.data, fallback);
  }

  static Map<String, dynamic> _publicKeyOf(
    Response<dynamic> r,
    String fallback,
  ) {
    final pk = r.data is Map ? r.data['publicKey'] : null;
    if (r.statusCode == 200 && pk is Map) return Map<String, dynamic>.from(pk);
    throw _apiError(r.statusCode, r.data, fallback);
  }

  /// คำขอที่ต้องเข้าสู่ระบบ รับ 4xx (ยกเว้น 401 ที่ interceptor ต่ออายุแล้วยิงซ้ำ) กลับมาแปลเอง
  Future<Response<dynamic>> _authedRequest(
    String method,
    String path, {
    Map<String, dynamic>? query,
    Object? data,
    ResponseType? responseType,
    Duration? receiveTimeout,
  }) async {
    await _ensureToken();
    try {
      return await dio.request(
        path,
        queryParameters: query,
        data: data,
        options: Options(
          method: method,
          responseType: responseType,
          receiveTimeout: receiveTimeout,
          validateStatus: (s) => s != null && s < 500 && s != 401,
        ),
      );
    } on DioException catch (e) {
      if (AppLogger.on) AppLogger.e('🔴 $method $path: ${e.type}');
      throw _dioError(e);
    }
  }

  /// คำขอเส้นสาธารณะ (ไม่แนบ token) รับทุกรหัสสถานะกลับมาแปลเอง
  Future<Response<dynamic>> _publicRequest(
    String method,
    String path, {
    Map<String, dynamic>? query,
    Object? data,
    ResponseType? responseType,
  }) async {
    try {
      return await publicDio.request(
        path,
        queryParameters: query,
        data: data,
        options: Options(
          method: method,
          responseType: responseType,
          validateStatus: (_) => true,
        ),
      );
    } on DioException catch (e) {
      if (AppLogger.on) AppLogger.e('🔴 $method $path: ${e.type}');
      throw _dioError(e);
    }
  }

  /// POST เส้นสาธารณะ — ไม่ log ตัวข้อมูลที่ส่ง (มีรหัสผ่าน/เลขบัตร/ticket)
  Future<Response<dynamic>> _publicPost(
    String path,
    Map<String, dynamic> data,
  ) => _publicRequest('POST', path, data: data);

  /// POST multipart ที่ต้องเข้าสู่ระบบ: FormData ส่งซ้ำไม่ได้ จึงรับ 401 เอง ต่ออายุ token แล้วสร้างใหม่ส่งอีกครั้ง
  Future<Response<dynamic>> _multipart(
    String path,
    FormData Function() build, {
    Duration timeout = const Duration(minutes: 2),
  }) async {
    await _ensureToken();
    Future<Response<dynamic>> send() async {
      final token = await getAccessToken();
      return publicDio.post(
        path,
        data: build(),
        options: Options(
          headers: {if (token != null) 'Authorization': 'Bearer $token'},
          sendTimeout: timeout,
          receiveTimeout: timeout,
          validateStatus: (s) => s != null && s < 500,
        ),
      );
    }

    try {
      var r = await send();
      if (r.statusCode == 401) {
        await refreshToken();
        r = await send();
      }
      return r;
    } on DioException catch (e) {
      if (AppLogger.on) AppLogger.e('🔴 POST $path: ${e.type}');
      throw _dioError(e);
    }
  }

  /// ดาวน์โหลดไฟล์ (PDF/เอกสาร) เป็นไบต์ ชื่อไฟล์จาก Content-Disposition (ไม่มี = [fallbackName])
  /// ข้อผิดพลาดมาเป็นไบต์ ถอดเป็น JSON แล้วโยน [ApiException] พร้อมข้อความของ backend
  Future<DownloadedFile> _download(
    String method,
    String path, {
    Map<String, dynamic>? query,
    Object? data,
    required String fallbackName,
    required String failMessage,
    bool public = false,
  }) async {
    final r = public
        ? await _publicRequest(
            method,
            path,
            query: query,
            data: data,
            responseType: ResponseType.bytes,
          )
        : await _authedRequest(
            method,
            path,
            query: query,
            data: data,
            responseType: ResponseType.bytes,
            receiveTimeout: const Duration(minutes: 3),
          );
    final bytes = _bytesOf(r.data);
    if (r.statusCode == 200 && bytes != null) {
      final mime =
          r.headers.value(Headers.contentTypeHeader) ??
          'application/octet-stream';
      return DownloadedFile(
        bytes: bytes,
        fileName:
            fileNameFromDisposition(r.headers.value('content-disposition')) ??
            fallbackName,
        mime: mime,
      );
    }
    throw _apiError(r.statusCode, _decodeBody(r.data), failMessage);
  }

  /// ชื่อไฟล์จาก header Content-Disposition — รองรับ `filename*=UTF-8''...` (ชื่อไทย) และ `filename="..."`
  @visibleForTesting
  static String? fileNameFromDisposition(String? header) {
    if (header == null || header.isEmpty) return null;
    final star = RegExp(
      r"filename\*\s*=\s*([^']*)''([^;]+)",
      caseSensitive: false,
    ).firstMatch(header);
    if (star != null) {
      try {
        return Uri.decodeComponent(star.group(2)!.trim());
      } catch (_) {}
    }
    final plain = RegExp(
      r'filename\s*=\s*"?([^";]+)"?',
      caseSensitive: false,
    ).firstMatch(header);
    final name = plain?.group(1)?.trim();
    return name == null || name.isEmpty ? null : name;
  }

  static Uint8List? _bytesOf(Object? data) => data is Uint8List
      ? data
      : (data is List<int> ? Uint8List.fromList(data) : null);

  /// ตัวข้อมูลที่มาเป็นไบต์/ข้อความ ถอดเป็น JSON (ถอดไม่ได้ = null)
  static dynamic _decodeBody(dynamic data) {
    try {
      if (data is List<int>) {
        return jsonDecode(utf8.decode(data, allowMalformed: true));
      }
      if (data is String) return jsonDecode(data);
    } catch (_) {
      return null;
    }
    return data;
  }

  ApiException _dioError(DioException e) {
    final body = _decodeBody(e.response?.data);
    return ApiException(
      _messageFrom(body) ?? _connectionMessage(e),
      statusCode: e.response?.statusCode,
      code: _codeFrom(body),
    );
  }

  static String _connectionMessage(DioException e) => switch (e.type) {
    DioExceptionType.connectionTimeout ||
    DioExceptionType.sendTimeout ||
    DioExceptionType.receiveTimeout =>
      'หมดเวลาเชื่อมต่อเซิร์ฟเวอร์ กรุณาลองใหม่อีกครั้ง',
    DioExceptionType.connectionError =>
      'ไม่สามารถเชื่อมต่อกับเซิร์ฟเวอร์ได้ กรุณาตรวจสอบการเชื่อมต่ออินเทอร์เน็ต',
    DioExceptionType.badCertificate =>
      'ใบรับรองความปลอดภัยของเซิร์ฟเวอร์ไม่ถูกต้อง',
    DioExceptionType.badResponse => switch (e.response?.statusCode) {
      502 ||
      503 ||
      504 => 'เซิร์ฟเวอร์ไม่พร้อมให้บริการชั่วคราว กรุณาลองใหม่ภายหลัง',
      _ => 'เกิดข้อผิดพลาดที่เซิร์ฟเวอร์ (${e.response?.statusCode})',
    },
    _ => 'เกิดข้อผิดพลาดในการเชื่อมต่อ กรุณาลองใหม่อีกครั้ง',
  };

  /// ข้อผิดพลาดจากคำตอบ: ใช้ `message` ของ backend ก่อน ไม่มีจึงใช้ข้อความตั้งต้น
  static ApiException _apiError(int? status, dynamic body, String fallback) {
    return ApiException(
      _messageFrom(body) ??
          switch (status) {
            403 => 'คุณไม่มีสิทธิ์ใช้งานส่วนนี้',
            429 => 'ทำรายการถี่เกินไป กรุณารอสักครู่แล้วลองใหม่',
            _ => status == null ? fallback : '$fallback ($status)',
          },
      statusCode: status,
      code: _codeFrom(body),
    );
  }

  static String? _messageFrom(dynamic body) {
    final m = body is Map ? body['message'] : null;
    return m == null || '$m'.trim().isEmpty ? null : '$m';
  }

  static String? _codeFrom(dynamic body) {
    final code = body is Map ? body['code'] : null;
    return code is String && code.isNotEmpty ? code : null;
  }

  static String? _strOrNull(Object? v) {
    final s = '${v ?? ''}'.trim();
    return s.isEmpty || s == 'null' ? null : s;
  }
}

/// ข้อผิดพลาดจาก backend ที่มีข้อความให้ผู้ใช้อ่าน ([toString] คืนข้อความล้วน)
class ApiException implements Exception {
  final String message;
  final int? statusCode;

  /// รหัสข้อผิดพลาดของ backend (ช่อง `code`) ดู [ErrorCodes] ไม่มี = null
  final String? code;

  const ApiException(this.message, {this.statusCode, this.code});

  @override
  String toString() => message;
}
