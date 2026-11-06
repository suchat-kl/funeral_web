// เทสต์งานเงินฝากฌาปนกิจล่วงหน้า: สิทธิ์เห็นเมนู, ค้นหา/รายละเอียดสมาชิก, ค่าฌาปนกิจรายเดือน, รายงาน + Excel

import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:funeral_web/screens/deposit/deposit_member_screen.dart';
import 'package:funeral_web/screens/deposit/deposit_parts.dart';
import 'package:funeral_web/screens/deposit/deposit_report_screens.dart';
import 'package:funeral_web/screens/deposit/deposit_search_screen.dart';
import 'package:funeral_web/screens/deposit/monthly_cost_screen.dart';
import 'package:funeral_web/services/api_service.dart';
import 'package:funeral_web/utils/roles.dart';

import 'fake_backend.dart';
import 'helpers.dart';

/// ข้อมูลจำลองของ /api/deposit/staff/** (ชื่อสมมุติ)
class FakeDeposit {
  final List<Map<String, dynamic>> members = [
    {
      'memberNo': '9',
      'title': 'นาย',
      'firstName': 'สมชาย',
      'lastName': 'ทดลอง',
      'divName': 'สังกัดหนึ่ง',
      'status': 0,
      'registered': true,
      'hasAccount': true,
      'accountStatus': 0,
      'balance': 1500.5,
      'debt': 0,
      'special': false,
      'dunning': false,
    },
    {
      'memberNo': '120',
      'title': 'นาง',
      'firstName': 'สมศรี',
      'lastName': 'ค้างจ่าย',
      'divName': 'สังกัดสอง',
      'status': 0,
      'registered': true,
      'hasAccount': true,
      'accountStatus': 0,
      'balance': 0,
      'debt': 4156,
      'special': true,
      'dunning': true,
    },
  ];
  Map<String, dynamic> account = {
    'balance': 0,
    'debt': 4156,
    'remark': 'ค้างชำระศพที่ 18489 ถึงศพที่ 18527',
    'status': 0,
    'statusText': '.ตัดออก',
    'dunning': true,
    'version': 3,
  };
  final List<Map<String, dynamic>> costs = [
    {
      'period': 256909,
      'bodyBegin': 18638,
      'bodyEnd': 18699,
      'bodyCount': 62,
      'perBody': 4,
      'amount': 248,
      'processedAt': '2026-10-01T09:00:00',
    },
  ];

  ResponseBody? handle(
    FakeBackend b,
    String call,
    Map<String, dynamic>? body,
    Map<String, dynamic> query,
    List<String>? roles,
  ) {
    const base = '/api/deposit/staff';
    final path = call.substring(call.indexOf(' ') + 1);
    if (!path.startsWith(base)) return null;
    if (roles == null) {
      return b.error(401, 'UNAUTHENTICATED', 'กรุณาเข้าสู่ระบบ');
    }
    if (!roles.contains('DEPOSIT_STAFF') && !roles.contains('ADMIN')) {
      return b.error(403, 'FORBIDDEN', 'ไม่มีสิทธิ์ใช้งานส่วนนี้');
    }
    switch (call) {
      case 'GET $base/members':
        final q = '${query['q'] ?? ''}';
        final rows = members
            .where(
              (m) =>
                  q.isEmpty ||
                  m['memberNo'] == q ||
                  '${m['firstName']} ${m['lastName']}'.contains(q),
            )
            .where((m) => query['state'] != 'DUNNING' || m['dunning'] == true)
            .toList();
        return b.json(200, {'rows': rows, 'truncated': false});
      case 'GET $base/members/120':
        return b.json(200, {
          'member': members[1],
          'memo': 'โทรตามแล้ว',
          'account': account,
          'special': {'amount': 500, 'approvalRef': 'หนังสือที่ 1/2569'},
        });
      case 'PUT $base/members/120/account':
        if (body?['version'] != account['version']) {
          return b.error(
            409,
            'STALE_VERSION',
            'ข้อมูลถูกแก้ไขโดยผู้อื่นก่อนหน้า',
          );
        }
        account = {
          ...account,
          'remark': body?['remark'],
          'status': body?['status'],
          'statusText': body?['statusText'],
          'dunning': body?['dunning'],
          'version': (account['version'] as int) + 1,
        };
        return b.json(200, account);
      case 'GET $base/members/120/ledger':
        return b.json(200, [
          {
            'date': '2026-05-31',
            'text': 'โอนไป บ/ช สงเคราะห์',
            'bodyPay': '18489-18527',
            'paid': 156,
            'balance': 0,
          },
        ]);
      case 'GET $base/oracle-members':
        return b.json(200, [
          {
            'memberNo': '41636',
            'title': 'นาย',
            'firstName': 'ทดสอบ',
            'lastName': 'ทะเบียน',
            'membership': 'N',
            'hasAccount': false,
          },
        ]);
      case 'POST $base/members/41636/account':
        members.add({
          'memberNo': '41636',
          'firstName': 'ทดสอบ',
          'lastName': 'ทะเบียน',
          'hasAccount': true,
        });
        return b.json(200, {
          'balance': 0,
          'debt': 0,
          'status': 0,
          'version': 0,
        });
      case 'GET $base/members/41636':
        return b.json(200, {
          'member': members.last,
          'account': {'balance': 0, 'debt': 0, 'status': 0, 'version': 0},
        });
      case 'GET $base/monthly-costs':
        return b.json(200, costs);
      case 'GET $base/monthly-costs/draft':
        return b.json(200, {
          'period': 256910,
          'bodyBegin': 18700,
          'perBody': 4,
          'announcementRef': 'ประกาศ 2552',
        });
      case 'POST $base/monthly-costs':
        final n = (body!['bodyEnd'] as int) - (body['bodyBegin'] as int) + 1;
        final c = {...body, 'bodyCount': n, 'amount': n * 4};
        costs.insert(0, c);
        return b.json(200, c);
      case 'GET $base/reports/monthly':
        return b.json(200, [256905]);
      case 'GET $base/reports/monthly/256905':
        return b.json(200, {
          'period': 256905,
          'rows': [
            {
              'memberNo': '9',
              'name': 'นายสมชาย ทดลอง',
              'carried': 1656.5,
              'received': 0,
              'bodyPay': '18489-18527',
              'status': '.',
              'paid': 156,
              'balance': 1500.5,
            },
          ],
          'totals': {
            'count': 1,
            'carried': 1656.5,
            'received': 0,
            'paid': 156,
            'balance': 1500.5,
          },
        });
      case 'GET $base/reports/monthly/256905/xlsx':
        return b.bytes(
          Uint8List.fromList(utf8.encode('xlsx')),
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
          'monthly-256905.xlsx',
        );
      case 'GET $base/reports/dunning':
        return b.json(200, {
          'asOf': '2026-11-06T10:00:00',
          'rows': [
            {
              'memberNo': '120',
              'name': 'นางสมศรี ค้างจ่าย',
              'debt': 4156,
              'balance': 0,
            },
          ],
          'count': 1,
          'totalDebt': 4156,
        });
    }
    return b.error(404, 'NOT_FOUND', 'ไม่พบ');
  }
}

void main() {
  setUpAll(loadAppFonts);
  logoutAfter();

  late FakeBackend backend;
  late FakeDeposit deposit;

  Future<void> open(
    WidgetTester tester,
    Widget Function() screen, {
    String user = 'deposit1',
    String pw = 'Deposit@2569x',
  }) async {
    useDesktopView(tester, size: const Size(1500, 1400));
    backend = await installFakeBackend();
    deposit = FakeDeposit();
    backend.extra = (c, b, q, r) => deposit.handle(backend, c, b, q, r);
    await loginAs(tester, user, pw);
    await pumpScreen(tester, screen());
  }

  group('สิทธิ์เห็นเมนู', () {
    MenuAccess a(List<String> roles) =>
        MenuAccess(loggedIn: true, roles: roles);

    test(
      'เจ้าหน้าที่รับฝากเงินล่วงหน้า และผู้ดูแล เห็น — ผู้นำไฟล์เข้า/สมาชิกไม่เห็น',
      () {
        expect(a(const [Roles.depositStaff]).depositStaff, isTrue);
        expect(a(const [Roles.admin, Roles.uploader]).depositStaff, isTrue);
        expect(a(const [Roles.member, Roles.uploader]).depositStaff, isFalse);
        expect(a(const [Roles.member]).depositStaff, isFalse);
        expect(a(const [Roles.depositStaff]).upload, isFalse);
        expect(
          const MenuAccess(
            loggedIn: false,
            roles: [Roles.depositStaff],
          ).depositStaff,
          isFalse,
        );
        expect(Roles.nameOf('DEPOSIT_STAFF'), 'เจ้าหน้าที่รับฝากเงินล่วงหน้า');
      },
    );
  });

  testWidgets('ค้นหาสมาชิก: แสดงยอด สถานะทวงถาม และกรองสถานะ', (tester) async {
    await open(tester, () => DepositSearchScreen(apiService: ApiService()));
    expect(find.byKey(DepositSearchScreen.rowKey('9')), findsOneWidget);
    expect(find.text('1,500.50'), findsOneWidget);
    expect(find.text('4,156.00'), findsOneWidget);
    expect(find.text('ทวงถาม'), findsOneWidget);
    expect(find.text('พิเศษ'), findsOneWidget);
    expect(backend.queryOf('GET /api/deposit/staff/members'), {
      'tab': 'DEPOSIT',
    });

    await tester.tap(find.text('ทุกสถานะ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ระหว่างทวงถามหนี้').last);
    await tester.pumpAndSettle();
    expect(
      backend.queryOf('GET /api/deposit/staff/members')?['state'],
      'DUNNING',
    );
    expect(find.byKey(DepositSearchScreen.rowKey('9')), findsNothing);
    expect(find.byKey(DepositSearchScreen.rowKey('120')), findsOneWidget);
  });

  testWidgets('ผู้นำไฟล์เข้าเรียกเส้นเงินฝากไม่ได้', (tester) async {
    await open(
      tester,
      () => DepositSearchScreen(apiService: ApiService()),
      user: 'upload1',
      pw: 'Upload@2569x',
    );
    expect(find.textContaining('ไม่มีสิทธิ์'), findsWidgets);
  });

  testWidgets('รายละเอียดสมาชิก: นำออกจากสมาชิกต้องยืนยัน และส่ง version', (
    tester,
  ) async {
    await open(
      tester,
      () => DepositMemberScreen(apiService: ApiService(), memberNo: '120'),
    );
    expect(find.text('นางสมศรี ค้างจ่าย'), findsOneWidget);
    expect(textContaining('4,156.00 บาท'), findsOneWidget);
    expect(find.text('โทรตามแล้ว'), findsOneWidget);

    await tester.tap(find.byKey(DepositMemberScreen.statusKey));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ตัดออกจากสมาชิก').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(DepositMemberScreen.saveAccountKey));
    await tester.tap(find.byKey(DepositMemberScreen.saveAccountKey));
    await tester.pumpAndSettle();
    expect(textContaining('หยุดหักค่าฌาปนกิจรายเดือน'), findsOneWidget);
    await tester.tap(find.text('นำออกจากสมาชิก').last);
    await tester.pumpAndSettle();
    final sent = backend.bodyOf('PUT /api/deposit/staff/members/120/account');
    expect(sent?['status'], 5);
    expect(sent?['version'], 3);
    expect(sent?['dunning'], false);

    // ทะเบียนรายตัว
    await tester.tap(find.byKey(DepositMemberScreen.tabKey(5)));
    await tester.pumpAndSettle();
    expect(find.text('โอนไป บ/ช สงเคราะห์'), findsOneWidget);
    expect(find.text('31 พฤษภาคม 2569'), findsOneWidget);
  });

  testWidgets('เปิดบัญชีจากทะเบียนสมาชิกแล้วเข้าหน้ารายละเอียด', (
    tester,
  ) async {
    await open(tester, () => DepositSearchScreen(apiService: ApiService()));
    await tester.tap(find.byKey(DepositSearchScreen.openAccountKey));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(OpenAccountDialog.searchKey), '41636');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(OpenAccountDialog.openKey('41636')));
    await tester.pumpAndSettle();
    expect(
      backend.calls,
      contains('POST /api/deposit/staff/members/41636/account'),
    );
    expect(
      find.text('นายทดสอบ ทะเบียน'),
      findsNothing,
    ); // ไม่มีคำนำหน้าในข้อมูลจำลอง
    expect(find.text('ทดสอบ ทะเบียน'), findsOneWidget);
  });

  testWidgets('ค่าฌาปนกิจรายเดือน: ตั้งต้นจากเดือนก่อน คำนวณยอด แล้วบันทึก', (
    tester,
  ) async {
    await open(tester, () => MonthlyCostScreen(apiService: ApiService()));
    expect(find.text('เพิ่มเดือนใหม่: ตุลาคม 2569'), findsOneWidget);
    expect(find.text('ประมวลผลแล้ว'), findsOneWidget);
    expect(find.byKey(MonthlyCostScreen.editKey(256909)), findsNothing);

    await tester.enterText(find.byKey(MonthlyCostScreen.endKey), '18739');
    await tester.pumpAndSettle();
    expect(find.text('ยอดต่อคน: 40 ศพ × 4 = 160.00 บาท'), findsOneWidget);
    await tester.tap(find.byKey(MonthlyCostScreen.saveKey));
    await tester.pumpAndSettle();
    final sent = backend.bodyOf('POST /api/deposit/staff/monthly-costs');
    expect(sent?['period'], 256910);
    expect(sent?['bodyBegin'], 18700);
    expect(sent?['bodyEnd'], 18739);
    expect(sent?['perBody'], '4');
    expect(find.byKey(MonthlyCostScreen.editKey(256910)), findsOneWidget);
  });

  testWidgets('รายงานประจำเดือน: ยอดรวม และส่งออก Excel', (tester) async {
    final saver = installFakeSaver();
    await open(tester, () => MonthlyReportScreen(apiService: ApiService()));
    expect(find.text('พฤษภาคม 2569 (6905)'), findsOneWidget);
    expect(find.text('รวม 1 คน'), findsOneWidget);
    expect(find.text('1,656.50'), findsWidgets);
    await tester.tap(find.text('ส่งออก Excel'));
    await tester.pumpAndSettle();
    expect(saver.saved.single.fileName, 'monthly-256905.xlsx');
  });

  testWidgets('รายงานระหว่างทวงถามหนี้', (tester) async {
    await open(
      tester,
      () => NeedDepositScreen(apiService: ApiService(), dunning: true),
    );
    expect(find.text('รายชื่อสมาชิกที่อยู่ระหว่างทวงถามหนี้'), findsOneWidget);
    expect(find.text('นางสมศรี ค้างจ่าย'), findsOneWidget);
    expect(textContaining('6 พฤศจิกายน 2569 10:00 น.'), findsOneWidget);
    expect(find.byKey(ExcelButton.buttonKey), findsOneWidget);
  });
}
