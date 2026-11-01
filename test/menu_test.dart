// เทสต์การเห็นเมนูตามบทบาท (ข้อกำหนดหัวข้อ 2 "เมนูและสิทธิ์") ทั้งระดับเงื่อนไขและเมนูข้างจริง

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:funeral_web/main.dart';
import 'package:funeral_web/providers/auth_provider.dart';
import 'package:funeral_web/utils/roles.dart';
import 'package:funeral_web/widgets/app_menu.dart';

import 'fake_backend.dart';
import 'helpers.dart';

void main() {
  setUpAll(loadAppFonts);
  logoutAfter();

  group('MenuAccess ตามตารางเมนูของข้อกำหนด', () {
    MenuAccess a(List<String> roles, {bool loggedIn = true}) =>
        MenuAccess(loggedIn: loggedIn, roles: roles);

    test('ไม่เข้าสู่ระบบ: เห็นเฉพาะแบบฟอร์มทั่วไป', () {
      final x = a(const [], loggedIn: false);
      expect(x.generalFiles, isTrue);
      expect(x.monthYearFiles, isFalse);
      expect(x.periodReceipts, isFalse);
      expect(x.cashReceipts, isFalse);
      expect(x.upload, isFalse);
      expect(x.reports, isFalse);
      expect(x.admin, isFalse);
      expect(x.account, isFalse);
    });

    test('ไม่ใช่สมาชิก: แบบฟอร์ม + ทะเบียนคุม + บัญชี ไม่มีใบเสร็จ', () {
      final x = a(const [Roles.nonMember]);
      expect(x.monthYearFiles, isTrue);
      expect(x.periodReceipts, isFalse);
      expect(x.cashReceipts, isFalse);
      expect(x.upload, isFalse);
      expect(x.account, isTrue);
    });

    test('สมาชิก: ใบเสร็จทั้งสองแบบ ไม่มีนำไฟล์เข้า/รายงาน/ผู้ดูแล', () {
      final x = a(const [Roles.member]);
      expect(x.periodReceipts, isTrue);
      expect(x.cashReceipts, isTrue);
      expect(x.upload, isFalse);
      expect(x.reports, isFalse);
      expect(x.admin, isFalse);
    });

    test(
      'ผู้นำไฟล์เข้าที่ไม่ใช่สมาชิก: ซ่อนใบเสร็จรายงวด แต่ออกใบเสร็จเงินสดได้',
      () {
        final x = a(const [Roles.nonMember, Roles.uploader]);
        expect(x.periodReceipts, isFalse);
        expect(x.cashReceipts, isTrue);
        expect(x.upload, isTrue);
        expect(x.reports, isTrue);
        expect(x.admin, isFalse);
      },
    );

    test('ผู้ดูแล: ทุกเมนูยกเว้นใบเสร็จรายงวด (ไม่ใช่สมาชิก)', () {
      final x = a(const [Roles.nonMember, Roles.uploader, Roles.admin]);
      expect(x.periodReceipts, isFalse);
      expect(x.cashReceipts, isTrue);
      expect(x.upload, isTrue);
      expect(x.reports, isTrue);
      expect(x.admin, isTrue);
    });

    test(
      'ผู้ดูแลที่ backend ไม่ส่ง UPLOADER มาด้วย ยังได้เมนูนำไฟล์เข้า/รายงาน',
      () {
        final x = a(const [Roles.admin]);
        expect(x.upload, isTrue);
        expect(x.reports, isTrue);
      },
    );

    test('บทบาทใหม่ที่ไม่รู้จักถูกเก็บไว้ ไม่ทำให้พัง (รายการเปิด)', () {
      expect(
        Roles.listFrom(['ROLE_ADMIN', 'DEPOSIT_STAFF', 'MEMBER', 'MEMBER']),
        ['ADMIN', 'DEPOSIT_STAFF', 'MEMBER'],
      );
      expect(Roles.nameOf('DEPOSIT_STAFF'), 'DEPOSIT_STAFF');
      expect(Roles.nameOf('ROLE_UPLOADER'), 'ผู้นำไฟล์เข้า');
    });
  });

  group('เมนูข้างของแต่ละบทบาท', () {
    late AuthProvider auth;

    Future<void> openMenu(WidgetTester tester, String? user, String? pw) async {
      // สูงพอให้ทุกกลุ่มที่ขยายแล้วอยู่ในจอ (ไม่ต้องเลื่อนเมนู)
      useDesktopView(tester, size: const Size(1400, 2400));
      await installFakeBackend();
      auth = AuthProvider();
      if (user != null) await tester.runAsync(() => auth.login(user, pw!));
      await tester.pumpWidget(FuneralApp(authProvider: auth));
      await tester.pumpAndSettle();
      // เปิด drawer จากปุ่มเมนูที่แถบบน
      final scaffold = tester.firstState<ScaffoldState>(find.byType(Scaffold));
      scaffold.openDrawer();
      await tester.pumpAndSettle();
      // ขยายทุกกลุ่มที่เห็น
      for (final g in ['upload', 'report', 'admin', 'account']) {
        final f = find.byKey(AppMenuGroup.keyOf(g));
        if (f.evaluate().isNotEmpty) {
          await tester.ensureVisible(f);
          await tester.tap(f);
          await tester.pumpAndSettle();
        }
      }
    }

    void expectItems(Set<String> visible) {
      const all = {
        'general-files',
        'monthyear-files',
        'receipt-period',
        'receipt-cash',
        'upload-general',
        'upload-monthyear',
        'upload-home-documents',
        'report-slip',
        'report-retired',
        'admin-users',
        'admin-uploaders',
        'admin-signatures',
        'admin-import',
        'register',
        'forgot-password',
        'change-password',
        'two-factor',
      };
      for (final id in all) {
        expect(
          find.byKey(AppMenuItem.keyOf(id)),
          visible.contains(id) ? findsOneWidget : findsNothing,
          reason: 'เมนู $id',
        );
      }
    }

    testWidgets('ไม่เข้าสู่ระบบ', (tester) async {
      await openMenu(tester, null, null);
      expectItems({'general-files', 'register', 'forgot-password'});
      expect(find.byKey(AppMenuGroup.keyOf('admin')), findsNothing);
    });

    testWidgets('ไม่ใช่สมาชิก', (tester) async {
      await openMenu(tester, 'nonmember1', 'NonMember@2569x');
      expectItems({
        'general-files',
        'monthyear-files',
        'change-password',
        'two-factor',
      });
    });

    testWidgets('สมาชิก', (tester) async {
      await openMenu(tester, 'member1', 'Member@2569x');
      expectItems({
        'general-files',
        'monthyear-files',
        'receipt-period',
        'receipt-cash',
        'change-password',
        'two-factor',
      });
    });

    testWidgets('ผู้นำไฟล์เข้า (เป็นสมาชิกด้วย)', (tester) async {
      await openMenu(tester, 'upload1', 'Upload@2569x');
      expectItems({
        'general-files',
        'monthyear-files',
        'receipt-period',
        'receipt-cash',
        'upload-general',
        'upload-monthyear',
        'upload-home-documents',
        'report-slip',
        'report-retired',
        'change-password',
        'two-factor',
      });
    });

    testWidgets('ผู้ดูแล (ไม่ใช่สมาชิก)', (tester) async {
      await openMenu(tester, 'admin1', 'Admin@2569x');
      expectItems({
        'general-files',
        'monthyear-files',
        'receipt-cash',
        'upload-general',
        'upload-monthyear',
        'upload-home-documents',
        'report-slip',
        'report-retired',
        'admin-users',
        'admin-uploaders',
        'admin-signatures',
        'admin-import',
        'change-password',
        'two-factor',
      });
    });

    testWidgets('กดเมนูแล้วเปิดหน้าจอ (ทะเบียนคุมรายชื่อ)', (tester) async {
      await openMenu(tester, 'member1', 'Member@2569x');
      await tester.tap(find.byKey(AppMenuItem.keyOf('monthyear-files')));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'ทะเบียนคุมรายชื่อสมาชิกฌาปนกิจรายเดือน เลือกปีและเดือนแล้วดาวน์โหลด',
        ),
        findsOneWidget,
      );
    });
  });
}
