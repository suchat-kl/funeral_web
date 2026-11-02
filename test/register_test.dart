// เทสต์ลงทะเบียน 3 ทาง (สมาชิกแบบเดิม / สมาชิก ThaID / ไม่เป็นสมาชิก ThaID) และรหัสข้อผิดพลาดทุกแบบ
// ข้อมูลทั้งหมดเป็นค่าสมมุติ

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:funeral_web/services/api_service.dart';
import 'package:funeral_web/widgets/register_dialog.dart';

import 'fake_backend.dart';
import 'helpers.dart';

void main() {
  setUpAll(loadAppFonts);
  logoutAfter();

  late FakeBackend backend;
  late FakeThaidAuthorizer thaid;
  RegisterResult? result;
  var closed = false;
  final memberId = fakeIdcard('200000000001'); // อยู่ในทะเบียนสมาชิก 70001
  final dpisOnlyId = fakeIdcard('200000000003'); // อยู่ใน DPIS ไม่ใช่สมาชิก

  Future<void> open(WidgetTester tester) async {
    useDesktopView(tester, size: const Size(1200, 1400));
    backend = await installFakeBackend();
    thaid = installFakeThaid();
    result = null;
    closed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (ctx) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async {
                  result = await showDialog<RegisterResult>(
                    context: ctx,
                    builder: (_) => RegisterDialog(apiService: ApiService()),
                  );
                  closed = true;
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Finder field(Key key) => find.descendant(
    of: find.byKey(key),
    matching: find.byType(TextFormField),
  );

  Future<void> tapText(WidgetTester tester, String text) async {
    await tester.ensureVisible(find.text(text).last);
    await tester.tap(find.text(text).last);
    await tester.pumpAndSettle();
  }

  Future<void> fillLegacy(
    WidgetTester tester, {
    required String idcard,
    String memberNo = '70001',
  }) async {
    await tester.tap(find.byKey(RegisterDialog.memberKey));
    await tester.pumpAndSettle();
    await tester.enterText(field(RegisterDialog.idcardKey), idcard);
    await tester.enterText(field(RegisterDialog.memberNoKey), memberNo);
    await tapText(tester, 'ตรวจสอบ');
  }

  Future<void> fillAccount(
    WidgetTester tester, {
    String username = 'tester.one',
  }) async {
    await tester.enterText(field(RegisterDialog.usernameKey), username);
    final pw = find.descendant(
      of: find.byType(Form),
      matching: find.byType(TextFormField),
    );
    // ช่องรหัสผ่านและยืนยันคือสองช่องสุดท้าย
    final count = pw.evaluate().length;
    await tester.enterText(pw.at(count - 2), 'Strong@2569x');
    await tester.enterText(pw.at(count - 1), 'Strong@2569x');
    await tapText(tester, 'ลงทะเบียน');
  }

  testWidgets('ขั้น 1 ต้องเลือกก่อน: สองตัวเลือก เป็นสมาชิก / ไม่เป็นสมาชิก', (
    tester,
  ) async {
    await open(tester);
    expect(find.byKey(RegisterDialog.memberKey), findsOneWidget);
    expect(find.byKey(RegisterDialog.nonMemberKey), findsOneWidget);
    expect(
      find.text('ขั้นที่ 1 จาก 3: ท่านเป็นสมาชิกฌาปนกิจหรือไม่'),
      findsOneWidget,
    );
  });

  testWidgets(
    'สมาชิกแบบเดิม: ส่งเฉพาะเลขบัตรกับเลขสมาชิก ไม่มีช่องวันเกิด → ตั้งชื่อผู้ใช้ด้วยใบผ่าน',
    (tester) async {
      await open(tester);
      await fillLegacy(tester, idcard: memberId);
      expect(backend.bodyOf('POST /api/public/register/legacy-verify'), {
        'idcard': memberId,
        'memberNo': '70001',
      });
      expect(find.byKey(RegisterDialog.verifiedKey), findsOneWidget);
      expect(textContaining('เลขสมาชิก 70001'), findsOneWidget);

      await fillAccount(tester);
      final body = backend.bodyOf('POST /api/public/register/complete')!;
      expect(body['ticket'], startsWith('ticket-'));
      expect(body['username'], 'tester.one');
      expect(closed, isTrue);
      expect(result?.username, 'tester.one');
      expect(result?.goForgotPassword, isFalse);
    },
  );

  testWidgets(
    'สมาชิกแบบเดิม: เลขบัตรผิดหลักตรวจสอบ = เตือนในช่อง ไม่เรียก backend',
    (tester) async {
      await open(tester);
      await tester.tap(find.byKey(RegisterDialog.memberKey));
      await tester.pumpAndSettle();
      await tester.enterText(field(RegisterDialog.idcardKey), '1234567890123');
      await tester.enterText(field(RegisterDialog.memberNoKey), '70001');
      await tapText(tester, 'ตรวจสอบ');
      expect(find.text('เลขบัตรประชาชนไม่ถูกต้อง'), findsOneWidget);
      expect(
        find.text('วันเกิด'),
        findsNothing,
        reason: 'แบบเดิมไม่มีช่องวันเกิดแล้ว',
      );
      expect(backend.calls, isEmpty);
    },
  );

  testWidgets(
    'สมาชิกแบบเดิม: ข้อมูลไม่ตรง (REGISTER_NOT_MATCH) แสดงข้อความ อยู่ขั้นเดิม',
    (tester) async {
      await open(tester);
      await fillLegacy(tester, idcard: memberId, memberNo: '79999');
      expect(find.text('ข้อมูลไม่ตรงกับทะเบียนสมาชิก'), findsOneWidget);
      expect(find.byKey(RegisterDialog.verifiedKey), findsNothing);
      expect(find.byKey(RegisterDialog.idcardKey), findsOneWidget);
    },
  );

  testWidgets(
    'เลขบัตรมีบัญชีแล้ว (ALREADY_REGISTERED): ปุ่มไปลืมรหัสผ่านผ่าน ThaID',
    (tester) async {
      await open(tester);
      final existing = backend.users['member1']!.idcard;
      await fillLegacy(tester, idcard: existing);
      expect(find.byKey(RegisterDialog.alreadyKey), findsOneWidget);
      await tester.tap(find.byKey(RegisterDialog.goForgotKey));
      await tester.pumpAndSettle();
      expect(closed, isTrue);
      expect(result?.goForgotPassword, isTrue);
    },
  );

  testWidgets(
    'สมาชิก ThaID: purpose=register, mode=MEMBER แล้วลงทะเบียนสำเร็จ',
    (tester) async {
      await open(tester);
      thaid.state = 'st-reg';
      backend.thaid['st-reg'] = FakeThaid('register', memberId);
      await tester.tap(find.byKey(RegisterDialog.memberKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(RegisterDialog.thaidWayKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(RegisterDialog.thaidButtonKey));
      await tester.pumpAndSettle();
      expect(thaid.purposes, ['register']);
      expect(backend.bodyOf('POST /api/auth/public-thaid/register'), {
        'state': 'st-reg',
        'mode': 'MEMBER',
      });
      await fillAccount(tester, username: 'tester.two');
      expect(result?.username, 'tester.two');
    },
  );

  testWidgets(
    'สมาชิก ThaID ไม่พบในทะเบียน (NOT_MEMBER): ปุ่มลงทะเบียนแบบไม่เป็นสมาชิก',
    (tester) async {
      await open(tester);
      thaid.state = 'st-nm';
      backend.thaid['st-nm'] = FakeThaid('register', dpisOnlyId);
      await tester.tap(find.byKey(RegisterDialog.memberKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(RegisterDialog.thaidWayKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(RegisterDialog.thaidButtonKey));
      await tester.pumpAndSettle();
      expect(find.text('ไม่พบเลขบัตรในทะเบียนสมาชิกฌาปนกิจ'), findsOneWidget);
      await tester.tap(find.byKey(RegisterDialog.goNonMemberKey));
      await tester.pumpAndSettle();
      // ไม่เป็นสมาชิก: ไม่มีตัวเลือกแบบเดิม มีแต่ ThaID
      expect(find.byKey(RegisterDialog.legacyWayKey), findsNothing);
      thaid.state = 'st-nm2';
      backend.thaid['st-nm2'] = FakeThaid('register', dpisOnlyId);
      await tester.tap(find.byKey(RegisterDialog.thaidButtonKey));
      await tester.pumpAndSettle();
      expect(
        backend.bodyOf('POST /api/auth/public-thaid/register')!['mode'],
        'NON_MEMBER',
      );
      expect(textContaining('ไม่ใช่สมาชิกฌาปนกิจ'), findsOneWidget);
    },
  );

  testWidgets(
    'ไม่เป็นสมาชิก: ThaID เท่านั้น ไม่พบใน DPIS (NOT_IN_DPIS) แสดงข้อความ',
    (tester) async {
      await open(tester);
      thaid.state = 'st-x';
      backend.thaid['st-x'] = FakeThaid('register', fakeIdcard('399999999999'));
      await tester.tap(find.byKey(RegisterDialog.nonMemberKey));
      await tester.pumpAndSettle();
      expect(find.byKey(RegisterDialog.legacyWayKey), findsNothing);
      await tester.tap(find.byKey(RegisterDialog.thaidButtonKey));
      await tester.pumpAndSettle();
      expect(find.text('ไม่พบข้อมูลบุคลากรของเลขบัตรนี้'), findsOneWidget);
    },
  );

  testWidgets('ThaID ยกเลิก: แจ้งยกเลิก ไม่เรียกเส้นลงทะเบียน', (tester) async {
    await open(tester);
    thaid.state = null;
    await tester.tap(find.byKey(RegisterDialog.nonMemberKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(RegisterDialog.thaidButtonKey));
    await tester.pumpAndSettle();
    expect(find.text('ผู้ใช้งานยกเลิกการใช้ ThaID'), findsOneWidget);
    expect(
      backend.calls,
      isNot(contains('POST /api/auth/public-thaid/register')),
    );
  });

  testWidgets(
    'ชื่อซ้ำ (409 DUPLICATE): เตือนที่ช่องชื่อผู้ใช้ ใบผ่านเดิมใช้ต่อได้',
    (tester) async {
      await open(tester);
      await fillLegacy(tester, idcard: memberId);
      await fillAccount(tester, username: 'member1'); // มีอยู่แล้ว
      expect(find.text('ชื่อผู้ใช้นี้มีผู้ใช้แล้ว'), findsOneWidget);
      expect(closed, isFalse);
      final ticket = backend.bodyOf(
        'POST /api/public/register/complete',
      )!['ticket'];
      await fillAccount(tester, username: 'tester.three');
      expect(
        backend.bodyOf('POST /api/public/register/complete')!['ticket'],
        ticket,
      );
      expect(result?.username, 'tester.three');
    },
  );

  testWidgets('ใบผ่านหมดอายุ (REGISTER_TICKET_INVALID): กลับไปเริ่มขั้นที่ 1', (
    tester,
  ) async {
    await open(tester);
    await fillLegacy(tester, idcard: memberId);
    backend.ticketsExpired = true;
    await fillAccount(tester);
    expect(find.byKey(RegisterDialog.memberKey), findsOneWidget);
    expect(textContaining(RegisterDialog.ticketExpiredMessage), findsOneWidget);
    expect(closed, isFalse);
  });

  testWidgets('ลองถี่เกิน (429 TOO_MANY_REQUESTS): แสดงข้อความของ backend', (
    tester,
  ) async {
    await open(tester);
    backend.failures['POST /api/public/register/legacy-verify'] = (
      429,
      'TOO_MANY_REQUESTS',
      'ลองหลายครั้งเกินไป กรุณารอสักครู่แล้วลองใหม่',
    );
    await fillLegacy(tester, idcard: memberId);
    expect(
      find.text('ลองหลายครั้งเกินไป กรุณารอสักครู่แล้วลองใหม่'),
      findsOneWidget,
    );
  });

  test('กติกาชื่อผู้ใช้ตรงกับ backend', () {
    // ตรวจแค่ความยาว 4-30 ตัว (ผู้ใช้ตัดสิน 1 พ.ย. 2569)
    expect(RegisterDialog.validateUsername('abc'), isNotNull);
    expect(RegisterDialog.validateUsername('a' * 31), isNotNull);
    expect(RegisterDialog.validateUsername('   '), isNotNull);
    expect(RegisterDialog.validateUsername('ab\ncd'), isNotNull);
    expect(RegisterDialog.validateUsername('a b c d'), isNull);
    expect(RegisterDialog.validateUsername('ชื่อไทย'), isNull);
    expect(RegisterDialog.validateUsername('1234567890123'), isNull);
    expect(RegisterDialog.validateUsername('somchai.j_01-x'), isNull);
    expect(RegisterDialog.validateUsername('ก' * 30), isNull);
  });
}
