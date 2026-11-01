// ตัวช่วยร่วมของเทสต์: จัดจอ ตัวบันทึกไฟล์ปลอม ThaID/passkey ปลอม และเข้าสู่ระบบก่อนเปิดหน้าจอ

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:funeral_web/providers/auth_provider.dart';
import 'package:funeral_web/services/api_service.dart';
import 'package:funeral_web/utils/file_download.dart';
import 'package:funeral_web/utils/passkey.dart';
import 'package:funeral_web/utils/thaid.dart';

import 'fake_backend.dart';

/// ไฟล์ที่หน้าจอส่งให้เบราว์เซอร์ (แทน Blob + ลิงก์ดาวน์โหลด)
class FakeSavedFile implements SavedFile {
  @override
  final String fileName;
  final DownloadedFile file;
  int opened = 0;
  bool disposed = false;

  FakeSavedFile(this.file) : fileName = file.fileName;

  @override
  void open() => opened++;

  @override
  void dispose() => disposed = true;
}

class FakeFileSaver extends FileSaver {
  final List<FakeSavedFile> saved = [];

  @override
  SavedFile save(DownloadedFile file) {
    final f = FakeSavedFile(file);
    saved.add(f);
    return f;
  }
}

/// ติดตั้งตัวบันทึกไฟล์ปลอม (คืนค่าเดิมตอนจบเทสต์)
FakeFileSaver installFakeSaver() {
  final saver = FakeFileSaver();
  final old = FileSaver.instance;
  FileSaver.instance = saver;
  addTearDown(() => FileSaver.instance = old);
  return saver;
}

/// ThaID ปลอม: คืน [state] (null = ผู้ใช้ยกเลิก) และจด purpose ที่ขอ
class FakeThaidAuthorizer {
  String? state;
  final List<String> purposes = [];

  Future<String?> call(ApiService api, {String purpose = 'login'}) async {
    purposes.add(purpose);
    return state;
  }
}

FakeThaidAuthorizer installFakeThaid() {
  final f = FakeThaidAuthorizer();
  thaidAuthorizerOverride = f.call;
  addTearDown(() => thaidAuthorizerOverride = null);
  return f;
}

/// passkey ปลอม: เบราว์เซอร์รองรับ คืนผลสมมุติ
class FakePasskey implements PasskeyAuthenticator {
  Map<String, dynamic>? lastGetOptions;
  Map<String, dynamic>? lastCreateOptions;

  @override
  bool isSupported() => true;

  @override
  Future<bool> isPlatformAuthenticatorAvailable() async => true;

  @override
  Future<Map<String, dynamic>?> create(Map<String, dynamic> publicKey) async {
    lastCreateOptions = publicKey;
    return {'id': 'cred-1', 'type': 'public-key', 'response': {}};
  }

  @override
  Future<Map<String, dynamic>?> get(Map<String, dynamic> publicKey) async {
    lastGetOptions = publicKey;
    return {'id': 'cred-1', 'type': 'public-key', 'response': {}};
  }

  @override
  String defaultName() => 'Windows Hello';
}

FakePasskey installFakePasskey() {
  final p = FakePasskey();
  passkeyAuthenticatorOverride = p;
  addTearDown(() => passkeyAuthenticatorOverride = null);
  return p;
}

/// จอกว้าง (โน้ตบุ๊ก) ให้ตารางแสดงครบคอลัมน์
void useDesktopView(WidgetTester tester, {Size size = const Size(1400, 1000)}) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// เข้าสู่ระบบนอกโซนเวลาจำลอง (ในโซนนั้น await คำขอ Dio ตรง ๆ จะค้าง)
Future<AuthProvider> loginAs(
  WidgetTester tester,
  String username,
  String password,
) async {
  final auth = AuthProvider();
  await tester.runAsync(() => auth.login(username, password));
  return auth;
}

/// เปิดหน้าจอเดี่ยว ๆ ใน MaterialApp
Future<void> pumpScreen(WidgetTester tester, Widget screen) async {
  await tester.pumpWidget(MaterialApp(home: screen));
  await tester.pumpAndSettle();
}

/// ออกจากระบบตอนจบเทสต์ (นอกโซนเวลาจำลอง)
void logoutAfter() {
  tearDown(() async {
    if (ApiService().isLoggedIn) await ApiService().logout();
  });
}

/// ข้อความที่มี [part] อยู่ (ใช้หาข้อความยาวที่มีค่าตัวแปรปน)
Finder textContaining(String part) => find.byWidgetPredicate(
  (w) =>
      w is Text && (w.data ?? w.textSpan?.toPlainText() ?? '').contains(part),
);

/// โหลดฟอนต์จริงของแอป (ฟอนต์ตั้งต้นของเทสต์กว้างกว่ามาก ปุ่ม/แถวจะล้นผิดจากของจริง)
Future<void> loadAppFonts() async {
  for (final family in ['NotoSansThai', 'Sarabun', 'Kanit']) {
    final loader = FontLoader(family);
    for (final w in ['Regular', 'Medium', 'Bold']) {
      loader.addFont(rootBundle.load('assets/fonts/$family-$w.ttf'));
    }
    await loader.load();
  }
}

/// backend + saver ของเทสต์หน้าจอ
Future<FakeBackend> setUpBackend() => installFakeBackend();
