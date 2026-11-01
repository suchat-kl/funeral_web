// เทสต์ใบเสร็จรับเงิน: รายงวด (สมาชิกเท่านั้น เลือกหลายงวด/ทั้งหมด รหัสเปิดไฟล์) และเงินสด
// (สมาชิกล็อกเลขของตัวเอง / ผู้นำไฟล์เข้า-ผู้ดูแลค้นสมาชิกแบบ autocomplete ใช้รหัสได้เฉพาะไม่ใส่/กำหนดเอง)

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:funeral_web/models/receipt.dart';
import 'package:funeral_web/screens/cash_receipt_screen.dart';
import 'package:funeral_web/screens/receipt_period_screen.dart';
import 'package:funeral_web/services/api_service.dart';
import 'package:funeral_web/widgets/pdf_password_picker.dart';

import 'fake_backend.dart';
import 'helpers.dart';

void main() {
  setUpAll(loadAppFonts);
  logoutAfter();

  late FakeBackend backend;
  late FakeFileSaver saver;
  final today = DateTime(2026, 11, 1);

  Future<void> setUpUser(WidgetTester tester, String user, String pw) async {
    useDesktopView(tester, size: const Size(1300, 1600));
    backend = await installFakeBackend();
    saver = installFakeSaver();
    await loginAs(tester, user, pw);
  }

  Future<void> tapDownload(WidgetTester tester, Key key) async {
    final button = find.descendant(
      of: find.byKey(key),
      matching: find.byType(ElevatedButton),
    );
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  group('ใบเสร็จรายงวด', () {
    Future<void> open(WidgetTester tester) async {
      await setUpUser(tester, 'member1', 'Member@2569x');
      await pumpScreen(tester, ReceiptPeriodScreen(apiService: ApiService()));
    }

    testWidgets(
      'แสดงงวดเป็นปุ่ม เลือกหลายงวดแล้วดาวน์โหลด PDF ไฟล์เดียว (ไม่ใส่รหัส)',
      (tester) async {
        await open(tester);
        expect(find.text('ม.ค. 69 - มิ.ย. 69'), findsOneWidget);
        // ยังไม่เลือก = ปุ่มดาวน์โหลดกดไม่ได้
        final button = find.descendant(
          of: find.byKey(ReceiptPeriodScreen.downloadKey),
          matching: find.byType(ElevatedButton),
        );
        expect(tester.widget<ElevatedButton>(button).onPressed, isNull);

        await tester.tap(find.byKey(ReceiptPeriodScreen.periodKey('5002')));
        await tester.tap(find.byKey(ReceiptPeriodScreen.periodKey('5003')));
        await tester.pumpAndSettle();
        await tapDownload(tester, ReceiptPeriodScreen.downloadKey);

        expect(backend.bodyOf('POST /api/receipts/pdf'), {
          'receiptNos': ['5003', '5002'],
          'passwordType': 'none',
        });
        expect(saver.saved.single.fileName, 'receipt.pdf');
        expect(saver.saved.single.file.bytes, fakePdf);
      },
    );

    testWidgets('เลือกทั้งหมด + กำหนดรหัสเอง: ตรวจ 4-32 ตัวก่อนส่ง', (
      tester,
    ) async {
      await open(tester);
      await tester.tap(find.byKey(ReceiptPeriodScreen.selectAllKey));
      await tester.pumpAndSettle();
      expect(find.text('เลือกแล้ว 3 จาก 3 งวด'), findsOneWidget);

      await tester.tap(
        find.byKey(PdfPasswordPicker.optionKey(PdfPassword.custom)),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(PdfPasswordPicker.customFieldKey),
        'abc',
      );
      await tapDownload(tester, ReceiptPeriodScreen.downloadKey);
      expect(
        find.text('รหัสเปิดไฟล์ต้องยาว 4 ถึง 32 ตัวอักษร'),
        findsOneWidget,
      );
      expect(backend.calls, isNot(contains('POST /api/receipts/pdf')));

      await tester.enterText(
        find.byKey(PdfPasswordPicker.customFieldKey),
        'Pass1234',
      );
      await tapDownload(tester, ReceiptPeriodScreen.downloadKey);
      final body = backend.bodyOf('POST /api/receipts/pdf')!;
      expect(body['receiptNos'], ['5003', '5002', '5001']);
      expect(body['passwordType'], 'custom');
      expect(body['password'], 'Pass1234');
    });

    testWidgets('รหัสเลขบัตร / วันเกิด: ส่งเฉพาะ passwordType ไม่ส่งรหัส', (
      tester,
    ) async {
      await open(tester);
      await tester.tap(find.byKey(ReceiptPeriodScreen.periodKey('5001')));
      await tester.tap(
        find.byKey(PdfPasswordPicker.optionKey(PdfPassword.birthdate)),
      );
      await tester.pumpAndSettle();
      await tapDownload(tester, ReceiptPeriodScreen.downloadKey);
      expect(backend.bodyOf('POST /api/receipts/pdf'), {
        'receiptNos': ['5001'],
        'passwordType': 'birthdate',
      });
    });

    testWidgets('backend ปฏิเสธ: แสดงข้อความของ backend', (tester) async {
      await open(tester);
      backend.failures['POST /api/receipts/pdf'] = (
        400,
        'BAD_REQUEST',
        'หาวันเกิดของท่านไม่ได้ในขณะนี้ กรุณาเลือกเลขบัตรประชาชนหรือกำหนดรหัสเอง',
      );
      await tester.tap(find.byKey(ReceiptPeriodScreen.periodKey('5001')));
      await tester.pumpAndSettle();
      await tapDownload(tester, ReceiptPeriodScreen.downloadKey);
      expect(
        find.text(
          'หาวันเกิดของท่านไม่ได้ในขณะนี้ กรุณาเลือกเลขบัตรประชาชนหรือกำหนดรหัสเอง',
        ),
        findsOneWidget,
      );
      expect(saver.saved, isEmpty);
    });
  });

  group('ใบเสร็จเงินสด', () {
    testWidgets(
      'สมาชิก: เลขสมาชิกล็อกเป็นของตัวเอง ไม่ส่ง memberNo เลือกหลายเดือน',
      (tester) async {
        await setUpUser(tester, 'member1', 'Member@2569x');
        await pumpScreen(
          tester,
          CashReceiptScreen(apiService: ApiService(), today: today),
        );
        expect(find.byKey(CashReceiptScreen.lockedMemberKey), findsOneWidget);
        expect(find.byKey(CashReceiptScreen.memberFieldKey), findsNothing);
        expect(textContaining('เลขสมาชิก 90003'), findsOneWidget);
        // สี่วิธีของใบเสร็จตัวเอง
        for (final t in PdfPassword.forSelf) {
          expect(find.byKey(PdfPasswordPicker.optionKey(t)), findsOneWidget);
        }

        await tester.tap(find.byKey(const ValueKey('month-3')));
        await tester.tap(find.byKey(const ValueKey('month-1')));
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(PdfPasswordPicker.optionKey(PdfPassword.idcard)),
        );
        await tester.pumpAndSettle();
        await tapDownload(tester, CashReceiptScreen.downloadKey);
        expect(backend.bodyOf('POST /api/cash-receipts/pdf'), {
          'year': '2569',
          'months': [1, 3],
          'passwordType': 'idcard',
        });
        expect(saver.saved.single.fileName, 'cash-receipt.pdf');
      },
    );

    testWidgets(
      'สมาชิก: ไม่เลือกเดือน = เตือน ไม่เรียก backend / ทั้งปีเลือก 12 เดือน',
      (tester) async {
        await setUpUser(tester, 'member1', 'Member@2569x');
        await pumpScreen(
          tester,
          CashReceiptScreen(apiService: ApiService(), today: today),
        );
        await tapDownload(tester, CashReceiptScreen.downloadKey);
        expect(find.text('กรุณาเลือกเดือนอย่างน้อย 1 เดือน'), findsOneWidget);
        expect(backend.calls, isNot(contains('POST /api/cash-receipts/pdf')));
        await tester.tap(find.byKey(CashReceiptScreen.selectAllKey));
        await tester.pumpAndSettle();
        await tapDownload(tester, CashReceiptScreen.downloadKey);
        expect(
          backend.bodyOf('POST /api/cash-receipts/pdf')!['months'],
          List.generate(12, (i) => i + 1),
        );
      },
    );

    testWidgets(
      'ผู้ดูแล: ค้นสมาชิก (≥2 ตัว) เลือกแล้วส่ง memberNo ใช้รหัสได้เฉพาะไม่ใส่/กำหนดเอง',
      (tester) async {
        await setUpUser(tester, 'admin1', 'Admin@2569x');
        await pumpScreen(
          tester,
          CashReceiptScreen(apiService: ApiService(), today: today),
        );
        expect(find.byKey(CashReceiptScreen.lockedMemberKey), findsNothing);
        final input = find.descendant(
          of: find.byKey(CashReceiptScreen.memberFieldKey),
          matching: find.byType(TextField),
        );
        // พิมพ์ตัวเดียวยังไม่ค้น
        await tester.enterText(input, '8');
        await tester.pump(const Duration(milliseconds: 500));
        expect(backend.calls, isNot(contains('GET /api/members/search')));

        await tester.enterText(input, '8100');
        await tester.pump(
          CashReceiptScreen.searchDelay + const Duration(milliseconds: 50),
        );
        await tester.pumpAndSettle();
        expect(backend.queryOf('GET /api/members/search'), {'q': '8100'});
        await tester.tap(find.byKey(const ValueKey('member-81002')));
        await tester.pumpAndSettle();
        expect(textContaining('ออกใบเสร็จให้: 81002'), findsOneWidget);

        // ออกให้ผู้อื่น: ไม่มีตัวเลือกเลขบัตร/วันเกิด
        expect(
          find.byKey(PdfPasswordPicker.optionKey(PdfPassword.idcard)),
          findsNothing,
        );
        expect(
          find.byKey(PdfPasswordPicker.optionKey(PdfPassword.birthdate)),
          findsNothing,
        );
        expect(
          find.byKey(PdfPasswordPicker.optionKey(PdfPassword.custom)),
          findsOneWidget,
        );

        await tester.tap(find.byKey(const ValueKey('month-10')));
        await tester.pumpAndSettle();
        await tapDownload(tester, CashReceiptScreen.downloadKey);
        expect(backend.bodyOf('POST /api/cash-receipts/pdf'), {
          'memberNo': '81002',
          'year': '2569',
          'months': [10],
          'passwordType': 'none',
        });
      },
    );

    testWidgets(
      'ผู้นำไฟล์เข้าที่เป็นสมาชิก: เริ่มที่ใบเสร็จของตัวเอง ใช้รหัสเลขบัตรได้',
      (tester) async {
        await setUpUser(tester, 'upload1', 'Upload@2569x');
        await pumpScreen(
          tester,
          CashReceiptScreen(apiService: ApiService(), today: today),
        );
        expect(textContaining('ออกใบเสร็จให้: 90002'), findsOneWidget);
        expect(
          find.byKey(PdfPasswordPicker.optionKey(PdfPassword.idcard)),
          findsOneWidget,
        );
        await tester.tap(find.byKey(const ValueKey('month-2')));
        await tester.pumpAndSettle();
        await tapDownload(tester, CashReceiptScreen.downloadKey);
        expect(
          backend.bodyOf('POST /api/cash-receipts/pdf')!['memberNo'],
          '90002',
        );
      },
    );

    testWidgets('ผู้ดูแลยังไม่เลือกสมาชิก: เตือน ไม่เรียก backend', (
      tester,
    ) async {
      await setUpUser(tester, 'admin1', 'Admin@2569x');
      await pumpScreen(
        tester,
        CashReceiptScreen(apiService: ApiService(), today: today),
      );
      await tester.tap(find.byKey(const ValueKey('month-2')));
      await tester.pumpAndSettle();
      await tapDownload(tester, CashReceiptScreen.downloadKey);
      expect(find.text('กรุณาค้นและเลือกสมาชิกก่อน'), findsOneWidget);
      expect(backend.calls, isNot(contains('POST /api/cash-receipts/pdf')));
    });
  });

  test('PdfPassword.validateCustom', () {
    expect(PdfPassword.validateCustom(''), isNotNull);
    expect(PdfPassword.validateCustom('abc'), isNotNull);
    expect(PdfPassword.validateCustom(' abcd'), isNotNull);
    expect(PdfPassword.validateCustom('a' * 33), isNotNull);
    expect(PdfPassword.validateCustom('abcd'), isNull);
  });
}
