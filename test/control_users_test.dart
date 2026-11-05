// เทสต์เมนูนำไฟล์เข้า › เพิ่มผู้ใช้งานทะเบียนคุม (เปลี่ยนประเภท U เป็น N)

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:funeral_web/screens/control_users_screen.dart';
import 'package:funeral_web/services/api_service.dart';

import 'fake_backend.dart';
import 'helpers.dart';

void main() {
  setUpAll(loadAppFonts);
  logoutAfter();

  late FakeBackend backend;

  Future<void> open(WidgetTester tester, String user, String pw) async {
    useDesktopView(tester, size: const Size(1400, 1400));
    backend = await installFakeBackend();
    await loginAs(tester, user, pw);
    await pumpScreen(tester, ControlUsersScreen(apiService: ApiService()));
  }

  Offset top(String id) =>
      find.byKey(ControlUsersScreen.rowKey(id)).evaluate().isEmpty
      ? Offset.infinite
      : (find.byKey(ControlUsersScreen.rowKey(id)).evaluate().first.renderObject
                as RenderBox)
            .localToGlobal(Offset.zero);

  testWidgets('แสดงเฉพาะประเภท U เรียงลงทะเบียนล่าสุดก่อน เลขบัตรปิดบางส่วน', (
    tester,
  ) async {
    await open(tester, 'upload1', 'Upload@2569x');
    expect(find.byKey(ControlUsersScreen.rowKey('u-unk1')), findsOneWidget);
    expect(find.byKey(ControlUsersScreen.rowKey('u-unk2')), findsOneWidget);
    expect(find.byKey(ControlUsersScreen.rowKey('u-nb')), findsNothing);
    expect(find.byKey(ControlUsersScreen.rowKey('u-member')), findsNothing);
    // unknown2 ลงทะเบียน 5 พ.ย. อยู่บนกว่า unknown1 (4 พ.ย.)
    expect(top('u-unk2').dy, lessThan(top('u-unk1').dy));
    expect(find.text('5 พฤศจิกายน 2569 10:30 น.'), findsOneWidget);
    expect(textContaining(backend.users['unknown1']!.idcard), findsNothing);
    expect(textContaining('xxxx'), findsWidgets);
    expect(find.text('ทั้งหมด 2 บัญชี'), findsOneWidget);
  });

  testWidgets('ค้นชื่อ นามสกุล เลขบัตร บางส่วนได้', (tester) async {
    await open(tester, 'admin1', 'Admin@2569x');
    Future<void> search(String q) async {
      await tester.enterText(find.byKey(ControlUsersScreen.searchKey), q);
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
    }

    await search('สมหญิง');
    expect(backend.queryOf('GET /api/upload/control-users'), {'q': 'สมหญิง'});
    expect(find.byKey(ControlUsersScreen.rowKey('u-unk2')), findsOneWidget);
    expect(find.byKey(ControlUsersScreen.rowKey('u-unk1')), findsNothing);

    await search('รอตรวจหนึ่ง');
    expect(find.byKey(ControlUsersScreen.rowKey('u-unk1')), findsOneWidget);
    expect(find.byKey(ControlUsersScreen.rowKey('u-unk2')), findsNothing);

    // เลขบัตรบางส่วน (6 หลักท้ายของ unknown2)
    final id = backend.users['unknown2']!.idcard;
    await search(id.substring(id.length - 6));
    expect(find.byKey(ControlUsersScreen.rowKey('u-unk2')), findsOneWidget);
    expect(find.byKey(ControlUsersScreen.rowKey('u-unk1')), findsNothing);

    await search('ไม่มีคนนี้');
    expect(find.text('ไม่มีผู้ใช้ประเภท U ที่ตรงคำค้น'), findsOneWidget);
  });

  testWidgets('เปลี่ยนเป็น N: ยืนยันแล้วหายจากรายการ', (tester) async {
    await open(tester, 'upload1', 'Upload@2569x');
    final key = ControlUsersScreen.grantKey('u-unk1');
    await tester.ensureVisible(find.byKey(key));
    await tester.tap(find.byKey(key));
    await tester.pumpAndSettle();
    expect(textContaining('ลูกจ้างประจำ เงินนอกงบประมาณ'), findsWidgets);
    // ยกเลิก = ไม่เปลี่ยน
    await tester.tap(find.text('ยกเลิก').last);
    await tester.pumpAndSettle();
    expect(
      backend.calls,
      isNot(contains('PUT /api/upload/control-users/u-unk1/grant')),
    );

    await tester.tap(find.byKey(key));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, 'เปลี่ยนเป็น N').last);
    await tester.pumpAndSettle();
    expect(
      backend.calls,
      contains('PUT /api/upload/control-users/u-unk1/grant'),
    );
    expect(backend.users['unknown1']!.personType, 'N');
    expect(find.byKey(ControlUsersScreen.rowKey('u-unk1')), findsNothing);
    expect(find.byKey(ControlUsersScreen.rowKey('u-unk2')), findsOneWidget);
    expect(textContaining('เรียบร้อย'), findsOneWidget);
  });

  testWidgets('ผู้ใช้ทั่วไปเปิดหน้านี้: backend ตอบ 403 แสดงข้อความ', (
    tester,
  ) async {
    await open(tester, 'nonbudget1', 'NonBudget@2569x');
    expect(backend.calls, contains('GET /api/upload/control-users'));
    expect(find.byKey(ControlUsersScreen.rowKey('u-unk1')), findsNothing);
    expect(textContaining('สิทธิ์'), findsWidgets);
  });
}
