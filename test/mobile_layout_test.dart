// เทสต์จอมือถือ (375x812): หน้าแรก แถบบน เมนู และหน้าจอหลักต้องไม่ล้น (overflow = เทสต์ล้ม)

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:funeral_web/main.dart';
import 'package:funeral_web/models/stored_file.dart';
import 'package:funeral_web/providers/auth_provider.dart';
import 'package:funeral_web/screens/cash_receipt_screen.dart';
import 'package:funeral_web/screens/chapana_slip_screen.dart';
import 'package:funeral_web/screens/general_files_screen.dart';
import 'package:funeral_web/screens/receipt_period_screen.dart';
import 'package:funeral_web/screens/upload_files_screen.dart';
import 'package:funeral_web/services/api_service.dart';
import 'package:funeral_web/widgets/register_dialog.dart';

import 'fake_backend.dart';
import 'helpers.dart';

void main() {
  setUpAll(loadAppFonts);
  logoutAfter();

  const phone = Size(375, 812);

  testWidgets('หน้าแรกบนมือถือ: ยังไม่เข้าสู่ระบบ และเข้าสู่ระบบแล้ว', (
    tester,
  ) async {
    useDesktopView(tester, size: phone);
    await installFakeBackend();
    final auth = AuthProvider();
    await tester.pumpWidget(FuneralApp(authProvider: auth));
    await tester.pumpAndSettle();
    expect(find.text('ลงทะเบียน'), findsWidgets);
    await tester.runAsync(() => auth.login('upload1', 'Upload@2569x'));
    await tester.pumpAndSettle();
    final scaffold = tester.firstState<ScaffoldState>(find.byType(Scaffold));
    scaffold.openDrawer();
    await tester.pumpAndSettle();
    expect(find.text('เลขสมาชิก 90002'), findsOneWidget);
  });

  testWidgets('หน้าต่างลงทะเบียนบนมือถือ', (tester) async {
    useDesktopView(tester, size: phone);
    await installFakeBackend();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: RegisterDialog(apiService: ApiService())),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(RegisterDialog.memberKey));
    await tester.pumpAndSettle();
    expect(find.byKey(RegisterDialog.idcardKey), findsOneWidget);
  });

  for (final entry in <String, Widget Function()>{
    'แบบฟอร์มทั่วไป': () => GeneralFilesScreen(apiService: ApiService()),
    'ใบเสร็จรายงวด': () => ReceiptPeriodScreen(apiService: ApiService()),
    'ใบเสร็จเงินสด': () => CashReceiptScreen(apiService: ApiService()),
    'นำไฟล์เข้า': () => UploadFilesScreen(
      apiService: ApiService(),
      kind: StoredFile.kindMonthYear,
    ),
    'รายงานฌาปนกิจ-สลิป': () => ChapanaSlipScreen(apiService: ApiService()),
  }.entries) {
    testWidgets('${entry.key} บนมือถือไม่ล้น', (tester) async {
      useDesktopView(tester, size: phone);
      await installFakeBackend();
      await loginAs(tester, 'upload1', 'Upload@2569x');
      await pumpScreen(tester, entry.value());
      expect(tester.takeException(), isNull);
    });
  }
}
