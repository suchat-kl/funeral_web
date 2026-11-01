// เทสต์งานบัญชี: ยืนยันตัวตนสองขั้น (QR สร้างในเครื่อง) passkey เปลี่ยนรหัสผ่าน (รวมแบบบังคับ) และลืมรหัสผ่านผ่าน ThaID
// พร้อมเทสต์ฟังก์ชันช่วย (วันที่ไทย เลขบัตรแบบปิด ชื่อไฟล์จาก header จำนวนเงิน)

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:funeral_web/main.dart';
import 'package:funeral_web/providers/auth_provider.dart';
import 'package:funeral_web/services/api_service.dart';
import 'package:funeral_web/utils/util.dart';
import 'package:funeral_web/widgets/account_form.dart';
import 'package:funeral_web/widgets/change_password_dialog.dart';
import 'package:funeral_web/widgets/forgot_password_dialog.dart';
import 'package:funeral_web/widgets/passkey_dialog.dart';
import 'package:funeral_web/widgets/qr_view.dart';
import 'package:funeral_web/widgets/two_factor_dialog.dart';
import 'package:funeral_web/widgets/work_parts.dart';

import 'fake_backend.dart';
import 'helpers.dart';

void main() {
  setUpAll(loadAppFonts);
  logoutAfter();

  late FakeBackend backend;

  Future<void> setUpAs(WidgetTester tester, String user, String pw) async {
    useDesktopView(tester, size: const Size(1300, 1600));
    backend = await installFakeBackend();
    await loginAs(tester, user, pw);
  }

  Finder field(String hint) => find.widgetWithText(TextFormField, hint);

  Future<void> tapText(WidgetTester tester, String text) async {
    await tester.ensureVisible(find.text(text).last);
    await tester.tap(find.text(text).last);
    await tester.pumpAndSettle();
  }

  group('ยืนยันตัวตนสองขั้น', () {
    testWidgets(
      'เปิดใช้: รหัสผ่าน → QR จาก otpauth_uri (สร้างในเครื่อง) + รหัสตั้งค่า → รหัส 6 หลัก',
      (tester) async {
        await setUpAs(tester, 'member1', 'Member@2569x');
        await pumpScreen(
          tester,
          Scaffold(body: TwoFactorDialog(apiService: ApiService())),
        );
        expect(find.text('ยังไม่ได้เปิดใช้'), findsOneWidget);
        await tapText(tester, 'เปิดใช้ 2FA');
        await tester.enterText(field('กรอกรหัสผ่านปัจจุบัน'), 'Member@2569x');
        await tapText(tester, 'ถัดไป');
        expect(backend.bodyOf('POST /api/account/2fa/setup'), {
          'currentPassword': 'Member@2569x',
        });
        final qr = tester.widget<QrView>(
          find.byKey(const ValueKey('two-factor-qr')),
        );
        expect(qr.data, startsWith('otpauth://totp/'));
        expect(find.byType(CustomPaint), findsWidgets);
        expect(
          find.text('JBSW Y3DP EHPK 3PXP JBSW Y3DP EHPK 3PXP'),
          findsOneWidget,
        );

        await tester.enterText(
          find.byKey(TwoFactorCodeField.fieldKey),
          '111111',
        );
        await tapText(tester, 'ยืนยันและเปิดใช้');
        expect(find.text('รหัส 6 หลักไม่ถูกต้อง'), findsOneWidget);
        await tester.enterText(
          find.byKey(TwoFactorCodeField.fieldKey),
          fakeTotpCode,
        );
        await tapText(tester, 'ยืนยันและเปิดใช้');
        expect(find.text('เปิดใช้อยู่'), findsOneWidget);
        expect(backend.users['member1']!.twoFactor, isTrue);
      },
    );

    testWidgets('ปิดใช้: ต้องใส่ทั้งรหัสผ่านและรหัส 6 หลัก', (tester) async {
      await setUpAs(tester, 'member1', 'Member@2569x');
      backend.users['member1']!.twoFactor = true;
      await pumpScreen(
        tester,
        Scaffold(body: TwoFactorDialog(apiService: ApiService())),
      );
      expect(find.text('เปิดใช้อยู่'), findsOneWidget);
      await tapText(tester, 'ปิดใช้ 2FA');
      expect(find.text(TwoFactorDialog.lostPhoneHelp), findsOneWidget);
      await tester.enterText(field('กรอกรหัสผ่านปัจจุบัน'), 'Member@2569x');
      await tester.enterText(
        find.byKey(TwoFactorCodeField.fieldKey),
        fakeTotpCode,
      );
      await tapText(tester, 'ปิดใช้ 2FA');
      expect(backend.bodyOf('POST /api/account/2fa/disable'), {
        'currentPassword': 'Member@2569x',
        'code': fakeTotpCode,
      });
      expect(find.text('ยังไม่ได้เปิดใช้'), findsOneWidget);
    });
  });

  group('passkey', () {
    testWidgets(
      'เพิ่ม: ยืนยันรหัสผ่าน → สแกน → ส่ง credential เป็นข้อความ JSON แล้วลบได้',
      (tester) async {
        final passkey = installFakePasskey();
        await setUpAs(tester, 'member1', 'Member@2569x');
        await pumpScreen(
          tester,
          Scaffold(
            body: PasskeyDialog(
              apiService: ApiService(),
              authenticator: passkey,
            ),
          ),
        );
        expect(find.text('ยังไม่มี passkey ของบัญชีนี้'), findsOneWidget);
        await tapText(tester, 'เพิ่ม passkey');
        await tester.enterText(field('กรอกรหัสผ่านปัจจุบัน'), 'Member@2569x');
        await tapText(tester, 'สแกนเพื่อเพิ่ม');
        expect(backend.bodyOf('POST /api/account/passkeys/options'), {
          'currentPassword': 'Member@2569x',
        });
        expect(passkey.lastCreateOptions, isNotNull);
        final body = backend.bodyOf('POST /api/account/passkeys')!;
        expect(body['name'], 'Windows Hello');
        expect(body['credential'], isA<String>());
        expect(find.text('ฌาปนกิจ: Windows Hello'), findsOneWidget);

        await tester.tap(find.byTooltip('ลบ'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(ElevatedButton, 'ลบ'));
        await tester.pumpAndSettle();
        expect(
          backend.calls.where(
            (c) => c.startsWith('DELETE /api/account/passkeys/'),
          ),
          hasLength(1),
        );
        expect(find.text('ยังไม่มี passkey ของบัญชีนี้'), findsOneWidget);
      },
    );
  });

  group('เปลี่ยนรหัสผ่าน', () {
    testWidgets(
      'ส่ง oldPassword/newPassword (ไม่ส่งชื่อผู้ใช้) รหัสใหม่ต้องผ่านกติกา',
      (tester) async {
        await setUpAs(tester, 'member1', 'Member@2569x');
        await pumpScreen(
          tester,
          Scaffold(
            body: ChangePasswordDialog(
              username: 'member1',
              apiService: ApiService(),
            ),
          ),
        );
        await tester.enterText(field('กรอกรหัสผ่านเดิม'), 'Member@2569x');
        await tester.enterText(field('กรอกรหัสผ่านใหม่'), 'NewPass@2569');
        await tester.enterText(
          field('กรุณากรอกรหัสผ่านใหม่อีกครั้ง'),
          'NewPass@2569',
        );
        await tapText(tester, 'เปลี่ยนรหัสผ่าน');
        expect(backend.bodyOf('POST /api/auth/changepassword'), {
          'oldPassword': 'Member@2569x',
          'newPassword': 'NewPass@2569',
        });
        expect(backend.users['member1']!.password, 'NewPass@2569');
      },
    );

    testWidgets('บังคับเปลี่ยน: เปลี่ยนสำเร็จแล้วหน้าต่างปิด ใช้งานต่อได้', (
      tester,
    ) async {
      useDesktopView(tester, size: const Size(1400, 1100));
      backend = await installFakeBackend();
      final auth = AuthProvider();
      await tester.pumpWidget(FuneralApp(authProvider: auth));
      await tester.pumpAndSettle();
      await tester.runAsync(() => auth.login('newbie1', 'Temp@2569xx'));
      await tester.pumpAndSettle();
      expect(find.byType(ChangePasswordDialog), findsOneWidget);
      await tester.enterText(field('กรอกรหัสผ่านเดิม'), 'Temp@2569xx');
      await tester.enterText(field('กรอกรหัสผ่านใหม่'), 'NewPass@2569');
      await tester.enterText(
        field('กรุณากรอกรหัสผ่านใหม่อีกครั้ง'),
        'NewPass@2569',
      );
      await tapText(tester, 'เปลี่ยนรหัสผ่าน');
      expect(find.byType(ChangePasswordDialog), findsNothing);
      expect(auth.isLoggedIn, isTrue);
      expect(auth.mustChangePassword, isFalse);
    });
  });

  group('ลืมรหัสผ่าน (ThaID)', () {
    ForgotPasswordResult? result;

    Future<void> open(WidgetTester tester) async {
      useDesktopView(tester, size: const Size(1200, 1400));
      backend = await installFakeBackend();
      result = null;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (ctx) => Scaffold(
              body: ElevatedButton(
                onPressed: () async {
                  result = await showDialog<ForgotPasswordResult>(
                    context: ctx,
                    builder: (_) =>
                        ForgotPasswordDialog(apiService: ApiService()),
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    Future<void> fill(WidgetTester tester, String pw) async {
      final fields = find.descendant(
        of: find.byType(NewPasswordFields),
        matching: find.byType(TextFormField),
      );
      await tester.enterText(fields.at(0), pw);
      await tester.enterText(fields.at(1), pw);
      await tapText(tester, 'ยืนยันตัวตนด้วย ThaID');
    }

    testWidgets(
      'ตรวจกติการหัสก่อนเปิด ThaID แล้วส่ง state + รหัสใหม่ ได้ชื่อผู้ใช้กลับมา',
      (tester) async {
        await open(tester);
        final thaid = installFakeThaid()..state = 'st-reset';
        backend.thaid['st-reset'] = FakeThaid(
          'reset',
          backend.users['member1']!.idcard,
        );
        await fill(tester, 'weak');
        expect(find.text(PasswordRules.notMetMessage), findsOneWidget);
        expect(thaid.purposes, isEmpty);

        await fill(tester, 'Reset@2569xx');
        expect(thaid.purposes, ['reset']);
        expect(backend.bodyOf('POST /api/auth/public-thaid/reset'), {
          'state': 'st-reset',
          'newPassword': 'Reset@2569xx',
        });
        expect(result?.username, 'member1');
        expect(result?.message, contains('ชื่อผู้ใช้ของท่านคือ member1'));
      },
    );

    testWidgets('ยังไม่ลงทะเบียน (NOT_REGISTERED): ปุ่มไปลงทะเบียน', (
      tester,
    ) async {
      await open(tester);
      installFakeThaid().state = 'st-r2';
      backend.thaid['st-r2'] = FakeThaid('reset', fakeIdcard('299999999990'));
      await fill(tester, 'Reset@2569xx');
      expect(
        find.text('ยังไม่พบบัญชีของท่าน กรุณาลงทะเบียนก่อน'),
        findsOneWidget,
      );
      await tester.tap(find.byKey(ForgotPasswordDialog.goRegisterKey));
      await tester.pumpAndSettle();
      expect(result?.goRegister, isTrue);
    });
  });

  group('ฟังก์ชันช่วย', () {
    test('วันที่แบบไทยจากข้อความเวลาของ backend', () {
      expect(Util.thaiDateOf('2026-10-28T10:15:00'), '28 ตุลาคม 2569');
      expect(Util.thaiDateOf(null), '-');
      expect(
        Util.thaiDateTimeOf('2026-10-28T10:15:00'),
        '28 ตุลาคม 2569 10:15 น.',
      );
      expect(Util.isoDate(DateTime(1986, 3, 5)), '1986-03-05');
      expect(Util.yearMonth(2569, 9), '2569-09');
      expect(Util.yearMonthName('2569-10'), 'ตุลาคม 2569');
    });

    test('เลขบัตรแบบปิดบางส่วน', () {
      expect(Util.maskIdcard('1234567890121'), '1-xxxx-xxxx0-12-1');
      expect(Util.maskIdcard(null), '-');
    });

    test('ชื่อไฟล์จาก Content-Disposition (รองรับชื่อไทย)', () {
      expect(
        ApiService.fileNameFromDisposition(
          "attachment; filename*=UTF-8''%E0%B9%81%E0%B8%9A%E0%B8%9A.pdf",
        ),
        'แบบ.pdf',
      );
      expect(
        ApiService.fileNameFromDisposition('attachment; filename="rep9.pdf"'),
        'rep9.pdf',
      );
      expect(ApiService.fileNameFromDisposition(null), isNull);
    });

    test('จำนวนเงินมีจุลภาค ทศนิยม 2 ตำแหน่ง ไม่ผ่าน double', () {
      expect(moneyText('1234567.5'), '1,234,567.50');
      expect(moneyText(100), '100.00');
      expect(moneyText(null), '-');
    });

    test('QR สร้างได้จาก otpauth_uri ในเครื่อง', () {
      final m = QrView.matrixOf(
        'otpauth://totp/Funeral:x?secret=$fakeTotpSecret&issuer=Funeral',
      );
      expect(m, isNotNull);
      expect(m!.length, greaterThanOrEqualTo(21));
      expect(QrView.matrixOf(''), isNull);
    });
  });
}
