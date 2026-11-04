// backend จำลองสำหรับเทสต์ ตอบตามสัญญาของ Spring Boot `funeral` (ดู CLAUDE.md หัวข้อ "สัญญากับ backend")
//
// ใช้เป็น HttpClientAdapter ของ Dio ทั้งสองตัวใน ApiService (dio และ publicDio)
// จึงทดสอบ AuthInterceptor ตัวจริงได้ ไม่ต้องจำลอง interceptor
// **ข้อมูลทั้งหมดเป็นค่าสมมุติ** (ชื่อ "ทดสอบ ..." เลขบัตรสร้างจากเลขสมมุติ) ห้ามใส่ข้อมูลบุคคลจริง

import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:funeral_web/services/api_service.dart';

/// เลขบัตรประชาชนสมมุติที่ผ่านหลักตรวจสอบ จากเลข 12 หลักแรก
String fakeIdcard(String first12) {
  var sum = 0;
  for (var i = 0; i < 12; i++) {
    sum += int.parse(first12[i]) * (13 - i);
  }
  return '$first12${(11 - sum % 11) % 10}';
}

/// รหัส 6 หลักที่ backend จำลองถือว่าถูก
const String fakeTotpCode = '123456';

/// รหัสตั้งค่า 2FA สมมุติ (Base32)
const String fakeTotpSecret = 'JBSWY3DPEHPK3PXPJBSWY3DPEHPK3PXP';

/// ไบต์ของ PDF สมมุติ
final Uint8List fakePdf = Uint8List.fromList(utf8.encode('%PDF-1.4 fake'));

/// รูป PNG 1x1
final Uint8List fakePng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
);

class FakeUser {
  final String id;
  String password;
  final String fullName;
  final String idcard;
  final String? memberNo;
  String? personType;
  List<String> roles;
  bool mustChange;
  bool twoFactor;

  FakeUser({
    required this.id,
    required this.password,
    required this.fullName,
    required this.idcard,
    this.memberNo,
    this.personType,
    required this.roles,
    this.mustChange = false,
    this.twoFactor = false,
  });
}

/// ผลของ ThaID ที่จำลองไว้ต่อ state: วัตถุประสงค์ + เลขบัตร
class FakeThaid {
  final String purpose;
  final String idcard;

  const FakeThaid(this.purpose, this.idcard);
}

class FakeBackend implements HttpClientAdapter {
  final Map<String, FakeUser> users = {
    'admin1': FakeUser(
      id: 'u-admin',
      password: 'Admin@2569x',
      fullName: 'ทดสอบ ผู้ดูแล',
      idcard: fakeIdcard('100000000001'),
      personType: 'G',
      roles: ['NON_MEMBER', 'UPLOADER', 'ADMIN'],
    ),
    'upload1': FakeUser(
      id: 'u-upload',
      password: 'Upload@2569x',
      fullName: 'ทดสอบ นำไฟล์เข้า',
      idcard: fakeIdcard('100000000002'),
      memberNo: '90002',
      personType: 'E',
      roles: ['MEMBER', 'UPLOADER'],
    ),
    'member1': FakeUser(
      id: 'u-member',
      password: 'Member@2569x',
      fullName: 'ทดสอบ สมาชิก',
      idcard: fakeIdcard('100000000003'),
      memberNo: '90003',
      personType: 'G',
      roles: ['MEMBER'],
    ),
    'nonmember1': FakeUser(
      id: 'u-non',
      password: 'NonMember@2569x',
      fullName: 'ทดสอบ ไม่ใช่สมาชิก',
      idcard: fakeIdcard('100000000004'),
      personType: 'E',
      roles: ['NON_MEMBER'],
    ),
    'otpuser1': FakeUser(
      id: 'u-otp',
      password: 'Otp@2569xx',
      fullName: 'ทดสอบ สองขั้น',
      idcard: fakeIdcard('100000000005'),
      memberNo: '90005',
      roles: ['MEMBER'],
      twoFactor: true,
    ),
    'newbie1': FakeUser(
      id: 'u-new',
      password: 'Temp@2569xx',
      fullName: 'ทดสอบ มาใหม่',
      idcard: fakeIdcard('100000000006'),
      roles: ['NON_MEMBER'],
      mustChange: true,
    ),
  };

  // ── สถานะที่เทสต์ตั้ง/ตรวจได้ ─────────────────────────────────────

  /// ทุกคำขอ รูป "METHOD path"
  final List<String> calls = [];
  final List<Map<String, dynamic>> queries = [];
  final List<Map<String, dynamic>?> bodies = [];
  final List<String?> authHeaders = [];

  Map<String, dynamic>? bodyOf(String call) {
    final i = calls.lastIndexOf(call);
    return i < 0 ? null : bodies[i];
  }

  Map<String, dynamic>? queryOf(String call) {
    final i = calls.lastIndexOf(call);
    return i < 0 ? null : queries[i];
  }

  String? authOf(String call) {
    final i = calls.lastIndexOf(call);
    return i < 0 ? null : authHeaders[i];
  }

  int count(String call) => calls.where((c) => c == call).length;

  Map<String, dynamic> stats = {
    'registered': 1234,
    'members': 1000,
    'nonMembers': 234,
    'downloads': 56789,
    'generalFiles': 3,
  };

  /// แบบฟอร์มทั่วไป (fileFor 1/2/3) — backend จริงกรองตามผู้ดู ที่นี่กรองแบบเดียวกัน
  List<Map<String, dynamic>> generalFiles = [
    _file('g1', 1, 'แบบฟอร์ม', 'แบบคำขอสมัครสมาชิก', 'form1.pdf', 3),
    _file(
      'g2',
      2,
      'แบบฟอร์ม',
      'แบบเปลี่ยนผู้รับเงิน (ข้าราชการ)',
      'form2.docx',
      1,
    ),
    _file('g3', 3, 'ประกาศ', 'ประกาศอัตราเงินสงเคราะห์', 'notice.pdf', 3),
    _file(
      'g4',
      4,
      'แบบฟอร์ม',
      'แบบเปลี่ยนผู้รับเงิน (ลูกจ้างประจำ)',
      'form4.xlsx',
      2,
    ),
  ];

  /// ทะเบียนคุม: ปี-เดือน → รายการ
  Map<String, List<Map<String, dynamic>>> monthYearFiles = {
    '2569-09': [
      _file(
        'm1',
        1,
        'ทะเบียนคุม',
        'ทะเบียนคุม ก.ย. 69 ข้าราชการ',
        'reg-g.pdf',
        1,
        ym: '2569-09',
      ),
      _file(
        'm2',
        2,
        'ทะเบียนคุม',
        'ทะเบียนคุม ก.ย. 69 ลูกจ้าง',
        'reg-e.pdf',
        2,
        ym: '2569-09',
      ),
    ],
    '2569-08': [
      _file(
        'm3',
        3,
        'ทะเบียนคุม',
        'ทะเบียนคุม ส.ค. 69',
        'reg-08.pdf',
        3,
        ym: '2569-08',
      ),
    ],
  };

  /// งวดใบเสร็จของสมาชิก
  List<Map<String, dynamic>> periods = [
    {
      'receipt_no': '5003',
      'receipt_year': '2569',
      'month_desc': 'ก.ค. 69 - ธ.ค. 69',
      'receipt_date': '2026-12-31',
    },
    {
      'receipt_no': '5002',
      'receipt_year': '2569',
      'month_desc': 'ม.ค. 69 - มิ.ย. 69',
      'receipt_date': '2026-06-30',
    },
    {
      'receipt_no': '5001',
      'receipt_year': '2568',
      'month_desc': 'ก.ค. 68 - ธ.ค. 68',
      'receipt_date': '2025-12-31',
    },
  ];

  /// ผลค้นสมาชิก
  List<Map<String, dynamic>> memberHits = [
    {
      'member_no': '81001',
      'title': 'นาย',
      'firstname': 'ทดสอบ',
      'lastname': 'หนึ่ง',
      'org_name': 'สำนักทดสอบ',
      'membership': 'N',
    },
    {
      'member_no': '81002',
      'title': 'นาง',
      'firstname': 'ทดสอบ',
      'lastname': 'สอง',
      'org_name': 'แขวงทดสอบ',
      'membership': 'N',
    },
  ];

  /// ผลจำลองของ ThaID ต่อ state (เทสต์ตั้งก่อนกดปุ่ม — ตัวเปิด ThaID ปลอมคืน state นี้)
  final Map<String, FakeThaid> thaid = {};

  /// เลขบัตรในทะเบียนสมาชิก (เลขบัตร → เลขสมาชิก) และใน DPIS
  final Map<String, String> ffdMembers = {
    fakeIdcard('200000000001'): '70001',
    fakeIdcard('200000000002'): '70002',
  };
  final Set<String> dpis = {
    fakeIdcard('200000000001'),
    fakeIdcard('200000000002'),
    fakeIdcard('200000000003'),
  };

  /// ค.ศ. วันเกิดในทะเบียนสมาชิก (เลขบัตร → yyyy-MM-dd)
  final Map<String, String> birthDates = {
    fakeIdcard('200000000001'): '1975-03-05',
  };

  /// ใบผ่านลงทะเบียน → (เลขบัตร, เลขสมาชิก)
  final Map<String, (String, String?)> tickets = {};

  /// ตั้งไว้ = ใบผ่านทุกใบหมดอายุ
  bool ticketsExpired = false;

  /// รายงาน rep9: ผลที่ตอบ (null = 503 ยังไม่ตั้งค่า)
  Map<String, dynamic>? slipReport = {
    'month': '10',
    'year': '2569',
    'type': 'G',
    'summary': {
      'chapana_rows': 3,
      'matched': 1,
      'mismatch': 1,
      'not_in_slip': 1,
      'not_paid': 2,
      'chapana_amount': '300.00',
      'not_paid_amount': '200.00',
    },
    'slip': {'count': 2, 'not_in_chapana': 0},
    'items': [
      {
        'idcard': fakeIdcard('300000000001'),
        'name': 'ทดสอบ หักไม่ได้',
        'member_no': '60001',
        'dept_name': 'สำนักทดสอบ',
        'org_code': '01',
        'per_status': 1,
        'retired': false,
        'amount': '100.00',
        'slip_amount': '50.00',
        'status': 'MISMATCH',
        'pay_for': 'ศพที่ 1',
      },
      {
        'idcard': fakeIdcard('300000000002'),
        'name': 'ทดสอบ เกษียณ',
        'member_no': '60002',
        'dept_name': 'แขวงทดสอบ',
        'org_code': '02',
        'per_status': 2,
        'retired': true,
        'amount': '100.00',
        'slip_amount': '0.00',
        'status': 'NOT_IN_SLIP',
        'pay_for': '',
      },
    ],
    'success': true,
  };

  List<Map<String, dynamic>> retired = [
    {
      'type': 'G',
      'idcard': fakeIdcard('300000000003'),
      'title': 'นาย',
      'name': 'ทดสอบ',
      'surname': 'พ้นสภาพ',
      'divname': 'สำนักทดสอบ',
      'pos_name': 'นายช่าง',
      'member_no': '60003',
      'per_status': '2',
    },
  ];

  List<Map<String, dynamic>> uploaders = [
    {
      'id': 'up1',
      'idcard': fakeIdcard('100000000002'),
      'fullName': 'ทดสอบ นำไฟล์เข้า',
      'addedBy': 'admin1',
      'addedAt': '2026-10-28T10:00:00',
    },
  ];

  /// เอกสารหน้าแรกสองช่อง (INVITE ยังไม่มีไฟล์, REGULATION มีไฟล์)
  List<Map<String, dynamic>> homeDocuments = [
    {
      'slot': 'INVITE',
      'title':
          'ประชาสัมพันธ์และเชิญชวนสมัครเป็นสมาชิกการฌาปนกิจสงเคราะห์กรมทางหลวง',
      'available': false,
    },
    {
      'slot': 'REGULATION',
      'title': 'ข้อบังคับ ฌ.ส.ทล',
      'available': true,
      'fileName': 'rule.pdf',
      'size': 5632476,
      'uploadedBy': 'admin1',
      'uploadedAt': '2026-11-01T09:00:00',
    },
  ];

  List<Map<String, dynamic>> signatures = [
    {
      'id': 's1',
      'kind': 'RECEIVER',
      'name': '(ทดสอบ รับเงิน)',
      'positionLines': ['เจ้าหน้าที่ทดสอบ'],
      'effectiveFrom': '2569-10',
      'hasImage': true,
      'uploadedBy': 'admin1',
      'uploadedAt': '2026-10-28T10:00:00',
    },
  ];

  bool twoFactorEnabledFor(String username) => users[username]!.twoFactor;

  /// passkey ของบัญชี (username → รายการ)
  final Map<String, List<Map<String, dynamic>>> passkeys = {};

  /// ตอบด้วยรหัสสถานะ/ข้อผิดพลาดนี้กับเส้นที่ระบุ (เช่น {'POST /api/receipts/pdf': (400, 'BAD_REQUEST', '...')})
  final Map<String, (int, String, String)> failures = {};

  final Map<String, String> _access = {};
  final Map<String, String> _refresh = {};
  final Map<String, String> _challenges = {};
  int _serial = 0;

  static Map<String, dynamic> _file(
    String id,
    int num,
    String type,
    String title,
    String fileName,
    int fileFor, {
    String? ym,
  }) => {
    'id': id,
    'num': num,
    'typeFile': type,
    'title': title,
    'fileName': fileName,
    'fileFor': fileFor,
    'yearMonth': ym,
    'size': 2048,
    'contentType': 'application/pdf',
    'sha256': 'x',
    'uploadedBy': 'upload1',
    'uploadedAt': '2026-10-28T10:15:00',
    'legacy': false,
  };

  void expireAccessTokens() => _access.clear();

  String _jwt(String username) {
    String part(Object o) =>
        base64Url.encode(utf8.encode(jsonEncode(o))).replaceAll('=', '');
    final exp =
        DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/
        1000;
    return '${part({'alg': 'none'})}.${part({'sub': username, 'exp': exp, 'n': ++_serial})}.sig';
  }

  Map<String, dynamic> _loginBody(String username) {
    final u = users[username]!;
    final access = _jwt(username);
    final refresh = 'refresh-${++_serial}-xxxxxxxx';
    _access[access] = username;
    _refresh[refresh] = username;
    return {
      'access_token': access,
      'refresh_token': refresh,
      'token_type': 'Bearer',
      'expires_in': 3600,
      'message': 'เข้าสู่ระบบสำเร็จ',
      'username': username,
      'full_name': u.fullName,
      'member_no': u.memberNo,
      'person_type': u.personType,
      'roles': u.roles,
      'must_change_password': u.mustChange,
      'two_factor_required': false,
    };
  }

  ResponseBody _json(int status, Object body) => ResponseBody.fromString(
    jsonEncode(body),
    status,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );

  ResponseBody _err(int status, String code, String message) =>
      _json(status, {'code': code, 'message': message, 'success': false});

  ResponseBody _bytes(Uint8List bytes, String type, String fileName) =>
      ResponseBody.fromBytes(
        bytes,
        200,
        headers: {
          Headers.contentTypeHeader: [type],
          'content-disposition': [
            "attachment; filename*=UTF-8''${Uri.encodeComponent(fileName)}",
          ],
        },
      );

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final path = options.path;
    final method = options.method;
    final call = '$method $path';
    final auth = options.headers['Authorization'] as String?;
    calls.add(call);
    authHeaders.add(auth);
    final data = options.data;
    final body = data is Map
        ? Map<String, dynamic>.from(data)
        : data is FormData
        ? <String, dynamic>{
            for (final f in data.fields)
              f.key: data.fields.where((x) => x.key == f.key).length > 1
                  ? [
                      for (final x in data.fields)
                        if (x.key == f.key) x.value,
                    ]
                  : f.value,
            for (final f in data.files) ...{
              f.key: f.value.filename,
              '${f.key}Size': f.value.length,
            },
          }
        : null;
    queries.add(Map<String, dynamic>.from(options.queryParameters));
    bodies.add(body);

    final fail = failures[call];
    if (fail != null) return _err(fail.$1, fail.$2, fail.$3);

    final me = auth != null && auth.startsWith('Bearer ')
        ? _access[auth.substring(7)]
        : null;
    final user = me == null ? null : users[me];
    bool has(String role) => user?.roles.contains(role) ?? false;
    ResponseBody unauth() => _err(401, 'UNAUTHENTICATED', 'กรุณาเข้าสู่ระบบ');
    ResponseBody forbidden() =>
        _err(403, 'FORBIDDEN', 'คุณไม่มีสิทธิ์ใช้งานส่วนนี้');

    // ───────── เข้าสู่ระบบ ─────────
    if (call == 'POST /api/auth/login') {
      final u = users[body?['username']];
      if (u == null || u.password != body?['password']) {
        return _err(401, 'BAD_CREDENTIALS', 'ชื่อผู้ใช้หรือรหัสผ่านไม่ถูกต้อง');
      }
      if (u.twoFactor) {
        final c = 'challenge-${++_serial}-xxxxxxxx';
        _challenges[c] = body!['username'] as String;
        return _json(200, {'two_factor_required': true, 'challenge': c});
      }
      return _json(200, _loginBody(body!['username'] as String));
    }
    if (call == 'POST /api/auth/login/2fa') {
      final username = _challenges[body?['challenge']];
      if (username == null) {
        return _err(
          400,
          'TWO_FACTOR_REJECTED',
          'หมดเวลายืนยันตัวตน กรุณาเข้าสู่ระบบใหม่',
        );
      }
      if (body?['code'] != fakeTotpCode) {
        return _err(401, 'TWO_FACTOR_CODE_WRONG', 'รหัส 6 หลักไม่ถูกต้อง');
      }
      _challenges.remove(body?['challenge']);
      return _json(200, _loginBody(username));
    }
    if (call == 'POST /api/auth/refresh-token') {
      final username = _refresh.remove(body?['refresh_token']);
      if (username == null) {
        return _err(403, 'REFRESH_TOKEN_INVALID', 'กรุณาเข้าสู่ระบบใหม่');
      }
      final b = _loginBody(username);
      return _json(200, {
        'access_token': b['access_token'],
        'refresh_token': b['refresh_token'],
        'token_type': 'Bearer',
        'expires_in': 3600,
      });
    }
    if (call == 'POST /api/auth/logout') {
      if (auth != null) _access.remove(auth.replaceFirst('Bearer ', ''));
      _refresh.remove(body?['refresh_token']);
      return _json(200, {'message': 'ออกจากระบบแล้ว', 'success': true});
    }
    if (call == 'GET /api/auth/me') {
      if (user == null) return unauth();
      final b = _loginBody(me!);
      return _json(200, {
        'username': me,
        'full_name': b['full_name'],
        'member_no': b['member_no'],
        'person_type': b['person_type'],
        'roles': b['roles'],
        'previous_login': '2026-10-27T09:00:00',
        'must_change_password': user.mustChange,
      });
    }
    if (call == 'POST /api/auth/changepassword') {
      if (user == null) return unauth();
      if (body?['oldPassword'] != user.password) {
        return _err(400, 'BAD_REQUEST', 'รหัสผ่านเดิมไม่ถูกต้อง');
      }
      user.password = body!['newPassword'] as String;
      user.mustChange = false;
      return _json(200, {'message': 'เปลี่ยนรหัสผ่านสำเร็จ', 'success': true});
    }

    // ───────── ThaID ─────────
    if (call == 'GET /api/auth/public-thaid/status') {
      return _json(200, {
        'status': thaid.containsKey(options.queryParameters['state'])
            ? 'DONE'
            : 'GONE',
      });
    }
    if (path.startsWith('/api/auth/public-thaid/') && method == 'POST') {
      final purpose = path.substring('/api/auth/public-thaid/'.length);
      final r = thaid.remove(body?['state']);
      if (r == null) {
        return _err(
          400,
          'THAID_ERROR',
          'คำขอยืนยันตัวตนหมดอายุ กรุณาเริ่มใหม่',
        );
      }
      final wanted = purpose == 'login'
          ? 'login'
          : purpose == 'register'
          ? 'register'
          : 'reset';
      if (r.purpose != wanted) {
        return _err(
          400,
          'THAID_ERROR',
          'ผลยืนยันตัวตนนี้ใช้กับรายการนี้ไม่ได้',
        );
      }
      final account = users.entries
          .where((e) => e.value.idcard == r.idcard)
          .map((e) => e.key)
          .firstOrNull;
      if (purpose == 'login') {
        if (account == null) {
          return _err(
            404,
            'NOT_REGISTERED',
            'ยังไม่พบบัญชีของท่าน กรุณาลงทะเบียนก่อน',
          );
        }
        return _json(200, _loginBody(account));
      }
      if (purpose == 'reset') {
        if (account == null) {
          return _err(
            404,
            'NOT_REGISTERED',
            'ยังไม่พบบัญชีของท่าน กรุณาลงทะเบียนก่อน',
          );
        }
        users[account]!.password = body!['newPassword'] as String;
        return _json(200, {
          'message': 'ตั้งรหัสผ่านใหม่สำเร็จ ชื่อผู้ใช้ของท่านคือ $account',
          'success': true,
        });
      }
      // register
      if (account != null) {
        return _err(400, 'ALREADY_REGISTERED', 'เลขบัตรนี้ลงทะเบียนแล้ว');
      }
      final mode = body?['mode'];
      final memberNo = ffdMembers[r.idcard];
      if (mode == 'MEMBER' && memberNo == null) {
        return _err(400, 'NOT_MEMBER', 'ไม่พบเลขบัตรในทะเบียนสมาชิกฌาปนกิจ');
      }
      if (mode == 'NON_MEMBER' && !dpis.contains(r.idcard)) {
        return _err(400, 'NOT_IN_DPIS', 'ไม่พบข้อมูลบุคลากรของเลขบัตรนี้');
      }
      return _json(200, _ticket(r.idcard, memberNo));
    }

    // ───────── ลงทะเบียน ─────────
    if (call == 'POST /api/public/register/legacy-verify') {
      final idcard = '${body?['idcard']}';
      if (users.values.any((u) => u.idcard == idcard)) {
        return _err(400, 'ALREADY_REGISTERED', 'เลขบัตรนี้ลงทะเบียนแล้ว');
      }
      final no = ffdMembers[idcard];
      if (no == null || no != body?['memberNo']) {
        return _err(400, 'REGISTER_NOT_MATCH', 'ข้อมูลไม่ตรงกับทะเบียนสมาชิก');
      }
      return _json(200, _ticket(idcard, no));
    }
    if (call == 'POST /api/public/register/complete') {
      final t = tickets[body?['ticket']];
      if (t == null || ticketsExpired) {
        return _err(400, 'REGISTER_TICKET_INVALID', 'ใบผ่านหมดอายุหรือใช้แล้ว');
      }
      final name = '${body?['username']}';
      if (users.containsKey(name)) {
        return _err(409, 'DUPLICATE', 'ชื่อผู้ใช้นี้มีผู้ใช้แล้ว');
      }
      tickets.remove(body?['ticket']);
      users[name] = FakeUser(
        id: 'u-$name',
        password: '${body?['password']}',
        fullName: 'ทดสอบ ลงทะเบียนใหม่',
        idcard: t.$1,
        memberNo: t.$2,
        roles: [t.$2 == null ? 'NON_MEMBER' : 'MEMBER'],
      );
      return _json(200, {
        'success': true,
        'message':
            'ลงทะเบียนสำเร็จ กรุณาเข้าสู่ระบบด้วยชื่อผู้ใช้และรหัสผ่านที่ตั้งไว้',
        'username': name,
      });
    }

    // ───────── passkey สาธารณะ ─────────
    if (call == 'POST /api/public/passkey/options') {
      return _json(200, {
        'publicKey': {
          'challenge': 'Y2hhbGxlbmdl',
          'rpId': 'inf.doh.go.th',
          'allowCredentials': [],
        },
      });
    }
    if (call == 'POST /api/public/passkey/login') {
      if (body?['credential'] is! String) {
        return _err(
          400,
          'PASSKEY_INVALID',
          'ยืนยันตัวตนด้วย passkey ไม่สำเร็จ',
        );
      }
      return _json(200, _loginBody('member1'));
    }

    // ───────── สาธารณะ: สถิติ แบบฟอร์ม ─────────
    if (call == 'GET /api/public/stats') return _json(200, stats);
    if (call == 'GET /api/public/home-documents') {
      return _json(200, homeDocuments);
    }
    if (call == 'GET /api/public/general-files') {
      final pt = user?.personType;
      final staff = has('UPLOADER') || has('ADMIN');
      return _json(200, [
        for (final f in generalFiles)
          if (staff ||
              f['fileFor'] == 3 ||
              (pt == 'G' && f['fileFor'] == 1) ||
              (pt == 'E' && f['fileFor'] == 2))
            f,
      ]);
    }
    final gDl = RegExp(
      r'^/api/public/general-files/([^/]+)/download$',
    ).firstMatch(path);
    if (gDl != null) {
      final f = generalFiles.where((x) => x['id'] == gDl.group(1)).firstOrNull;
      if (f == null) return _err(404, 'NOT_FOUND', 'ไม่พบไฟล์');
      return _bytes(fakePdf, 'application/pdf', '${f['fileName']}');
    }

    // ───────── ต้องเข้าสู่ระบบตั้งแต่นี้ ─────────
    if (user == null) return unauth();

    if (call == 'GET /api/monthyear-files/year-months') {
      return _json(200, monthYearFiles.keys.toList());
    }
    if (call == 'GET /api/monthyear-files') {
      return _json(
        200,
        monthYearFiles[options.queryParameters['yearMonth']] ?? [],
      );
    }
    final mDl = RegExp(
      r'^/api/monthyear-files/([^/]+)/download$',
    ).firstMatch(path);
    if (mDl != null) {
      return _bytes(
        fakePdf,
        'application/pdf',
        'ทะเบียนคุม-${mDl.group(1)}.pdf',
      );
    }

    // ───────── นำไฟล์เข้า ─────────
    final hd = RegExp(
      r'^/api/upload/home-documents/([A-Z]+)$',
    ).firstMatch(path);
    if (hd != null) {
      if (!has('UPLOADER') && !has('ADMIN')) return forbidden();
      final d = homeDocuments.firstWhere((x) => x['slot'] == hd.group(1));
      if (method == 'DELETE') {
        d
          ..['available'] = false
          ..remove('fileName');
        return _json(200, {
          'message': 'เอาเอกสารออกจากหน้าแรกเรียบร้อย',
          'success': true,
        });
      }
      d['title'] = body?['title'];
      if (body?['file'] != null) {
        d
          ..['available'] = true
          ..['fileName'] = body!['file']
          ..['size'] = body['fileSize']
          ..['uploadedBy'] = me;
      }
      return _json(200, d);
    }
    final up = RegExp(
      r'^/api/upload/(general|monthyear)-files(?:/([^/]+))?$',
    ).firstMatch(path);
    if (up != null) {
      if (!has('UPLOADER') && !has('ADMIN')) return forbidden();
      final kind = up.group(1)!;
      final id = up.group(2);
      List<Map<String, dynamic>> all() => kind == 'general'
          ? generalFiles
          : [for (final l in monthYearFiles.values) ...l];
      if (method == 'GET') {
        final ym = options.queryParameters['yearMonth'];
        return _json(200, [
          for (final f in all())
            if (ym == null || f['yearMonth'] == ym) f,
        ]);
      }
      if (method == 'POST') {
        final f = _file(
          'new${++_serial}',
          100 + _serial,
          '${body?['typeFile'] ?? ''}',
          '${body?['title']}',
          '${body?['file']}',
          int.parse('${body?['fileFor']}'),
          ym: body?['yearMonth'] as String?,
        );
        if (kind == 'general') {
          generalFiles.add(f);
        } else {
          monthYearFiles.putIfAbsent('${body?['yearMonth']}', () => []).add(f);
        }
        return _json(200, f);
      }
      final f = all().where((x) => x['id'] == id).firstOrNull;
      if (f == null) return _err(404, 'NOT_FOUND', 'ไม่พบไฟล์');
      if (method == 'PUT') {
        f['title'] = body?['title'];
        f['typeFile'] = body?['typeFile'];
        f['fileFor'] = body?['fileFor'];
        if (kind == 'monthyear') f['yearMonth'] = body?['yearMonth'];
        return _json(200, f);
      }
      if (method == 'DELETE') {
        generalFiles.remove(f);
        for (final l in monthYearFiles.values) {
          l.remove(f);
        }
        return _json(200, {'message': 'ลบไฟล์เรียบร้อย', 'success': true});
      }
    }

    // ───────── ใบเสร็จ ─────────
    if (call == 'GET /api/receipts/periods') {
      if (!has('MEMBER')) return forbidden();
      return _json(200, periods);
    }
    if (call == 'POST /api/receipts/pdf') {
      if (!has('MEMBER')) return forbidden();
      final nos = body?['receiptNos'] as List? ?? const [];
      if (nos.isEmpty) {
        return _err(400, 'BAD_REQUEST', 'กรุณาเลือกงวดอย่างน้อย 1 งวด');
      }
      return _bytes(fakePdf, 'application/pdf', 'receipt.pdf');
    }
    if (call == 'GET /api/members/search') {
      if (!has('UPLOADER') && !has('ADMIN')) return forbidden();
      final q = '${options.queryParameters['q']}';
      return _json(200, [
        for (final m in memberHits)
          if ('${m['member_no']} ${m['firstname']} ${m['lastname']}'.contains(
            q,
          ))
            m,
      ]);
    }
    if (call == 'POST /api/cash-receipts/pdf') {
      final staff = has('UPLOADER') || has('ADMIN');
      if (!has('MEMBER') && !staff) return forbidden();
      final target = staff && body?['memberNo'] != null
          ? body!['memberNo']
          : user.memberNo;
      final own = target == user.memberNo;
      final type = body?['passwordType'];
      if (!own && (type == 'idcard' || type == 'birthdate')) {
        return _err(
          400,
          'BAD_REQUEST',
          'ใช้เลขบัตรเป็นรหัสได้เฉพาะใบเสร็จของตนเอง',
        );
      }
      return _bytes(fakePdf, 'application/pdf', 'cash-receipt.pdf');
    }

    // ───────── รายงาน ─────────
    if (path.startsWith('/api/reports/')) {
      if (!has('UPLOADER') && !has('ADMIN')) return forbidden();
      if (path == '/api/reports/chapana-slip') {
        final r = slipReport;
        if (r == null) {
          return _err(
            503,
            'DPAY_API_NOT_CONFIGURED',
            'ยังไม่ได้ตั้งค่าการเชื่อมต่อระบบหักหนี้',
          );
        }
        return _json(200, r);
      }
      if (path == '/api/reports/chapana-slip/pdf') {
        return _bytes(fakePdf, 'application/pdf', 'rep9-102569-G.pdf');
      }
      if (path == '/api/reports/chapana-retired') {
        return _json(200, {
          'month': '10',
          'year': '2569',
          'items': retired,
          'success': true,
        });
      }
      if (path == '/api/reports/chapana-retired/pdf') {
        return _bytes(fakePdf, 'application/pdf', 'rep10-102569.pdf');
      }
    }

    // ───────── บัญชี: 2FA / passkey ─────────
    if (call == 'GET /api/account/2fa') {
      return _json(200, {'enabled': user.twoFactor});
    }
    if (call == 'POST /api/account/2fa/setup') {
      if (body?['currentPassword'] != user.password) {
        return _err(400, 'BAD_REQUEST', 'รหัสผ่านปัจจุบันไม่ถูกต้อง');
      }
      return _json(200, {
        'secret': fakeTotpSecret,
        'otpauth_uri':
            'otpauth://totp/Funeral:$me?secret=$fakeTotpSecret&issuer=Funeral',
      });
    }
    if (call == 'POST /api/account/2fa/enable') {
      if (body?['code'] != fakeTotpCode) {
        return _err(401, 'TWO_FACTOR_CODE_WRONG', 'รหัส 6 หลักไม่ถูกต้อง');
      }
      user.twoFactor = true;
      return _json(200, {
        'message': 'เปิดใช้การยืนยันตัวตนสองขั้นเรียบร้อย',
        'success': true,
      });
    }
    if (call == 'POST /api/account/2fa/disable') {
      if (body?['currentPassword'] != user.password) {
        return _err(400, 'BAD_REQUEST', 'รหัสผ่านปัจจุบันไม่ถูกต้อง');
      }
      if (body?['code'] != fakeTotpCode) {
        return _err(401, 'TWO_FACTOR_CODE_WRONG', 'รหัส 6 หลักไม่ถูกต้อง');
      }
      user.twoFactor = false;
      return _json(200, {
        'message': 'ปิดการยืนยันตัวตนสองขั้นเรียบร้อย',
        'success': true,
      });
    }
    if (call == 'GET /api/account/passkeys') {
      return _json(200, passkeys[me] ?? []);
    }
    if (call == 'POST /api/account/passkeys/options') {
      if (body?['currentPassword'] != user.password) {
        return _err(400, 'BAD_REQUEST', 'รหัสผ่านปัจจุบันไม่ถูกต้อง');
      }
      return _json(200, {
        'publicKey': {
          'challenge': 'Y2hhbGxlbmdl',
          'rp': {'id': 'inf.doh.go.th'},
        },
      });
    }
    if (call == 'POST /api/account/passkeys') {
      final p = {
        'id': 'pk${++_serial}',
        'name': 'ฌาปนกิจ: ${body?['name']}',
        'createdAt': '2026-10-28T10:00:00',
        'lastUsedAt': null,
        'synced': false,
      };
      passkeys.putIfAbsent(me!, () => []).add(p);
      return _json(200, p);
    }
    final pkDel = RegExp(r'^/api/account/passkeys/([^/]+)$').firstMatch(path);
    if (pkDel != null && method == 'DELETE') {
      passkeys[me]?.removeWhere((p) => p['id'] == pkDel.group(1));
      return _json(200, {'message': 'ลบ passkey เรียบร้อย', 'success': true});
    }

    // ───────── ผู้ดูแล ─────────
    if (path.startsWith('/api/admin/')) {
      if (!has('ADMIN')) return forbidden();
      if (call == 'GET /api/admin/roles') {
        return _json(200, [
          {
            'name': 'NON_MEMBER',
            'description': 'ไม่ใช่สมาชิก',
            'assignable': false,
          },
          {
            'name': 'MEMBER',
            'description': 'สมาชิกฌาปนกิจ',
            'assignable': false,
          },
          {
            'name': 'UPLOADER',
            'description': 'ผู้นำไฟล์เข้าระบบ',
            'assignable': false,
          },
          {'name': 'ADMIN', 'description': 'ผู้ดูแลระบบ', 'assignable': true},
        ]);
      }
      if (call == 'GET /api/admin/users') {
        final kw = '${options.queryParameters['keyword'] ?? ''}';
        final size = int.parse('${options.queryParameters['size'] ?? 10}');
        final page = int.parse('${options.queryParameters['page'] ?? 0}');
        final all = [
          for (final e in users.entries)
            if (kw.isEmpty ||
                e.key.contains(kw) ||
                e.value.fullName.contains(kw))
              _userDto(e.key, e.value),
        ];
        final pages = (all.length / size).ceil();
        return _json(200, {
          'users': all.skip(page * size).take(size).toList(),
          'currentPage': page,
          'totalItems': all.length,
          'totalPages': pages,
          'pageSize': size,
        });
      }
      final um = RegExp(
        r'^/api/admin/users/([^/]+)(?:/(reset-password|disable-2fa|delete-passkeys))?$',
      ).firstMatch(path);
      if (um != null) {
        final entry = users.entries
            .where((e) => e.value.id == um.group(1))
            .firstOrNull;
        if (entry == null) return _err(404, 'NOT_FOUND', 'ไม่พบผู้ใช้ที่ระบุ');
        final u = entry.value;
        switch (um.group(2)) {
          case null:
            if (method == 'PUT') {
              u.personType = body?['personType'] as String?;
              final assigned = List<String>.from(body?['assignedRoles'] ?? []);
              u.roles = [...u.roles.where((r) => r != 'ADMIN'), ...assigned];
              return _json(200, _userDto(entry.key, u));
            }
          case 'reset-password':
            u.password = '${body?['newPassword']}';
            u.mustChange = true;
            return _json(200, {
              'message':
                  'ตั้งรหัสผ่านใหม่สำเร็จ ผู้ใช้ต้องเปลี่ยนรหัสผ่านตอนเข้าสู่ระบบครั้งถัดไป',
              'success': true,
            });
          case 'disable-2fa':
            u.twoFactor = false;
            return _json(200, {
              'message': 'ปิดการยืนยันตัวตนสองขั้นของผู้ใช้นี้แล้ว',
              'success': true,
            });
          case 'delete-passkeys':
            passkeys.remove(entry.key);
            return _json(200, {
              'message': 'ลบ passkey ทั้งหมดของผู้ใช้นี้แล้ว',
              'success': true,
            });
        }
      }
      if (call == 'GET /api/admin/uploaders') return _json(200, uploaders);
      if (call == 'POST /api/admin/uploaders') {
        final idcard = '${body?['idcard']}';
        final typed = '${body?['fullName'] ?? ''}'.trim();
        final inDpis = dpis.contains(idcard);
        final account = users.values
            .where((u) => u.idcard == idcard && u.fullName.trim().isNotEmpty)
            .map((u) => u.fullName.trim())
            .firstOrNull;
        if (!inDpis && account == null && typed.isEmpty) {
          return _err(
            400,
            'NOT_IN_DPIS',
            'ไม่พบเลขบัตรนี้ในทะเบียนบุคลากร (DPIS) กรุณากรอกชื่อ-สกุลเพื่อเพิ่ม',
          );
        }
        final u = {
          'id': 'up${++_serial}',
          'idcard': idcard,
          'fullName': inDpis ? 'ทดสอบ ผู้นำไฟล์ใหม่' : (account ?? typed),
          'nameSource': inDpis
              ? 'DPIS'
              : (account != null ? 'ACCOUNT' : 'MANUAL'),
          'addedBy': me,
          'addedAt': '2026-11-01T09:00:00',
        };
        uploaders.add(u);
        return _json(200, u);
      }
      final ud = RegExp(r'^/api/admin/uploaders/([^/]+)$').firstMatch(path);
      if (ud != null && method == 'DELETE') {
        uploaders.removeWhere((u) => u['id'] == ud.group(1));
        return _json(200, {
          'message':
              'ลบผู้มีสิทธิ์นำไฟล์เข้าเรียบร้อย มีผลเมื่อผู้นั้นเข้าสู่ระบบครั้งถัดไป',
          'success': true,
        });
      }
      if (call == 'GET /api/admin/signatures') return _json(200, signatures);
      if (call == 'POST /api/admin/signatures') {
        final lines = body?['positionLines'];
        final s = {
          'id': 's${++_serial}',
          'kind': body?['kind'],
          'name': body?['name'],
          'positionLines': lines is List ? lines : [?lines],
          'effectiveFrom': body?['effectiveFrom'],
          'hasImage': true,
          'uploadedBy': me,
          'uploadedAt': '2026-11-01T09:00:00',
        };
        signatures.insert(0, s);
        return _json(200, s);
      }
      final si = RegExp(
        r'^/api/admin/signatures/([^/]+)(/image)?$',
      ).firstMatch(path);
      if (si != null) {
        if (si.group(2) != null) {
          return ResponseBody.fromBytes(
            fakePng,
            200,
            headers: {
              Headers.contentTypeHeader: ['image/png'],
            },
          );
        }
        if (method == 'DELETE') {
          signatures.removeWhere((s) => s['id'] == si.group(1));
          return _json(200, {'message': 'ลบลายเซ็นเรียบร้อย', 'success': true});
        }
      }
      final imp = RegExp(
        r'^/api/admin/import/(general|monthyear)$',
      ).firstMatch(path);
      if (imp != null) {
        return _json(200, {
          'rows': 5,
          'imported': 3,
          'duplicates': 1,
          'missingFiles': ['แถว 4: old-form.pdf'],
          'invalidRows': [],
          'filesWithoutRow': [],
        });
      }
    }

    return _err(404, 'NOT_FOUND', 'ไม่พบเส้น $call (fake)');
  }

  Map<String, dynamic> _ticket(String idcard, String? memberNo) {
    final t = 'ticket-${++_serial}-xxxxxxxx';
    tickets[t] = (idcard, memberNo);
    return {
      'ticket': t,
      'full_name': 'ทดสอบ ยืนยันแล้ว',
      'member': memberNo != null,
      'member_no': memberNo,
      'expires_in': 900,
    };
  }

  Map<String, dynamic> _userDto(String username, FakeUser u) => {
    'id': u.id,
    'username': username,
    'idcard': u.idcard,
    'fullName': u.fullName,
    'memberNo': u.memberNo,
    'member': u.memberNo != null,
    'uploader': u.roles.contains('UPLOADER'),
    'personType': u.personType,
    'roles': u.roles,
    'assignedRoles': [if (u.roles.contains('ADMIN')) 'ADMIN'],
    'source': 'REGISTER',
    'active': true,
    'locked': false,
    'twoFactorEnabled': u.twoFactor,
    'mustChangePassword': u.mustChange,
    'lastLogin': '2026-10-31T08:30:00',
    'createdAt': '2026-10-28T10:00:00',
  };
}

/// ติดตั้ง backend จำลองให้ ApiService (singleton) และล้างสถานะเดิม
Future<FakeBackend> installFakeBackend() async {
  FlutterSecureStorage.setMockInitialValues({});
  final api = ApiService();
  await api.logout();
  final backend = FakeBackend();
  api.dio.httpClientAdapter = backend;
  api.publicDio.httpClientAdapter = backend;
  return backend;
}
