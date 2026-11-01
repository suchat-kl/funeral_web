// เทสต์ไฟล์: ดาวน์โหลดแบบฟอร์มทั่วไป (ค้นหา/แบ่งหน้า/กรองตามประเภทบุคลากร) ทะเบียนคุมรายชื่อ (เลือกปี-เดือน)
// และนำไฟล์เข้า (เลือกไฟล์ ตรวจชนิด/ขนาด แก้ไข ลบ)

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:funeral_web/models/stored_file.dart';
import 'package:funeral_web/screens/general_files_screen.dart';
import 'package:funeral_web/screens/monthyear_files_screen.dart';
import 'package:funeral_web/screens/upload_files_screen.dart';
import 'package:funeral_web/services/api_service.dart';
import 'package:funeral_web/utils/file_pick.dart';
import 'package:funeral_web/widgets/file_table.dart';
import 'package:funeral_web/widgets/upload_file_dialog.dart';

import 'fake_backend.dart';
import 'helpers.dart';

void main() {
  setUpAll(loadAppFonts);
  logoutAfter();

  late FakeBackend backend;
  late FakeFileSaver saver;
  final today = DateTime(2026, 11, 1);

  Future<void> setUpAs(WidgetTester tester, String? user, String? pw) async {
    useDesktopView(tester, size: const Size(1400, 1600));
    backend = await installFakeBackend();
    saver = installFakeSaver();
    if (user != null) await loginAs(tester, user, pw!);
  }

  group('ดาวน์โหลด › แบบฟอร์มทั่วไป', () {
    testWidgets(
      'ไม่เข้าสู่ระบบ: เห็นเฉพาะ "ทั้งหมด" ไม่แนบ token ดาวน์โหลดได้ชื่อไฟล์เดิม',
      (tester) async {
        await setUpAs(tester, null, null);
        await pumpScreen(tester, GeneralFilesScreen(apiService: ApiService()));
        expect(find.text('แบบคำขอสมัครสมาชิก'), findsOneWidget);
        expect(find.text('ประกาศอัตราเงินสงเคราะห์'), findsOneWidget);
        expect(find.text('แบบเปลี่ยนผู้รับเงิน (ข้าราชการ)'), findsNothing);
        expect(backend.authOf('GET /api/public/general-files'), isNull);

        await tester.tap(find.byKey(const ValueKey('download-g1')));
        await tester.pumpAndSettle();
        expect(saver.saved.single.fileName, 'form1.pdf');
        expect(
          backend.authOf('GET /api/public/general-files/g1/download'),
          isNull,
        );
      },
    );

    testWidgets(
      'ข้าราชการเข้าสู่ระบบ: แนบ token เห็นแบบฟอร์มข้าราชการ + ทั้งหมด',
      (tester) async {
        await setUpAs(tester, 'member1', 'Member@2569x');
        await pumpScreen(tester, GeneralFilesScreen(apiService: ApiService()));
        expect(
          backend.authOf('GET /api/public/general-files'),
          startsWith('Bearer '),
        );
        expect(find.text('แบบเปลี่ยนผู้รับเงิน (ข้าราชการ)'), findsOneWidget);
        expect(find.text('แบบเปลี่ยนผู้รับเงิน (ลูกจ้างประจำ)'), findsNothing);
      },
    );

    testWidgets('ค้นหาในตาราง', (tester) async {
      await setUpAs(tester, 'admin1', 'Admin@2569x');
      await pumpScreen(tester, GeneralFilesScreen(apiService: ApiService()));
      expect(find.byKey(FileTable.rowKey('g4')), findsOneWidget);
      await tester.enterText(find.byKey(FileTable.searchKey), 'ประกาศ');
      await tester.pumpAndSettle();
      expect(find.byKey(FileTable.rowKey('g3')), findsOneWidget);
      expect(find.byKey(FileTable.rowKey('g1')), findsNothing);
    });

    testWidgets('แบ่งหน้าด้วย AppPagination เมื่อมีมากกว่า 5 รายการ', (
      tester,
    ) async {
      await setUpAs(tester, null, null);
      backend.generalFiles = [
        for (var i = 1; i <= 12; i++)
          {
            'id': 'x$i',
            'num': i,
            'typeFile': 'แบบฟอร์ม',
            'title': 'แบบทดสอบลำดับ $i',
            'fileName': 'f$i.pdf',
            'fileFor': 3,
            'uploadedAt': '2026-10-28T10:15:00',
          },
      ];
      await pumpScreen(tester, GeneralFilesScreen(apiService: ApiService()));
      expect(find.text('ทั้งหมด 12 รายการ'), findsOneWidget);
      expect(find.byKey(FileTable.rowKey('x10')), findsOneWidget);
      expect(find.byKey(FileTable.rowKey('x11')), findsNothing);
    });
  });

  group('ดาวน์โหลด › ทะเบียนคุมรายชื่อ', () {
    testWidgets(
      'เปิดมาที่เดือนล่าสุดที่มีไฟล์ เปลี่ยนเดือนแล้วโหลดใหม่ ดาวน์โหลดได้',
      (tester) async {
        await setUpAs(tester, 'nonmember1', 'NonMember@2569x');
        await pumpScreen(
          tester,
          MonthYearFilesScreen(apiService: ApiService(), today: today),
        );
        expect(backend.queryOf('GET /api/monthyear-files'), {
          'yearMonth': '2569-09',
        });
        expect(find.text('ทะเบียนคุมรายชื่อ กันยายน 2569'), findsOneWidget);
        expect(find.text('ทะเบียนคุม ก.ย. 69 ลูกจ้าง'), findsOneWidget);

        await tester.tap(find.byKey(const ValueKey('month-8')));
        await tester.pumpAndSettle();
        expect(backend.queryOf('GET /api/monthyear-files'), {
          'yearMonth': '2569-08',
        });
        expect(find.text('ทะเบียนคุม ส.ค. 69'), findsOneWidget);

        await tester.tap(find.byKey(const ValueKey('download-m3')));
        await tester.pumpAndSettle();
        expect(saver.saved.single.fileName, 'ทะเบียนคุม-m3.pdf');
      },
    );

    testWidgets('เดือนที่ไม่มีไฟล์: แสดงข้อความว่าง', (tester) async {
      await setUpAs(tester, 'member1', 'Member@2569x');
      await pumpScreen(
        tester,
        MonthYearFilesScreen(apiService: ApiService(), today: today),
      );
      await tester.tap(find.byKey(const ValueKey('month-1')));
      await tester.pumpAndSettle();
      expect(find.text('ไม่มีทะเบียนคุมรายชื่อของเดือนนี้'), findsOneWidget);
    });
  });

  group('นำไฟล์เข้า', () {
    PickedFile? next;
    Future<PickedFile?> picker() async => next;

    Future<void> openUpload(WidgetTester tester, String kind) async {
      await setUpAs(tester, 'upload1', 'Upload@2569x');
      await pumpScreen(
        tester,
        UploadFilesScreen(
          apiService: ApiService(),
          kind: kind,
          picker: picker,
          today: today,
        ),
      );
    }

    Future<void> tapKey(WidgetTester tester, Key key) async {
      await tester.ensureVisible(find.byKey(key));
      await tester.tap(find.byKey(key));
      await tester.pumpAndSettle();
    }

    testWidgets('แบบฟอร์มทั่วไป: เลือกไฟล์ เติมชื่อให้ ส่ง multipart ครบช่อง', (
      tester,
    ) async {
      await openUpload(tester, StoredFile.kindGeneral);
      next = PickedFile('แบบใหม่.pdf', Uint8List.fromList([1, 2, 3]));
      await tapKey(tester, UploadFilesScreen.pickKey);
      expect(find.text('แบบใหม่.pdf (3 B)'), findsOneWidget);
      await tester.enterText(find.byKey(UploadFilesScreen.typeKey), 'แบบฟอร์ม');
      await tapKey(tester, FileForChips.chipKey(1));
      await tapKey(tester, UploadFilesScreen.submitKey);

      final body = backend.bodyOf('POST /api/upload/general-files')!;
      expect(body['title'], 'แบบใหม่');
      expect(body['typeFile'], 'แบบฟอร์ม');
      expect(body['fileFor'], '1');
      expect(body['file'], 'แบบใหม่.pdf');
      expect(body['fileSize'], 3);
      expect(body.containsKey('yearMonth'), isFalse);
      expect(
        backend.authOf('POST /api/upload/general-files'),
        startsWith('Bearer '),
      );
      expect(find.text('แบบใหม่'), findsOneWidget);
    });

    testWidgets('ชนิดไฟล์ไม่รับ / ใหญ่เกิน 20 MB: เตือน ไม่ส่ง', (
      tester,
    ) async {
      await openUpload(tester, StoredFile.kindGeneral);
      next = PickedFile('photo.png', Uint8List(4));
      await tapKey(tester, UploadFilesScreen.pickKey);
      expect(
        textContaining('รับเฉพาะไฟล์ pdf doc docx xls xlsx zip'),
        findsOneWidget,
      );
      next = PickedFile('big.zip', Uint8List(0), size: 25 * 1024 * 1024);
      await tapKey(tester, UploadFilesScreen.pickKey);
      expect(textContaining('ไฟล์ใหญ่เกิน 20 MB'), findsOneWidget);
      await tapKey(tester, UploadFilesScreen.submitKey);
      expect(backend.calls, isNot(contains('POST /api/upload/general-files')));
    });

    testWidgets(
      'ทะเบียนคุม: ส่ง yearMonth ของปี-เดือนที่เลือก และตารางกรองตามเดือน',
      (tester) async {
        await openUpload(tester, StoredFile.kindMonthYear);
        expect(backend.queryOf('GET /api/upload/monthyear-files'), {
          'yearMonth': '2569-11',
        });
        await tapKey(tester, const ValueKey('month-9'));
        expect(backend.queryOf('GET /api/upload/monthyear-files'), {
          'yearMonth': '2569-09',
        });
        expect(find.text('ทะเบียนคุม ก.ย. 69 ข้าราชการ'), findsOneWidget);

        next = PickedFile('reg.xlsx', Uint8List(10));
        await tapKey(tester, UploadFilesScreen.pickKey);
        await tester.enterText(
          find.byKey(UploadFilesScreen.titleKey),
          'ทะเบียนคุมทดสอบ',
        );
        await tapKey(tester, UploadFilesScreen.submitKey);
        final body = backend.bodyOf('POST /api/upload/monthyear-files')!;
        expect(body['yearMonth'], '2569-09');
        expect(body['fileFor'], '3');
      },
    );

    testWidgets('แก้ไขรายละเอียด: PUT JSON ไม่มีไฟล์', (tester) async {
      await openUpload(tester, StoredFile.kindGeneral);
      await tapKey(tester, UploadFilesScreen.editKey('g1'));
      final title = find.descendant(
        of: find.byKey(UploadFileDialog.titleKey),
        matching: find.byType(TextFormField),
      );
      await tester.enterText(title, 'แบบคำขอสมัครสมาชิก (ฉบับใหม่)');
      // ตัวเลือกในหน้าต่าง (ชุดหลังสุด) ไม่ใช่ของฟอร์มนำเข้าด้านหลัง
      await tester.tap(find.byKey(FileForChips.chipKey(2)).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('บันทึก').last);
      await tester.pumpAndSettle();
      expect(backend.bodyOf('PUT /api/upload/general-files/g1'), {
        'typeFile': 'แบบฟอร์ม',
        'title': 'แบบคำขอสมัครสมาชิก (ฉบับใหม่)',
        'fileFor': 2,
        'yearMonth': null,
      });
      expect(find.text('แบบคำขอสมัครสมาชิก (ฉบับใหม่)'), findsOneWidget);
    });

    testWidgets('ลบ: ถามยืนยันก่อน กดยกเลิกไม่ลบ กดลบแล้วหายจากตาราง', (
      tester,
    ) async {
      await openUpload(tester, StoredFile.kindGeneral);
      await tapKey(tester, UploadFilesScreen.deleteKey('g3'));
      await tester.tap(find.text('ยกเลิก'));
      await tester.pumpAndSettle();
      expect(
        backend.calls,
        isNot(contains('DELETE /api/upload/general-files/g3')),
      );

      await tapKey(tester, UploadFilesScreen.deleteKey('g3'));
      await tester.tap(find.widgetWithText(ElevatedButton, 'ลบ'));
      await tester.pumpAndSettle();
      expect(backend.calls, contains('DELETE /api/upload/general-files/g3'));
      expect(find.byKey(FileTable.rowKey('g3')), findsNothing);
    });

    testWidgets('สมาชิกธรรมดาเปิดหน้านำไฟล์เข้า: backend ตอบ 403 แสดงข้อความ', (
      tester,
    ) async {
      await setUpAs(tester, 'member1', 'Member@2569x');
      await pumpScreen(
        tester,
        UploadFilesScreen(
          apiService: ApiService(),
          kind: StoredFile.kindGeneral,
        ),
      );
      expect(find.text('คุณไม่มีสิทธิ์ใช้งานส่วนนี้'), findsOneWidget);
    });
  });
}
