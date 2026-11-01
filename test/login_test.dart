// เทสต์เข้าสู่ระบบ: รหัสผ่าน, ขั้นรหัส 6 หลัก (2FA), ThaID (ยังไม่ลงทะเบียน), passkey (ส่งชื่อผู้ใช้ที่พิมพ์),
// session ที่เก็บในที่เก็บของระบบเอง, บังคับเปลี่ยนรหัสผ่าน และกลับหน้าแรกเมื่อออกจากระบบ

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:funeral_web/config/app_config.dart';
import 'package:funeral_web/main.dart';
import 'package:funeral_web/providers/auth_provider.dart';
import 'package:funeral_web/services/api_service.dart';
import 'package:funeral_web/widgets/account_form.dart';
import 'package:funeral_web/widgets/change_password_dialog.dart';
import 'package:funeral_web/widgets/login_dialog.dart';

import 'fake_backend.dart';
import 'helpers.dart';

void main() {
  late FakeBackend backend;
  late AuthProvider auth;

  setUpAll(loadAppFonts);
  logoutAfter();

  Future<void> open(WidgetTester tester, {String? username}) async {
    useDesktopView(tester, size: const Size(1200, 1100));
    backend = await installFakeBackend();
    auth = AuthProvider();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LoginDialog(authProvider: auth, initialUsername: username),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  final submit = find.widgetWithText(ElevatedButton, 'เข้าสู่ระบบ');
  final username = find.widgetWithText(TextFormField, 'ชื่อผู้ใช้');
  final password = find.widgetWithText(TextFormField, 'รหัสผ่าน');

  testWidgets('หัวหน้าต่างแสดงชื่อระบบฌาปนกิจ', (tester) async {
    await open(tester);
    expect(find.text(AppConfig.systemName), findsOneWidget);
    expect(find.text(LoginDialog.thaidButtonLabel), findsOneWidget);
  });

  testWidgets('ไม่กรอกอะไร: เตือนทั้งสองช่อง ไม่เรียก backend', (tester) async {
    await open(tester);
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(find.text('กรุณากรอกชื่อผู้ใช้'), findsOneWidget);
    expect(find.text('กรุณากรอกรหัสผ่าน'), findsOneWidget);
    expect(backend.calls, isEmpty);
  });

  testWidgets('รหัสผ่านผิด: แสดงข้อความของ backend ยังไม่เข้าสู่ระบบ', (
    tester,
  ) async {
    await open(tester);
    await tester.enterText(username, 'member1');
    await tester.enterText(password, 'wrong');
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(backend.calls, ['POST /api/auth/login']);
    expect(find.text('ชื่อผู้ใช้หรือรหัสผ่านไม่ถูกต้อง'), findsOneWidget);
    expect(auth.isLoggedIn, isFalse);
  });

  testWidgets(
    'เข้าสู่ระบบสำเร็จ: ตัดช่องว่างชื่อผู้ใช้ เก็บบทบาท/เลขสมาชิก และ token ลงที่เก็บของระบบ',
    (tester) async {
      await open(tester);
      await tester.enterText(username, '  member1 ');
      await tester.enterText(password, 'Member@2569x');
      await tester.tap(submit);
      await tester.pumpAndSettle();

      expect(auth.isLoggedIn, isTrue);
      expect(auth.username, 'member1');
      expect(auth.roles, ['MEMBER']);
      expect(auth.memberNo, '90003');
      expect(auth.isMember, isTrue);
      expect(auth.isStaff, isFalse);
      expect(backend.bodyOf('POST /api/auth/login')!['username'], 'member1');
      // ที่เก็บของระบบนี้เอง (ไม่ปนกับสลิปภาษีบนโดเมนเดียวกัน)
      expect(AppConfig.secureDbName, 'FuneralEncryptedStorage');
      final saved = await tester.runAsync(
        () => ApiService().storage.read(key: ApiService.userDataKey),
      );
      expect(jsonDecode(saved!)['roles'], ['MEMBER']);
    },
  );

  group('ยืนยันตัวตนสองขั้น', () {
    Future<void> toSecondStep(WidgetTester tester) async {
      await open(tester);
      await tester.enterText(username, 'otpuser1');
      await tester.enterText(password, 'Otp@2569xx');
      await tester.tap(submit);
      await tester.pumpAndSettle();
    }

    testWidgets('บัญชีเปิด 2FA: ยังไม่เข้าสู่ระบบ แสดงช่องรหัส 6 หลัก', (
      tester,
    ) async {
      await toSecondStep(tester);
      expect(auth.isLoggedIn, isFalse);
      expect(find.text('ยืนยันตัวตนสองขั้น'), findsOneWidget);
      expect(find.byKey(TwoFactorCodeField.fieldKey), findsOneWidget);
      expect(find.text(LoginDialog.twoFactorLostHelp), findsOneWidget);
    });

    testWidgets('รหัสผิด: แสดงข้อความ ลองใหม่ด้วย challenge เดิมจนสำเร็จ', (
      tester,
    ) async {
      await toSecondStep(tester);
      await tester.enterText(find.byKey(TwoFactorCodeField.fieldKey), '000000');
      await tester.tap(find.widgetWithText(ElevatedButton, 'ยืนยัน'));
      await tester.pumpAndSettle();
      expect(find.text('รหัส 6 หลักไม่ถูกต้อง'), findsOneWidget);
      expect(auth.isLoggedIn, isFalse);

      await tester.enterText(
        find.byKey(TwoFactorCodeField.fieldKey),
        fakeTotpCode,
      );
      await tester.tap(find.widgetWithText(ElevatedButton, 'ยืนยัน'));
      await tester.pumpAndSettle();
      expect(auth.isLoggedIn, isTrue);
      // ทั้งสองครั้งใช้ challenge เดียวกัน
      final challenges = [
        for (var i = 0; i < backend.calls.length; i++)
          if (backend.calls[i] == 'POST /api/auth/login/2fa')
            backend.bodies[i]!['challenge'],
      ];
      expect(challenges, hasLength(2));
      expect(challenges.toSet(), hasLength(1));
    });

    testWidgets('challenge หมดอายุ (400 TWO_FACTOR_REJECTED): กลับขั้นแรก', (
      tester,
    ) async {
      await toSecondStep(tester);
      backend.failures['POST /api/auth/login/2fa'] = (
        400,
        'TWO_FACTOR_REJECTED',
        'หมดเวลายืนยันตัวตน กรุณาเข้าสู่ระบบใหม่',
      );
      await tester.enterText(
        find.byKey(TwoFactorCodeField.fieldKey),
        fakeTotpCode,
      );
      await tester.tap(find.widgetWithText(ElevatedButton, 'ยืนยัน'));
      await tester.pumpAndSettle();
      expect(find.byKey(TwoFactorCodeField.fieldKey), findsNothing);
      expect(username, findsOneWidget);
      expect(
        find.text('หมดเวลายืนยันตัวตน กรุณาเข้าสู่ระบบใหม่'),
        findsOneWidget,
      );
    });
  });

  testWidgets('ThaID: เข้าสู่ระบบสำเร็จด้วยเลขบัตรที่ลงทะเบียนแล้ว', (
    tester,
  ) async {
    await open(tester);
    final thaid = installFakeThaid()..state = 'st-login';
    backend.thaid['st-login'] = FakeThaid(
      'login',
      backend.users['member1']!.idcard,
    );
    await tester.tap(find.byKey(const ValueKey('thaid-login')));
    await tester.pumpAndSettle();
    expect(thaid.purposes, ['login']);
    expect(auth.isLoggedIn, isTrue);
    expect(auth.isThaidLogin, isTrue);
    expect(
      backend.bodyOf('POST /api/auth/public-thaid/login')!['state'],
      'st-login',
    );
  });

  testWidgets('ThaID: ยังไม่ลงทะเบียน (404 NOT_REGISTERED) แนะนำให้ลงทะเบียน', (
    tester,
  ) async {
    await open(tester);
    installFakeThaid().state = 'st-new';
    backend.thaid['st-new'] = FakeThaid('login', fakeIdcard('299999999999'));
    await tester.tap(find.byKey(const ValueKey('thaid-login')));
    await tester.pumpAndSettle();
    expect(auth.isLoggedIn, isFalse);
    expect(textContaining(LoginDialog.notRegisteredHint), findsOneWidget);
  });

  testWidgets('ThaID: ผู้ใช้ยกเลิก = แจ้งยกเลิก ไม่เรียกเส้น login', (
    tester,
  ) async {
    await open(tester);
    installFakeThaid().state = null;
    await tester.tap(find.byKey(const ValueKey('thaid-login')));
    await tester.pumpAndSettle();
    expect(find.text('ผู้ใช้งานยกเลิกการใช้ ThaID'), findsOneWidget);
    expect(backend.calls, isNot(contains('POST /api/auth/public-thaid/login')));
  });

  testWidgets(
    'passkey: ส่งชื่อผู้ใช้ที่พิมพ์ไว้ไปขอ options และส่ง credential เป็นข้อความ JSON',
    (tester) async {
      installFakePasskey();
      await open(tester);
      await tester.enterText(username, 'member1');
      await tester.tap(find.byKey(const ValueKey('passkey-login')));
      await tester.pumpAndSettle();
      expect(backend.bodyOf('POST /api/public/passkey/options'), {
        'username': 'member1',
      });
      expect(
        backend.bodyOf('POST /api/public/passkey/login')!['credential'],
        isA<String>(),
      );
      expect(auth.isLoggedIn, isTrue);
      expect(auth.isPasskeyLogin, isTrue);
    },
  );

  testWidgets('passkey: ไม่ได้พิมพ์ชื่อผู้ใช้ = ไม่ส่งช่อง username', (
    tester,
  ) async {
    installFakePasskey();
    await open(tester);
    await tester.tap(find.byKey(const ValueKey('passkey-login')));
    await tester.pumpAndSettle();
    expect(backend.bodyOf('POST /api/public/passkey/options'), isEmpty);
  });

  group('ทั้งแอป', () {
    Future<void> openApp(WidgetTester tester) async {
      useDesktopView(tester, size: const Size(1400, 1000));
      backend = await installFakeBackend();
      auth = AuthProvider();
      await tester.pumpWidget(FuneralApp(authProvider: auth));
      await tester.pumpAndSettle();
    }

    testWidgets(
      'บังคับเปลี่ยนรหัสผ่านเมื่อ must_change_password แล้วใช้งานต่อได้',
      (tester) async {
        await openApp(tester);
        await tester.runAsync(() => auth.login('newbie1', 'Temp@2569xx'));
        await tester.pumpAndSettle();
        expect(find.byType(ChangePasswordDialog), findsOneWidget);
        // ปิดด้วยการกดนอกหน้าต่างไม่ได้
        await tester.tapAt(const Offset(5, 500));
        await tester.pumpAndSettle();
        expect(find.byType(ChangePasswordDialog), findsOneWidget);
      },
    );

    testWidgets('ออกจากระบบจากเมนูผู้ใช้: กลับหน้าแรกและปิดหน้าจอที่เปิดค้าง', (
      tester,
    ) async {
      await openApp(tester);
      await tester.runAsync(() => auth.login('member1', 'Member@2569x'));
      await tester.pumpAndSettle();
      // เปิดหน้าจอซ้อนไว้หนึ่งหน้า
      final nav = tester.state<NavigatorState>(find.byType(Navigator).first);
      nav.push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('หน้าซ้อน')),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('หน้าซ้อน'), findsOneWidget);
      await tester.runAsync(() => auth.logout());
      await tester.pumpAndSettle();
      expect(find.text('หน้าซ้อน'), findsNothing);
      expect(auth.isLoggedIn, isFalse);
      expect(backend.authOf('POST /api/auth/logout'), startsWith('Bearer '));
    });

    testWidgets('หน้าแรกแสดงสถิติและแบบฟอร์มสำหรับทุกคน (ไม่แนบ token)', (
      tester,
    ) async {
      await openApp(tester);
      expect(find.text('1,234'), findsOneWidget);
      expect(find.text('แบบคำขอสมัครสมาชิก'), findsOneWidget);
      // ไม่เข้าสู่ระบบ = เห็นเฉพาะ "ทั้งหมด"
      expect(find.text('แบบเปลี่ยนผู้รับเงิน (ข้าราชการ)'), findsNothing);
      expect(backend.authOf('GET /api/public/general-files'), isNull);
    });
  });
}
