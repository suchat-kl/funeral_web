// เทสต์เอกสาร PDF บนหน้าแรก: ปุ่มบนหน้าแรก (เฉพาะช่องที่มีไฟล์ เปิด URL สาธารณะในแท็บใหม่)
// และหน้า นำไฟล์เข้า › เอกสารหน้าแรก (เลือก PDF, แก้ข้อความ, เอาออก)

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:funeral_web/providers/auth_provider.dart';
import 'package:funeral_web/screens/home_screen.dart';
import 'package:funeral_web/screens/upload_home_documents_screen.dart';
import 'package:funeral_web/services/api_service.dart';
import 'package:funeral_web/utils/file_download.dart';
import 'package:funeral_web/utils/file_pick.dart';

import 'fake_backend.dart';
import 'helpers.dart';

void main() {
  setUpAll(loadAppFonts);
  logoutAfter();

  late FakeBackend backend;
  final opened = <String>[];

  setUp(() {
    opened.clear();
    LinkOpener.open = opened.add;
    addTearDown(LinkOpener.reset);
  });

  testWidgets('หน้าแรก: แสดงเฉพาะช่องที่มีไฟล์ กดแล้วเปิด URL สาธารณะ', (
    tester,
  ) async {
    useDesktopView(tester, size: const Size(1400, 1600));
    backend = await installFakeBackend();
    await pumpScreen(
      tester,
      Scaffold(body: HomeScreen(authProvider: AuthProvider())),
    );
    expect(find.byKey(HomeScreen.documentKey('INVITE')), findsNothing);
    final reg = find.byKey(HomeScreen.documentKey('REGULATION'));
    expect(reg, findsOneWidget);
    expect(find.text('ข้อบังคับ ฌ.ส.ทล'), findsOneWidget);

    await tester.tap(reg);
    await tester.pump();
    expect(opened, [
      '${ApiService.baseUrl}/api/public/home-documents/REGULATION/file',
    ]);
    expect(backend.authOf('GET /api/public/home-documents'), isNull);
  });

  testWidgets('หน้าแรก: ยังไม่มีไฟล์เลย = ไม่มีแถบปุ่ม', (tester) async {
    useDesktopView(tester, size: const Size(1400, 1600));
    backend = await installFakeBackend();
    for (final d in backend.homeDocuments) {
      d['available'] = false;
    }
    await pumpScreen(
      tester,
      Scaffold(body: HomeScreen(authProvider: AuthProvider())),
    );
    expect(find.byKey(HomeScreen.documentsKey), findsNothing);
  });

  group('นำไฟล์เข้า › เอกสารหน้าแรก', () {
    PickedFile? next;
    Future<PickedFile?> picker() async => next;

    Future<void> open(WidgetTester tester) async {
      useDesktopView(tester, size: const Size(1400, 1600));
      backend = await installFakeBackend();
      await loginAs(tester, 'upload1', 'Upload@2569x');
      await pumpScreen(
        tester,
        UploadHomeDocumentsScreen(apiService: ApiService(), picker: picker),
      );
    }

    Future<void> tapKey(WidgetTester tester, Key key) async {
      await tester.ensureVisible(find.byKey(key));
      await tester.tap(find.byKey(key));
      await tester.pumpAndSettle();
    }

    testWidgets(
      'อัปโหลด PDF ช่องแรก ส่งข้อความ + ไฟล์ แล้วขึ้นว่าแสดงบนหน้าแรก',
      (tester) async {
        await open(tester);
        expect(find.text('ยังไม่มีไฟล์'), findsOneWidget);

        // ยังไม่เลือกไฟล์ บันทึกไม่ได้
        await tapKey(tester, UploadHomeDocumentsScreen.saveKey('INVITE'));
        expect(find.text('กรุณาเลือกไฟล์ PDF'), findsOneWidget);
        expect(
          backend.calls,
          isNot(contains('POST /api/upload/home-documents/INVITE')),
        );

        // ไฟล์ไม่ใช่ PDF
        next = PickedFile('a.docx', Uint8List.fromList([1, 2, 3]));
        await tapKey(tester, UploadHomeDocumentsScreen.pickKey('INVITE'));
        expect(find.text('รับเฉพาะไฟล์ PDF'), findsOneWidget);

        // ใหญ่เกิน
        next = PickedFile('big.pdf', Uint8List(0), size: 21 * 1024 * 1024);
        await tapKey(tester, UploadHomeDocumentsScreen.pickKey('INVITE'));
        expect(find.textContaining('ไฟล์ใหญ่เกิน 20 MB'), findsOneWidget);

        next = PickedFile('out1.pdf', Uint8List.fromList('%PDF-1.4'.codeUnits));
        await tapKey(tester, UploadHomeDocumentsScreen.pickKey('INVITE'));
        await tester.enterText(
          find.byKey(UploadHomeDocumentsScreen.titleKey('INVITE')),
          'เชิญชวนสมัครสมาชิก',
        );
        await tapKey(tester, UploadHomeDocumentsScreen.saveKey('INVITE'));

        final body = backend.bodyOf('POST /api/upload/home-documents/INVITE')!;
        expect(body['title'], 'เชิญชวนสมัครสมาชิก');
        expect(body['file'], 'out1.pdf');
        expect(find.text('ยังไม่มีไฟล์'), findsNothing);
        expect(find.text('แสดงบนหน้าแรก'), findsNWidgets(2));
      },
    );

    testWidgets('แก้ข้อความอย่างเดียวไม่ส่งไฟล์ / เปิดดู / เอาออก', (
      tester,
    ) async {
      await open(tester);
      await tester.enterText(
        find.byKey(UploadHomeDocumentsScreen.titleKey('REGULATION')),
        'ข้อบังคับ ฌ.ส.ทล ฉบับใหม่',
      );
      await tapKey(tester, UploadHomeDocumentsScreen.saveKey('REGULATION'));
      final body = backend.bodyOf(
        'POST /api/upload/home-documents/REGULATION',
      )!;
      expect(body['title'], 'ข้อบังคับ ฌ.ส.ทล ฉบับใหม่');
      expect(body.containsKey('file'), isFalse);

      await tapKey(tester, UploadHomeDocumentsScreen.openKey('REGULATION'));
      expect(
        opened.single,
        endsWith('/api/public/home-documents/REGULATION/file'),
      );

      await tapKey(tester, UploadHomeDocumentsScreen.removeKey('REGULATION'));
      await tester.tap(find.text('เอาออก').last);
      await tester.pumpAndSettle();
      expect(
        backend.calls,
        contains('DELETE /api/upload/home-documents/REGULATION'),
      );
      expect(find.text('ยังไม่มีไฟล์'), findsNWidgets(2));
    });
  });
}
