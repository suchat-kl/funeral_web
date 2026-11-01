// ทางเข้าร่วมของงานบัญชีผู้ใช้ (เข้าสู่ระบบ / ลงทะเบียน / ลืมรหัสผ่าน / เปลี่ยนรหัสผ่าน)
// ใช้ทั้งแถบบน เมนูข้าง และหน้าแรก ให้พฤติกรรมเหมือนกันทุกจุด
import 'package:flutter/material.dart';

import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import 'change_password_dialog.dart';
import 'forgot_password_dialog.dart';
import 'login_dialog.dart';
import 'register_dialog.dart';

/// เปิดหน้าต่างเข้าสู่ระบบ (เติมชื่อผู้ใช้/ข้อความให้ได้) คืน true เมื่อเข้าสู่ระบบสำเร็จ
Future<bool> showLogin(
  BuildContext context,
  AuthProvider auth, {
  String? initialUsername,
  String? message,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => LoginDialog(
      authProvider: auth,
      initialUsername: initialUsername,
      initialMessage: message,
    ),
  );
  return ok == true;
}

/// ลงทะเบียน แล้วเปิดหน้าเข้าสู่ระบบเติมชื่อผู้ใช้ให้
/// เลขบัตรมีบัญชีแล้วและผู้ใช้เลือก "ลืมรหัสผ่าน" = เปิดหน้าลืมรหัสผ่านต่อ
Future<void> showRegisterThenLogin(
  BuildContext context,
  AuthProvider auth,
) async {
  final result = await showDialog<RegisterResult>(
    context: context,
    barrierDismissible: false,
    builder: (_) => RegisterDialog(apiService: ApiService()),
  );
  if (result == null || !context.mounted) return;
  if (result.goForgotPassword) {
    await showForgotPasswordThenLogin(context, auth);
    return;
  }
  await showLogin(
    context,
    auth,
    initialUsername: result.username,
    message: LoginDialog.registeredMessage,
  );
}

/// ลืมรหัสผ่าน (ยืนยันด้วย ThaID) สำเร็จแล้วเปิดหน้าเข้าสู่ระบบเติมชื่อผู้ใช้ให้
/// ยังไม่มีบัญชีแล้วผู้ใช้เลือกลงทะเบียน = เปิดหน้าลงทะเบียนต่อ
Future<void> showForgotPasswordThenLogin(
  BuildContext context,
  AuthProvider auth,
) async {
  final result = await showDialog<ForgotPasswordResult>(
    context: context,
    barrierDismissible: false,
    builder: (_) => ForgotPasswordDialog(apiService: ApiService()),
  );
  if (result == null || !context.mounted) return;
  if (result.goRegister) {
    await showRegisterThenLogin(context, auth);
    return;
  }
  // ตั้งรหัสใหม่แล้ว backend ยกเลิก token ทั้งหมดของบัญชี: ถ้าเข้าสู่ระบบค้างอยู่ให้ออกก่อน
  if (auth.isLoggedIn) await auth.logout();
  if (!context.mounted) return;
  await showLogin(
    context,
    auth,
    initialUsername: result.username,
    message: result.message,
  );
}

/// เปลี่ยนรหัสผ่านของตัวเอง (ใช้รหัสเดิม) — หน้าต่างแจ้งผลสำเร็จเอง
Future<bool> showChangePassword(BuildContext context, AuthProvider auth) async {
  final ok = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => ChangePasswordDialog(
      username: auth.username ?? '',
      apiService: ApiService(),
    ),
  );
  return ok == true;
}
