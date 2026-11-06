// เทสต์งานเงินฝากฌาปนกิจล่วงหน้า: สิทธิ์เห็นเมนู, ค้นหา/รายละเอียดสมาชิก, ค่าฌาปนกิจรายเดือน, รายงาน + Excel

import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:funeral_web/screens/deposit/deposit_entry_screen.dart';
import 'package:funeral_web/screens/deposit/deposit_member_screen.dart';
import 'package:funeral_web/screens/deposit/deposit_refund_screen.dart';
import 'package:funeral_web/screens/deposit/monthly_process_screen.dart';
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
      'period': 256910,
      'bodyBegin': 18700,
      'bodyEnd': 18741,
      'bodyCount': 42,
      'perBody': 4,
      'amount': 168,
      'costDate': '2026-09-30',
      'totalMembers': 44161,
      'inDpis': true,
      'processed': false,
    },
    {
      'period': 256909,
      'bodyBegin': 18638,
      'bodyEnd': 18699,
      'bodyCount': 62,
      'perBody': 4,
      'amount': 248,
      'costDate': '2026-08-31',
      'totalMembers': 44161,
      'inDpis': true,
      'processed': true,
      'processedAt': '2026-10-01T09:00:00',
      'warning': 'ค่าใน DPIS เปลี่ยนหลังประมวลผลแล้ว',
    },
  ];

  bool processed = false;
  Object? lastCostYear;

  ResponseBody? handle(
    FakeBackend b,
    String call,
    Map<String, dynamic>? body,
    Map<String, dynamic> query,
    List<String>? roles,
  ) {
    const base = '/api/deposit/staff';
    final path = call.substring(call.indexOf(' ') + 1);
    if (path.startsWith('/api/deposit/admin/')) {
      // แก้ไขโดยผู้ดูแลระบบ: ADMIN เท่านั้น (เจ้าหน้าที่รับฝากเงินล่วงหน้าไม่ได้)
      if (roles == null) {
        return b.error(401, 'UNAUTHENTICATED', 'กรุณาเข้าสู่ระบบ');
      }
      if (!roles.contains('ADMIN')) {
        return b.error(403, 'FORBIDDEN', 'ไม่มีสิทธิ์ใช้งานส่วนนี้');
      }
      if (body?['reason'] == null) {
        return b.error(400, 'BAD_REQUEST', 'กรุณาระบุเหตุผลของการแก้ไข');
      }
      return b.json(200, {
        'memberNo': '9',
        'balance': 1344.5,
        'debt': 0,
        'version': 8,
        'reportRows': 2,
      });
    }
    if (!path.startsWith(base)) return null;
    if (roles == null) {
      return b.error(401, 'UNAUTHENTICATED', 'กรุณาเข้าสู่ระบบ');
    }
    if (!roles.contains('DEPOSIT_STAFF') && !roles.contains('ADMIN')) {
      return b.error(403, 'FORBIDDEN', 'ไม่มีสิทธิ์ใช้งานส่วนนี้');
    }
    switch (call) {
      case 'GET $base/members/9':
        return b.json(200, {
          'member': members[0],
          'account': {'balance': 1500.5, 'debt': 0, 'status': 0, 'version': 7},
        });
      case 'GET $base/members/9/payments':
        return b.json(200, [
          {
            'id': 'pay-6905',
            'period': 256905,
            'bodyBegin': 18489,
            'bodyEnd': 18527,
            'amount': 156,
            'paidPeriod': 256905,
          },
          {
            'period': 256904,
            'bodyBegin': 18450,
            'bodyEnd': 18488,
            'amount': 156,
            'paidPeriod': 256904,
            'reversedPeriod': 256905,
          },
        ]);
      case 'POST $base/members/9/refund':
        return b.json(200, {
          'type': body?['type'],
          'amount': 156,
          'balanceBefore': 1500.5,
          'balance': 1656.5,
          'debt': 0,
        });
      case 'POST $base/deposits':
        final rows = (body?['rows'] as List).cast<Map>();
        return b.json(200, [
          for (final r in rows)
            {
              'memberNo': r['memberNo'],
              'name': 'ชื่อ ${r['memberNo']}',
              'amount': r['amount'],
              'reportPeriod': 256906,
              'clearedPeriods': r['memberNo'] == '120' ? [256904, 256905] : [],
              'clearedAmount': r['memberNo'] == '120' ? 312 : 0,
              'balance': 10,
              'debt': 0,
            },
        ]);
      case 'GET $base/process':
        return b.json(200, {
          'openPeriod': processed ? 256907 : 256906,
          'pending': processed ? [] : [256906],
          'lastProcessed': processed ? 256906 : 256905,
          'canUndo': processed,
          'undoBlockedReason': processed
              ? null
              : 'เดือนนี้ประมวลผลในระบบเดิม ยกเลิกในระบบนี้ไม่ได้',
        });
      case 'GET $base/process/256906/preview':
        return b.json(200, {
          'period': 256906,
          'ready': true,
          'amount': 152,
          'bodyBegin': 18528,
          'bodyEnd': 18565,
          'accounts': 3200,
          'canPay': 2600,
          'payTotal': 395200,
          'willOwe': 600,
          'oweTotal': 91200,
        });
      case 'POST $base/process/256906':
        processed = true;
        return b.json(200, {
          'period': 256906,
          'paid': 2600,
          'paidTotal': 395200,
          'owed': 600,
          'clearedDebts': 40,
          'clearedTotal': 6240,
          'reportRows': 3210,
        });
      case 'POST $base/process/256906/undo':
        processed = false;
        return b.json(200, {'period': 256906, 'payments': 2600, 'debts': 600});
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
        lastCostYear = query['year'];
        return b.json(200, {
          'year': query['year'] == null ? 2569 : int.parse('${query['year']}'),
          'years': [2569, 2568],
          'rows': '${query['year']}' == '2568' ? [] : costs,
        });
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

  testWidgets('ค่าฌาปนกิจประจำเดือน: อ่านจาก DPIS อย่างเดียว เลือกปีได้', (
    tester,
  ) async {
    await open(tester, () => MonthlyCostScreen(apiService: ApiService()));
    expect(find.byKey(MonthlyCostScreen.rowKey(256910)), findsOneWidget);
    expect(find.text('18700-18741'), findsOneWidget);
    expect(find.text('168.00'), findsOneWidget);
    expect(find.text('ยังไม่ประมวลผล'), findsOneWidget);
    expect(find.text('ประมวลผลแล้ว'), findsOneWidget);
    expect(textContaining('เปลี่ยนหลังประมวลผล'), findsOneWidget);
    expect(find.text('30 กันยายน 2569'), findsOneWidget);
    // ไม่มีช่องกรอกหรือปุ่มบันทึก
    expect(find.byType(TextField), findsNothing);
    expect(find.byType(FilledButton), findsNothing);
    expect(deposit.lastCostYear, isNull);

    await tester.tap(find.byKey(MonthlyCostScreen.yearKey));
    await tester.pumpAndSettle();
    await tester.tap(find.text('2568').last);
    await tester.pumpAndSettle();
    expect('${deposit.lastCostYear}', '2568');
    expect(textContaining('ไม่มีค่าฌาปนกิจของปี 2568'), findsOneWidget);
    expect(
      backend.calls.where(
        (c) => c.contains('/api/deposit/') && !c.startsWith('GET'),
      ),
      isEmpty,
    );
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

  group('ผู้ดูแลระบบแก้ไขข้อมูล', () {
    Future<void> openPayments(
      WidgetTester tester,
      String user,
      String pw,
    ) async {
      await open(
        tester,
        () => DepositMemberScreen(apiService: ApiService(), memberNo: '9'),
        user: user,
        pw: pw,
      );
      await tester.tap(find.byKey(DepositMemberScreen.tabKey(2)));
      await tester.pumpAndSettle();
    }

    testWidgets('แก้จำนวนเงินการชำระ: ต้องใส่เหตุผล ส่ง version แล้วโหลดใหม่', (
      tester,
    ) async {
      await openPayments(tester, 'admin1', 'Admin@2569x');
      expect(textContaining('กดที่แถวเพื่อแก้ไขหรือลบ'), findsOneWidget);
      await tester.tap(find.byKey(DepositMemberScreen.rowKey('pay-6905')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('admin-field-amount')),
        '100',
      );
      // ไม่ใส่เหตุผล = ไม่ส่ง
      await tester.tap(find.byKey(const ValueKey('admin-form-save')));
      await tester.pumpAndSettle();
      expect(textContaining('กรุณาระบุเหตุผล'), findsOneWidget);
      expect(
        backend.calls.where((c) => c.contains('/api/deposit/admin/')),
        isEmpty,
      );

      await tester.enterText(
        find.byKey(const ValueKey('admin-form-reason')),
        'อัตราผิด',
      );
      await tester.tap(find.byKey(const ValueKey('admin-form-save')));
      await tester.pumpAndSettle();
      final sent = backend.bodyOf('PUT /api/deposit/admin/payments/pay-6905');
      expect(sent?['amount'], '100');
      expect(sent?['version'], 7);
      expect(sent?['reason'], 'อัตราผิด');
      expect(sent?['paidPeriod'], 256905);
      expect(textContaining('คำนวณใหม่ 2 แถว'), findsOneWidget);
    });

    testWidgets('ลบการชำระต้องกดยืนยันสองครั้ง', (tester) async {
      await openPayments(tester, 'admin1', 'Admin@2569x');
      await tester.tap(find.byKey(DepositMemberScreen.rowKey('pay-6905')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('admin-form-reason')),
        'หักผิดคน',
      );
      await tester.tap(find.byKey(const ValueKey('admin-form-delete')));
      await tester.pumpAndSettle();
      expect(backend.calls.where((c) => c.contains('/delete')), isEmpty);
      await tester.tap(find.byKey(const ValueKey('admin-form-delete')));
      await tester.pumpAndSettle();
      final sent = backend.bodyOf(
        'POST /api/deposit/admin/payments/pay-6905/delete',
      );
      expect(sent?['version'], 7);
      expect(sent?['reason'], 'หักผิดคน');
    });

    testWidgets('ปรับยอดเงินฝากจากแท็บบัญชีฝาก', (tester) async {
      await open(
        tester,
        () => DepositMemberScreen(apiService: ApiService(), memberNo: '9'),
        user: 'admin1',
        pw: 'Admin@2569x',
      );
      await tester.tap(find.byKey(DepositMemberScreen.adminAdjustKey));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('admin-field-amount')),
        '-156',
      );
      await tester.enterText(
        find.byKey(const ValueKey('admin-form-reason')),
        'ยอดยกมาจากระบบเดิมผิด',
      );
      await tester.tap(find.byKey(const ValueKey('admin-form-save')));
      await tester.pumpAndSettle();
      final sent = backend.bodyOf('POST /api/deposit/admin/members/9/adjust');
      expect(sent?['amount'], '-156');
      expect(sent?['version'], 7);
      expect(sent?['period'], isNull); // ไม่เลือก = เดือนที่เปิดอยู่
    });

    testWidgets('เจ้าหน้าที่รับฝากเงินล่วงหน้าไม่เห็นเครื่องมือแก้ไข', (
      tester,
    ) async {
      await openPayments(tester, 'deposit1', 'Deposit@2569x');
      expect(textContaining('กดที่แถวเพื่อแก้ไขหรือลบ'), findsNothing);
      await tester.tap(find.byKey(DepositMemberScreen.rowKey('pay-6905')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('admin-form-save')), findsNothing);
      await tester.tap(find.byKey(DepositMemberScreen.tabKey(0)));
      await tester.pumpAndSettle();
      expect(find.byKey(DepositMemberScreen.adminAdjustKey), findsNothing);
      expect(find.byKey(DepositMemberScreen.adminRegisterKey), findsNothing);
    });
  });

  Future<void> member(WidgetTester tester, int i, String no) async {
    await tester.enterText(find.byKey(DepositEntryScreen.memberKey(i)), no);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'บันทึกเงินฝากหลายแถว: แสดงชื่อ ยอดรวม ยืนยัน แล้วแสดงผลปลดหนี้',
    (tester) async {
      await open(
        tester,
        () => DepositEntryScreen(
          apiService: ApiService(),
          today: DateTime(2026, 6, 10),
        ),
      );
      await member(tester, 0, '120');
      expect(find.text('นางสมศรี ค้างจ่าย'), findsOneWidget);
      await tester.enterText(
        find.byKey(DepositEntryScreen.amountKey(0)),
        '1,000.50',
      );
      await tester.enterText(find.byKey(DepositEntryScreen.docKey(0)), 'A001');
      await tester.tap(find.byKey(DepositEntryScreen.addRowKey));
      await tester.pumpAndSettle();
      await member(tester, 1, '9');
      await tester.enterText(
        find.byKey(DepositEntryScreen.amountKey(1)),
        '500',
      );
      await tester.pumpAndSettle();
      expect(textContaining('1,500.50 บาท'), findsWidgets);

      await tester.tap(find.byKey(DepositEntryScreen.saveKey));
      await tester.pumpAndSettle();
      expect(
        textContaining('บันทึกเงินฝาก 2 รายการ รวม 1,500.50 บาท'),
        findsOneWidget,
      );
      await tester.tap(find.text('บันทึก').last);
      await tester.pumpAndSettle();
      final sent = backend.bodyOf('POST /api/deposit/staff/deposits');
      final rows = (sent!['rows'] as List).cast<Map>();
      expect(rows.length, 2);
      expect(rows[0]['memberNo'], '120');
      expect(rows[0]['amount'], '1000.50');
      expect(rows[0]['date'], '2026-06-10');
      expect(rows[0]['docNo'], 'A001');
      expect(rows[1]['docNo'], isNull);
      expect(
        textContaining('2 เดือน (312.00 บาท): 6904, 6905'),
        findsOneWidget,
      );
    },
  );

  testWidgets('บันทึกเงินฝาก: เลขที่ไม่พบถูกกันที่หน้าจอ ไม่ส่ง backend', (
    tester,
  ) async {
    await open(
      tester,
      () => DepositEntryScreen(
        apiService: ApiService(),
        today: DateTime(2026, 6, 10),
      ),
    );
    await member(tester, 0, '55555');
    expect(find.text('ไม่พบเลขสมาชิกนี้'), findsOneWidget);
    await tester.enterText(find.byKey(DepositEntryScreen.amountKey(0)), '10');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(DepositEntryScreen.saveKey));
    await tester.pumpAndSettle();
    expect(backend.calls, isNot(contains('POST /api/deposit/staff/deposits')));
    expect(textContaining('แถวที่ 1: ไม่พบเลขสมาชิกนี้'), findsOneWidget);
  });

  testWidgets('ประมวลผล: ตัวอย่างผล ยืนยัน แล้วยกเลิกเดือนล่าสุดได้', (
    tester,
  ) async {
    await open(tester, () => MonthlyProcessScreen(apiService: ApiService()));
    expect(
      find.text('เดือนที่ต้องประมวลผลถัดไป: มิถุนายน 2569'),
      findsOneWidget,
    );
    expect(textContaining('2,600 คน · 395,200.00 บาท'), findsOneWidget);
    expect(
      find.text('เดือนนี้ประมวลผลในระบบเดิม ยกเลิกในระบบนี้ไม่ได้'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(MonthlyProcessScreen.processKey));
    await tester.pumpAndSettle();
    expect(textContaining('ศพที่ 18528-18565 คนละ 152.00 บาท'), findsOneWidget);
    await tester.tap(find.text('ประมวลผล').last);
    await tester.pumpAndSettle();
    expect(backend.calls, contains('POST /api/deposit/staff/process/256906'));
    expect(
      find.text('เดือนที่ต้องประมวลผลถัดไป: กรกฎาคม 2569'),
      findsOneWidget,
    );
    expect(
      textContaining('ยังไม่มีค่าฌาปนกิจของเดือน กรกฎาคม 2569 ใน DPIS'),
      findsOneWidget,
    );
    expect(textContaining('รายงานประจำเดือน 3,210 แถว'), findsOneWidget);
    expect(
      textContaining('ปลดหนี้เดือนก่อน 40 เดือน 6,240.00 บาท'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(MonthlyProcessScreen.undoKey));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ยกเลิกการประมวลผล').last);
    await tester.pumpAndSettle();
    expect(
      backend.calls,
      contains('POST /api/deposit/staff/process/256906/undo'),
    );
    expect(
      find.text('เดือนที่ต้องประมวลผลถัดไป: มิถุนายน 2569'),
      findsOneWidget,
    );
  });

  Future<void> openRefund(WidgetTester tester) async {
    await open(
      tester,
      () => DepositRefundScreen(
        apiService: ApiService(),
        today: DateTime(2026, 6, 10),
      ),
    );
    await tester.enterText(find.byKey(DepositRefundScreen.memberKey), '9');
    await tester.tap(find.byKey(DepositRefundScreen.findKey));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'คืนกรณีเก็บซ้ำซ้อน: เลือกได้เฉพาะเดือนที่ยังไม่คืน ส่ง version',
    (tester) async {
      await openRefund(tester);
      await tester.tap(find.byKey(DepositRefundScreen.duplicateKey));
      await tester.pumpAndSettle();
      expect(find.byKey(DepositRefundScreen.monthKey(256905)), findsOneWidget);
      expect(find.byKey(DepositRefundScreen.monthKey(256904)), findsNothing);
      await tester.tap(find.byKey(DepositRefundScreen.monthKey(256905)));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(DepositRefundScreen.submitKey));
      await tester.tap(find.byKey(DepositRefundScreen.submitKey));
      await tester.pumpAndSettle();
      expect(textContaining('1,500.50 → 1,656.50 บาท'), findsOneWidget);
      await tester.tap(find.text('คืนเงิน').last);
      await tester.pumpAndSettle();
      final sent = backend.bodyOf('POST /api/deposit/staff/members/9/refund');
      expect(sent?['type'], 'DUPLICATE');
      expect(sent?['version'], 7);
      expect(sent?['periods'], [256905]);
      expect(sent?['date'], '2026-06-10');
    },
  );

  testWidgets('จ่ายคืนปิดบัญชี: ยืนยันแสดงยอดก่อน-หลัง', (tester) async {
    await openRefund(tester);
    await tester.ensureVisible(find.byKey(DepositRefundScreen.submitKey));
    await tester.tap(find.byKey(DepositRefundScreen.submitKey));
    await tester.pumpAndSettle();
    expect(textContaining('1,500.50 → 0.00 บาท'), findsOneWidget);
    expect(textContaining('สภาพหลังปิด: ลาออก'), findsOneWidget);
    await tester.tap(find.text('จ่ายคืนและปิดบัญชี').last);
    await tester.pumpAndSettle();
    final sent = backend.bodyOf('POST /api/deposit/staff/members/9/refund');
    expect(sent?['type'], 'CLOSE');
    expect(sent?['status'], 1);
  });
}
