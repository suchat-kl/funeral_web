// เทสต์เมนูนำไฟล์เข้า › เพิ่มผู้ใช้งานทะเบียนคุม (ให้บทบาท MONTHYEAR, ประเภท U เปลี่ยนเป็น N ด้วย)

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

  Finder row(String id) => find.byKey(ControlUsersScreen.rowKey(id));

  testWidgets(
    'แสดงทุกคนที่ยังไม่มีสิทธิ์ เรียงลงทะเบียนล่าสุดก่อน เลขบัตรปิดบางส่วน',
    (tester) async {
      await open(tester, 'upload1', 'Upload@2569x');
      // ยังไม่มีสิทธิ์: U สองคน, ไม่ใช่สมาชิกประเภท E, ไม่ใช่สมาชิกไม่ทราบประเภท
      for (final id in ['u-unk1', 'u-unk2', 'u-non', 'u-new']) {
        expect(row(id), findsOneWidget, reason: id);
      }
      // มีสิทธิ์อยู่แล้ว: บทบาทผู้ใช้ทะเบียนคุม สมาชิก ผู้นำไฟล์เข้า ผู้ดูแล
      for (final id in ['u-nb', 'u-member', 'u-otp', 'u-upload', 'u-admin']) {
        expect(row(id), findsNothing, reason: id);
      }
      // ปุ่มตามประเภท: U เปลี่ยนเป็น N ด้วย / ประเภทอื่นให้สิทธิ์อย่างเดียว
      expect(
        find.descendant(
          of: find.byKey(ControlUsersScreen.grantKey('u-unk1')),
          matching: find.text('เปลี่ยนเป็น N + ให้สิทธิ์'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(ControlUsersScreen.grantKey('u-non')),
          matching: find.text('ให้สิทธิ์ทะเบียนคุม'),
        ),
        findsOneWidget,
      );
      // unknown2 ลงทะเบียน 5 พ.ย. อยู่บนกว่า unknown1 (4 พ.ย.)
      expect(top('u-unk2').dy, lessThan(top('u-unk1').dy));
      expect(top('u-unk1').dy, lessThan(top('u-non').dy));
      expect(find.text('5 พฤศจิกายน 2569 10:30 น.'), findsOneWidget);
      expect(textContaining(backend.users['unknown1']!.idcard), findsNothing);
      expect(textContaining('xxxx'), findsWidgets);
      expect(find.text('ทั้งหมด 4 บัญชี'), findsOneWidget);
    },
  );

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
    expect(
      find.text('ไม่มีผู้ใช้ที่ยังไม่มีสิทธิ์ทะเบียนคุมตรงคำค้น'),
      findsOneWidget,
    );
  });

  testWidgets('ประเภท U: เปลี่ยนเป็น N + ให้บทบาท แล้วหายจากรายการ', (
    tester,
  ) async {
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
    await tester.tap(
      find.widgetWithText(ElevatedButton, 'เปลี่ยนเป็น N + ให้สิทธิ์').last,
    );
    await tester.pumpAndSettle();
    expect(
      backend.calls,
      contains('PUT /api/upload/control-users/u-unk1/grant'),
    );
    expect(backend.users['unknown1']!.personType, 'N');
    expect(backend.users['unknown1']!.roles, contains('MONTHYEAR'));
    expect(row('u-unk1'), findsNothing);
    expect(row('u-unk2'), findsOneWidget);
    expect(textContaining('เรียบร้อย'), findsOneWidget);
  });

  testWidgets('ประเภท E: ให้บทบาทอย่างเดียว ประเภทคงเดิม', (tester) async {
    await open(tester, 'admin1', 'Admin@2569x');
    final key = ControlUsersScreen.grantKey('u-non');
    await tester.ensureVisible(find.byKey(key));
    await tester.tap(find.byKey(key));
    await tester.pumpAndSettle();
    // ข้อความยืนยันในหน้าต่าง (หัวหน้าจอก็มีคำนี้)
    expect(
      find.descendant(
        of: find.byType(Dialog),
        matching: textContaining('ประเภทบุคลากรคงเดิม'),
      ),
      findsOneWidget,
    );
    await tester.tap(
      find.widgetWithText(ElevatedButton, 'ให้สิทธิ์ทะเบียนคุม').last,
    );
    await tester.pumpAndSettle();
    expect(
      backend.calls,
      contains('PUT /api/upload/control-users/u-non/grant'),
    );
    expect(backend.users['nonmember1']!.personType, 'E');
    expect(backend.users['nonmember1']!.roles, contains('MONTHYEAR'));
    expect(row('u-non'), findsNothing);
    expect(
      textContaining('ให้สิทธิ์ทะเบียนคุมแก่ nonmember1 เรียบร้อย'),
      findsOneWidget,
    );
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
