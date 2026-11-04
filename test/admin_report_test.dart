// เทสต์หน้าผู้ดูแล (ผู้ใช้ / ผู้มีสิทธิ์นำไฟล์เข้า / ลายเซ็นใบเสร็จ / นำเข้าข้อมูลเดิม)
// และรายงานฌาปนกิจจากระบบหักหนี้ (rep9 ฌาปนกิจ-สลิป / rep10 ผู้เกษียณ)

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:funeral_web/screens/admin_import_screen.dart';
import 'package:funeral_web/screens/admin_signatures_screen.dart';
import 'package:funeral_web/screens/admin_uploaders_screen.dart';
import 'package:funeral_web/screens/admin_users_screen.dart';
import 'package:funeral_web/screens/chapana_retired_screen.dart';
import 'package:funeral_web/screens/chapana_slip_screen.dart';
import 'package:funeral_web/services/api_service.dart';
import 'package:funeral_web/utils/file_pick.dart';
import 'package:funeral_web/widgets/account_form.dart';
import 'package:funeral_web/widgets/user_admin_dialog.dart';

import 'fake_backend.dart';
import 'helpers.dart';

void main() {
  setUpAll(loadAppFonts);
  logoutAfter();

  late FakeBackend backend;
  late FakeFileSaver saver;
  final today = DateTime(2026, 10, 15);

  Future<void> setUpAs(WidgetTester tester, String user, String pw) async {
    useDesktopView(tester, size: const Size(1400, 1800));
    backend = await installFakeBackend();
    saver = installFakeSaver();
    await loginAs(tester, user, pw);
  }

  Future<void> tapKey(WidgetTester tester, Key key) async {
    await tester.ensureVisible(find.byKey(key).last);
    await tester.tap(find.byKey(key).last);
    await tester.pumpAndSettle();
  }

  Future<void> confirm(WidgetTester tester, String text) async {
    await tester.tap(find.widgetWithText(ElevatedButton, text).last);
    await tester.pumpAndSettle();
  }

  group('ผู้ดูแล › ผู้ใช้', () {
    Future<void> open(WidgetTester tester) async {
      await setUpAs(tester, 'admin1', 'Admin@2569x');
      await pumpScreen(tester, AdminUsersScreen(apiService: ApiService()));
    }

    testWidgets(
      'รายการผู้ใช้แบ่งหน้าจาก backend เลขบัตรไม่แสดงในตาราง ค้นหาได้',
      (tester) async {
        await open(tester);
        expect(backend.queryOf('GET /api/admin/users'), {
          'page': 0,
          'size': 10,
        });
        expect(find.text('member1'), findsOneWidget);
        expect(find.text('ทั้งหมด 6 บัญชี'), findsOneWidget);
        expect(textContaining(backend.users['member1']!.idcard), findsNothing);

        await tester.enterText(
          find.byKey(AdminUsersScreen.searchKey),
          'upload',
        );
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pumpAndSettle();
        expect(backend.queryOf('GET /api/admin/users')!['keyword'], 'upload');
        expect(find.text('member1'), findsNothing);
        expect(find.text('upload1'), findsOneWidget);
      },
    );

    testWidgets('แก้ไข: ประเภทบุคลากร + กำหนดบทบาท ADMIN + บันทึกด้วย PUT', (
      tester,
    ) async {
      await open(tester);
      await tapKey(tester, AdminUsersScreen.editKey('u-member'));
      expect(find.byType(UserAdminDialog), findsOneWidget);
      // เลขบัตรแบบปิดบางส่วน
      expect(textContaining('xxxx'), findsWidgets);
      await tapKey(tester, UserAdminDialog.personTypeKey('E'));
      await tapKey(tester, UserAdminDialog.roleKey('ADMIN'));
      await confirm(tester, 'บันทึก');
      expect(backend.bodyOf('PUT /api/admin/users/u-member'), {
        'personType': 'E',
        'assignedRoles': ['ADMIN'],
        'active': true,
        'locked': false,
      });
      expect(find.byType(UserAdminDialog), findsNothing);
    });

    testWidgets('ตั้งรหัสผ่านใหม่: ตรวจกติกา แล้วส่งให้ backend', (
      tester,
    ) async {
      await open(tester);
      await tapKey(tester, AdminUsersScreen.editKey('u-member'));
      await tapKey(tester, UserAdminDialog.resetPasswordKey);
      final fields = find.descendant(
        of: find.byType(NewPasswordFields),
        matching: find.byType(TextFormField),
      );
      await tester.enterText(fields.at(0), 'weak');
      await tester.enterText(fields.at(1), 'weak');
      await confirm(tester, 'ตั้งรหัสผ่าน');
      expect(find.text(PasswordRules.notMetMessage), findsOneWidget);
      await tester.enterText(fields.at(0), 'NewPass@2569');
      await tester.enterText(fields.at(1), 'NewPass@2569');
      await confirm(tester, 'ตั้งรหัสผ่าน');
      expect(backend.bodyOf('POST /api/admin/users/u-member/reset-password'), {
        'newPassword': 'NewPass@2569',
      });
      expect(textContaining('ตั้งรหัสผ่านใหม่สำเร็จ'), findsOneWidget);
    });

    testWidgets(
      'ปิด 2FA (เฉพาะบัญชีที่เปิด) และลบ passkey ทั้งหมด ถามยืนยันก่อน',
      (tester) async {
        await open(tester);
        await tapKey(tester, AdminUsersScreen.editKey('u-member'));
        expect(find.byKey(UserAdminDialog.disable2faKey), findsNothing);
        await tester.tap(find.text('ปิด').last);
        await tester.pumpAndSettle();

        await tapKey(tester, AdminUsersScreen.editKey('u-otp'));
        await tapKey(tester, UserAdminDialog.disable2faKey);
        await confirm(tester, 'ยืนยัน');
        expect(
          backend.calls,
          contains('POST /api/admin/users/u-otp/disable-2fa'),
        );
        expect(find.byKey(UserAdminDialog.disable2faKey), findsNothing);

        await tapKey(tester, UserAdminDialog.deletePasskeysKey);
        await confirm(tester, 'ยืนยัน');
        expect(
          backend.calls,
          contains('POST /api/admin/users/u-otp/delete-passkeys'),
        );
      },
    );

    testWidgets('ปลดล็อก / ปิดบัญชี: ส่ง locked และ active ตามสวิตช์', (
      tester,
    ) async {
      await open(tester);
      await tapKey(tester, AdminUsersScreen.editKey('u-non'));
      await tapKey(tester, UserAdminDialog.activeKey);
      await confirm(tester, 'บันทึก');
      expect(backend.bodyOf('PUT /api/admin/users/u-non')!['active'], isFalse);
    });

    testWidgets('ไม่ใช่ผู้ดูแล: backend ตอบ 403 แสดงข้อความ', (tester) async {
      await setUpAs(tester, 'upload1', 'Upload@2569x');
      await pumpScreen(tester, AdminUsersScreen(apiService: ApiService()));
      expect(find.text('คุณไม่มีสิทธิ์ใช้งานส่วนนี้'), findsOneWidget);
    });
  });

  group('ผู้ดูแล › ผู้มีสิทธิ์นำไฟล์เข้า', () {
    testWidgets(
      'เพิ่มด้วยเลขบัตรของผู้ที่ลงทะเบียนแล้ว (ตรวจหลักตรวจสอบก่อน) แสดงชื่อจากบัญชีและลบได้',
      (tester) async {
        await setUpAs(tester, 'admin1', 'Admin@2569x');
        await pumpScreen(
          tester,
          AdminUploadersScreen(apiService: ApiService()),
        );
        expect(find.text('ทดสอบ นำไฟล์เข้า'), findsOneWidget);
        // เลขบัตรแสดงแบบปิดบางส่วน
        expect(
          find.text(backend.uploaders.first['idcard'] as String),
          findsNothing,
        );

        await tester.enterText(
          find.byKey(AdminUploadersScreen.idcardKey),
          '1111111111111',
        );
        await tapKey(tester, AdminUploadersScreen.addKey);
        expect(find.text('เลขบัตรประชาชนไม่ถูกต้อง'), findsOneWidget);
        expect(backend.calls, isNot(contains('POST /api/admin/uploaders')));

        final id = backend.users['nonmember1']!.idcard;
        await tester.enterText(find.byKey(AdminUploadersScreen.idcardKey), id);
        await tapKey(tester, AdminUploadersScreen.addKey);
        expect(backend.bodyOf('POST /api/admin/uploaders'), {'idcard': id});
        expect(find.text('ทดสอบ ไม่ใช่สมาชิก'), findsOneWidget);
        final added = backend.uploaders.last['id'] as String;
        expect(
          find.descendant(
            of: find.byKey(ValueKey('uploader-username-$added')),
            matching: find.text('nonmember1'),
            matchRoot: true,
          ),
          findsOneWidget,
        );

        await tapKey(tester, AdminUploadersScreen.deleteKey('up1'));
        await confirm(tester, 'ลบ');
        expect(backend.calls, contains('DELETE /api/admin/uploaders/up1'));
        expect(find.text('ทดสอบ นำไฟล์เข้า'), findsNothing);
      },
    );

    testWidgets('ยังไม่ลงทะเบียน: เพิ่มไม่ได้ แสดงข้อความของ backend', (
      tester,
    ) async {
      await setUpAs(tester, 'admin1', 'Admin@2569x');
      await pumpScreen(tester, AdminUploadersScreen(apiService: ApiService()));
      await tester.enterText(
        find.byKey(AdminUploadersScreen.idcardKey),
        fakeIdcard('399999999998'),
      );
      await tapKey(tester, AdminUploadersScreen.addKey);
      expect(
        find.text(
          'ยังไม่มีผู้ลงทะเบียนด้วยเลขบัตรนี้ ให้เจ้าของเลขบัตรลงทะเบียนก่อน',
        ),
        findsOneWidget,
      );
      expect(find.text('ทดสอบ นำไฟล์เข้า'), findsOneWidget);
      expect(backend.uploaders, hasLength(1));
    });
  });

  group('ผู้ดูแล › ลายเซ็นใบเสร็จ', () {
    testWidgets(
      'แสดงรายการพร้อมรูป เพิ่มด้วย multipart (ตำแหน่งหลายบรรทัด) และลบ',
      (tester) async {
        await setUpAs(tester, 'admin1', 'Admin@2569x');
        PickedFile? next = PickedFile('sign.png', fakePng);
        await pumpScreen(
          tester,
          AdminSignaturesScreen(
            apiService: ApiService(),
            picker: () async => next,
            today: today,
          ),
        );
        expect(find.text('(ทดสอบ รับเงิน)'), findsOneWidget);
        expect(find.text('ตั้งแต่ ตุลาคม 2569'), findsOneWidget);
        expect(backend.calls, contains('GET /api/admin/signatures/s1/image'));

        // ยังไม่กรอกชื่อ/ยังไม่เลือกรูป
        await tapKey(tester, AdminSignaturesScreen.saveKey);
        expect(find.text('กรุณาเลือกรูปลายเซ็น'), findsOneWidget);

        await tapKey(tester, AdminSignaturesScreen.kindKey('DIRECTOR'));
        await tester.enterText(
          find.byKey(AdminSignaturesScreen.nameKey),
          '(ทดสอบ ผู้อำนวยการ)',
        );
        await tester.enterText(
          find.byKey(AdminSignaturesScreen.positionKey),
          'ผู้อำนวยการกองทดสอบ\nเหรัญญิกทดสอบ',
        );
        await tapKey(tester, const ValueKey('month-11'));
        await tapKey(tester, AdminSignaturesScreen.pickKey);
        await tapKey(tester, AdminSignaturesScreen.saveKey);
        final body = backend.bodyOf('POST /api/admin/signatures')!;
        expect(body['kind'], 'DIRECTOR');
        expect(body['name'], '(ทดสอบ ผู้อำนวยการ)');
        expect(body['positionLines'], ['ผู้อำนวยการกองทดสอบ', 'เหรัญญิกทดสอบ']);
        expect(body['effectiveFrom'], '2569-11');
        expect(body['file'], 'sign.png');
        expect(find.text('(ทดสอบ ผู้อำนวยการ)'), findsOneWidget);

        await tapKey(tester, AdminSignaturesScreen.deleteKey('s1'));
        await confirm(tester, 'ลบ');
        expect(backend.calls, contains('DELETE /api/admin/signatures/s1'));
        expect(find.text('(ทดสอบ รับเงิน)'), findsNothing);
      },
    );

    testWidgets('รูปไม่ใช่ JPEG/PNG หรือใหญ่เกิน 2 MB: เตือน', (tester) async {
      await setUpAs(tester, 'admin1', 'Admin@2569x');
      PickedFile? next = PickedFile('sign.gif', Uint8List(3));
      await pumpScreen(
        tester,
        AdminSignaturesScreen(
          apiService: ApiService(),
          picker: () async => next,
        ),
      );
      await tapKey(tester, AdminSignaturesScreen.pickKey);
      expect(find.text('รับเฉพาะรูป JPEG หรือ PNG'), findsOneWidget);
      next = PickedFile('big.jpg', Uint8List(0), size: 3 * 1024 * 1024);
      await tapKey(tester, AdminSignaturesScreen.pickKey);
      expect(textContaining('รูปใหญ่เกิน 2 MB'), findsOneWidget);
    });
  });

  group('ผู้ดูแล › นำเข้าข้อมูลเดิม', () {
    testWidgets('อัปโหลด CSV แล้วแสดงรายงานผล (ใหม่/ซ้ำ/ไฟล์หาย)', (
      tester,
    ) async {
      await setUpAs(tester, 'admin1', 'Admin@2569x');
      PickedFile? next = PickedFile(
        'funeral_general.csv',
        Uint8List.fromList([65, 66]),
      );
      await pumpScreen(
        tester,
        AdminImportScreen(apiService: ApiService(), picker: () async => next),
      );
      await tapKey(tester, AdminImportScreen.pickKey('general'));
      await tapKey(tester, AdminImportScreen.runKey('general'));
      expect(
        backend.bodyOf('POST /api/admin/import/general')!['file'],
        'funeral_general.csv',
      );
      expect(
        find.byKey(AdminImportScreen.resultKey('general')),
        findsOneWidget,
      );
      expect(find.text('3 รายการ'), findsOneWidget);
      expect(find.text('แถว 4: old-form.pdf'), findsOneWidget);

      next = PickedFile('data.txt', Uint8List(2));
      await tapKey(tester, AdminImportScreen.pickKey('monthyear'));
      expect(textContaining('กรุณาเลือกไฟล์ .csv'), findsOneWidget);
    });
  });

  group('รายงานฌาปนกิจ', () {
    testWidgets('rep9: เลือกงวด+ประเภท กดตรวจสอบ แสดงสรุป/ตาราง และออก PDF', (
      tester,
    ) async {
      await setUpAs(tester, 'upload1', 'Upload@2569x');
      await pumpScreen(
        tester,
        ChapanaSlipScreen(apiService: ApiService(), today: today),
      );
      // ไม่เรียกอัตโนมัติ
      expect(backend.calls, isNot(contains('GET /api/reports/chapana-slip')));
      await tapKey(tester, ChapanaSlipScreen.typeKey('E'));
      await tapKey(tester, const ValueKey('month-9'));
      await tapKey(tester, ChapanaSlipScreen.runKey);
      expect(backend.queryOf('GET /api/reports/chapana-slip'), {
        'type': 'E',
        'month': '09',
        'year': '2569',
      });
      expect(find.byKey(ChapanaSlipScreen.summaryKey), findsOneWidget);
      expect(find.text('3 คน · 300.00 บาท'), findsOneWidget);
      expect(find.byKey(ChapanaSlipScreen.rowKey(0)), findsOneWidget);
      expect(find.text('ทดสอบ หักไม่ได้'), findsOneWidget);
      // เลขบัตรปิดบางส่วน
      expect(find.text(fakeIdcard('300000000001')), findsNothing);

      await tester.ensureVisible(find.byKey(ChapanaSlipScreen.reportKey));
      await tester.tap(
        find.descendant(
          of: find.byKey(ChapanaSlipScreen.reportKey),
          matching: find.byType(ElevatedButton),
        ),
      );
      await tester.pumpAndSettle();
      expect(backend.queryOf('GET /api/reports/chapana-slip/pdf'), {
        'type': 'E',
        'month': '09',
        'year': '2569',
      });
      expect(saver.saved.single.fileName, 'rep9-102569-G.pdf');
    });

    testWidgets('rep9: ระบบหักหนี้ยังไม่ตั้งค่า (503) แสดงข้อความของ backend', (
      tester,
    ) async {
      await setUpAs(tester, 'admin1', 'Admin@2569x');
      backend.slipReport = null;
      await pumpScreen(
        tester,
        ChapanaSlipScreen(apiService: ApiService(), today: today),
      );
      await tapKey(tester, ChapanaSlipScreen.runKey);
      expect(
        find.text('ยังไม่ได้ตั้งค่าการเชื่อมต่อระบบหักหนี้'),
        findsOneWidget,
      );
    });

    testWidgets('rep9: งวดยังไม่มีรายการ (404) แสดงข้อความของ backend', (
      tester,
    ) async {
      await setUpAs(tester, 'admin1', 'Admin@2569x');
      backend.failures['GET /api/reports/chapana-slip'] = (
        404,
        'NOT_FOUND',
        'ยังไม่มีรายการฌาปนกิจของงวดนี้ในระบบหักหนี้',
      );
      await pumpScreen(
        tester,
        ChapanaSlipScreen(apiService: ApiService(), today: today),
      );
      await tapKey(tester, ChapanaSlipScreen.runKey);
      expect(
        find.text('ยังไม่มีรายการฌาปนกิจของงวดนี้ในระบบหักหนี้'),
        findsOneWidget,
      );
    });

    testWidgets('rep10: แสดงรายชื่อผู้เกษียณ และออก PDF', (tester) async {
      await setUpAs(tester, 'admin1', 'Admin@2569x');
      await pumpScreen(
        tester,
        ChapanaRetiredScreen(apiService: ApiService(), today: today),
      );
      await tapKey(tester, ChapanaRetiredScreen.runKey);
      expect(backend.queryOf('GET /api/reports/chapana-retired'), {
        'month': '10',
        'year': '2569',
      });
      expect(find.text('นายทดสอบ พ้นสภาพ'), findsOneWidget);
      expect(find.text('เกษียณ/พ้นสภาพ'), findsOneWidget);
      await tester.tap(
        find.descendant(
          of: find.byKey(ChapanaRetiredScreen.reportKey),
          matching: find.byType(ElevatedButton),
        ),
      );
      await tester.pumpAndSettle();
      expect(saver.saved.single.fileName, 'rep10-102569.pdf');
    });

    testWidgets('สมาชิกธรรมดา: backend ตอบ 403', (tester) async {
      await setUpAs(tester, 'member1', 'Member@2569x');
      await pumpScreen(
        tester,
        ChapanaRetiredScreen(apiService: ApiService(), today: today),
      );
      await tapKey(tester, ChapanaRetiredScreen.runKey);
      expect(find.text('คุณไม่มีสิทธิ์ใช้งานส่วนนี้'), findsOneWidget);
    });
  });
}
