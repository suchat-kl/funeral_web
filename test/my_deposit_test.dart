// เทสต์บัญชีฝากล่วงหน้าของฉัน (สมาชิก): สิทธิ์เห็นเมนู การ์ดหน้าแรก และหน้ารายละเอียดแบบอ่านอย่างเดียว

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:funeral_web/screens/deposit/my_deposit_screen.dart';
import 'package:funeral_web/screens/home_screen.dart';
import 'package:funeral_web/services/api_service.dart';
import 'package:funeral_web/utils/roles.dart';

import 'fake_backend.dart';
import 'helpers.dart';

/// /api/deposit/me จำลอง: ตอบตามบทบาทของผู้เรียก (ข้อมูลสมมุติ)
class FakeMyDeposit {
  bool hasAccount = true;
  final List<Map<String, dynamic>> queries = [];

  ResponseBody? handle(
    FakeBackend b,
    String call,
    Map<String, dynamic> query,
    List<String>? roles,
  ) {
    const base = '/api/deposit/me';
    final path = call.substring(call.indexOf(' ') + 1);
    if (!path.startsWith(base)) return null;
    queries.add(query);
    if (roles == null) {
      return b.error(401, 'UNAUTHENTICATED', 'กรุณาเข้าสู่ระบบ');
    }
    final member = roles.contains('MEMBER');
    if (!member || !hasAccount) {
      return switch (path) {
        base => b.json(200, {'hasAccount': false, 'openDebts': 0}),
        _ => b.json(200, const []),
      };
    }
    return switch (path) {
      base => b.json(200, {
        'hasAccount': true,
        'memberNo': '90003',
        'balance': 1234.5,
        'debt': 312,
        'openDebts': 2,
        'status': 0,
        'statusName': 'ปกติ',
        'dunning': true,
        'special': false,
        'lastProcessed': 256909,
      }),
      '$base/payments' => b.json(200, [
        {
          'period': 256909,
          'bodyBegin': 18638,
          'bodyEnd': 18699,
          'amount': 248,
          'paidPeriod': 256909,
        },
      ]),
      '$base/debts' => b.json(200, [
        {
          'period': 256908,
          'bodyBegin': 18600,
          'bodyEnd': 18637,
          'amount': 156,
          'cleared': false,
        },
      ]),
      '$base/monthly' => b.json(200, [
        {
          'period': 256909,
          'carried': 1482.5,
          'received': 0,
          'bodyPay': '18638-18699',
          'paid': 248,
          'balance': 1234.5,
        },
      ]),
      _ => b.json(200, const []),
    };
  }
}

void main() {
  setUpAll(loadAppFonts);
  logoutAfter();

  late FakeBackend backend;
  late FakeMyDeposit my;

  Future<void> setUpUser(
    WidgetTester tester,
    String user,
    String pw, {
    Size size = const Size(1500, 1400),
  }) async {
    useDesktopView(tester, size: size);
    backend = await installFakeBackend();
    my = FakeMyDeposit();
    backend.extra = (c, b, q, r) => my.handle(backend, c, q, r);
    await loginAs(tester, user, pw);
  }

  test(
    'เมนูบัญชีฝากของฉัน: สมาชิกเห็น — เจ้าหน้าที่ที่ไม่ใช่สมาชิกไม่เห็น',
    () {
      MenuAccess a(List<String> roles) =>
          MenuAccess(loggedIn: true, roles: roles);
      expect(a(const [Roles.member]).myDeposit, isTrue);
      expect(a(const [Roles.member, Roles.depositStaff]).myDeposit, isTrue);
      expect(a(const [Roles.nonMember, Roles.depositStaff]).myDeposit, isFalse);
      expect(a(const [Roles.nonMember, Roles.uploader]).myDeposit, isFalse);
      expect(
        const MenuAccess(loggedIn: false, roles: [Roles.member]).myDeposit,
        isFalse,
      );
    },
  );

  testWidgets('หน้าบัญชีของฉัน: ยอด ทวงถาม แท็บ และไม่ส่งเลขสมาชิก', (
    tester,
  ) async {
    await setUpUser(tester, 'member1', 'Member@2569x');
    await pumpScreen(tester, MyDepositScreen(apiService: ApiService()));

    expect(find.byKey(MyDepositCard.cardKey), findsOneWidget);
    expect(textContaining('1,234.50'), findsOneWidget);
    expect(textContaining('312.00 บาท (2 เดือน)'), findsOneWidget);
    expect(textContaining('ระหว่างทวงถามหนี้'), findsOneWidget);
    expect(textContaining('กันยายน 2569'), findsWidgets);
    // ไม่มีปุ่มแก้ไขใด ๆ
    expect(find.byType(FilledButton), findsNothing);

    await tester.tap(find.byKey(MyDepositScreen.tabKey(1)));
    await tester.pumpAndSettle();
    expect(find.text('ค้างชำระ'), findsWidgets);
    expect(find.text('18600-18637'), findsOneWidget);

    await tester.tap(find.byKey(MyDepositScreen.tabKey(4)));
    await tester.pumpAndSettle();
    expect(find.text('1,482.50'), findsOneWidget);

    expect(my.queries, isNotEmpty);
    for (final q in my.queries) {
      expect(q, isEmpty, reason: 'หน้าเว็บต้องไม่ส่งพารามิเตอร์ใด ๆ');
    }
    for (final c in backend.calls.where((c) => c.contains('/api/deposit/'))) {
      expect(c, isNot(contains('90003')));
      expect(c, isNot(contains('/staff/')));
    }
  });

  testWidgets('ไม่มีบัญชีฝาก: แจ้งว่าไม่มี ไม่โหลดประวัติ', (tester) async {
    await setUpUser(tester, 'member1', 'Member@2569x');
    my.hasAccount = false;
    await pumpScreen(tester, MyDepositScreen(apiService: ApiService()));
    expect(textContaining('ยังไม่มีบัญชีฝาก'), findsOneWidget);
    expect(find.byKey(MyDepositCard.cardKey), findsNothing);
    expect(
      backend.calls.where((c) => c.startsWith('GET /api/deposit/me/')),
      isEmpty,
    );
  });

  testWidgets('หน้าแรก: สมาชิกที่มีบัญชีเห็นการ์ดยอดเงินฝาก', (tester) async {
    await setUpUser(
      tester,
      'member1',
      'Member@2569x',
      size: const Size(1400, 2400),
    );
    final auth = await loginAs(tester, 'member1', 'Member@2569x');
    await pumpScreen(tester, Scaffold(body: HomeScreen(authProvider: auth)));
    expect(find.byKey(MyDepositCard.cardKey), findsOneWidget);
    expect(textContaining('บัญชีฝากล่วงหน้าของฉัน'), findsOneWidget);
  });

  testWidgets('หน้าแรก: ไม่ใช่สมาชิก = ไม่มีการ์ด และไม่เรียกเส้น', (
    tester,
  ) async {
    await setUpUser(
      tester,
      'nonmember1',
      'NonMember@2569x',
      size: const Size(1400, 2400),
    );
    final auth = await loginAs(tester, 'nonmember1', 'NonMember@2569x');
    await pumpScreen(tester, Scaffold(body: HomeScreen(authProvider: auth)));
    expect(find.byKey(MyDepositCard.cardKey), findsNothing);
    expect(my.queries, isEmpty);
  });

  testWidgets('หน้าแรก: สมาชิกที่ไม่มีบัญชีฝาก = ไม่มีการ์ด', (tester) async {
    await setUpUser(
      tester,
      'member1',
      'Member@2569x',
      size: const Size(1400, 2400),
    );
    my.hasAccount = false;
    final auth = await loginAs(tester, 'member1', 'Member@2569x');
    await pumpScreen(tester, Scaffold(body: HomeScreen(authProvider: auth)));
    expect(find.byKey(MyDepositCard.cardKey), findsNothing);
  });
}
