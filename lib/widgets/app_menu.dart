// รายการเมนูทั้งระบบ (ข้อกำหนดหัวข้อ 2 "เมนูและสิทธิ์") — ใช้ร่วมกันทั้งเมนูข้างและเมนูบนแถบบน
import 'package:flutter/material.dart';

import '../models/stored_file.dart';
import '../providers/auth_provider.dart';
import '../screens/admin_import_screen.dart';
import '../screens/admin_signatures_screen.dart';
import '../screens/admin_uploaders_screen.dart';
import '../screens/admin_users_screen.dart';
import '../screens/cash_receipt_screen.dart';
import '../screens/chapana_retired_screen.dart';
import '../screens/chapana_slip_screen.dart';
import '../screens/control_users_screen.dart';
import '../screens/deposit/deposit_entry_screen.dart';
import '../screens/deposit/deposit_parts.dart';
import '../screens/deposit/deposit_refund_screen.dart';
import '../screens/deposit/deposit_report_screens.dart';
import '../screens/deposit/deposit_search_screen.dart';
import '../screens/deposit/monthly_cost_screen.dart';
import '../screens/deposit/monthly_process_screen.dart';
import '../screens/general_files_screen.dart';
import '../screens/monthyear_files_screen.dart';
import '../screens/receipt_period_screen.dart';
import '../screens/upload_files_screen.dart';
import '../screens/upload_home_documents_screen.dart';
import '../services/api_service.dart';
import '../utils/passkey.dart';
import '../utils/roles.dart';
import 'account_actions.dart';
import 'passkey_dialog.dart';
import 'two_factor_dialog.dart';

/// เมนูหนึ่งรายการ: เปิดหน้าจอ ([screen]) หรือหน้าต่าง ([dialog]) อย่างใดอย่างหนึ่ง
class AppMenuItem {
  /// รหัสเมนู (ใช้เป็นคีย์ในเทสต์)
  final String id;
  final String title;
  final IconData icon;

  /// เห็นเมนูนี้หรือไม่ตามบทบาท
  final bool Function(MenuAccess a) visible;

  /// สร้างหน้าจอ (เปิดเป็นหน้าใหม่ในพื้นที่เนื้อหา)
  final Widget Function()? screen;

  /// เปิดหน้าต่าง (งานบัญชี) — [context] ต้องเป็นของ navigator ชั้นนอกที่ยังอยู่จนหน้าต่างปิด
  final Future<void> Function(BuildContext context, AuthProvider auth)? dialog;

  const AppMenuItem({
    required this.id,
    required this.title,
    required this.icon,
    required this.visible,
    this.screen,
    this.dialog,
  });

  static Key keyOf(String id) => ValueKey('menu-$id');
}

/// กลุ่มเมนู (ขยายได้ในเมนูข้าง)
class AppMenuGroup {
  final String id;
  final String title;
  final IconData icon;
  final List<AppMenuItem> items;

  const AppMenuGroup({
    required this.id,
    required this.title,
    required this.icon,
    required this.items,
  });

  /// เมนูย่อยที่บทบาทนี้เห็น
  List<AppMenuItem> visibleItems(MenuAccess a) => [
    for (final i in items)
      if (i.visible(a)) i,
  ];

  static Key keyOf(String id) => ValueKey('menu-group-$id');
}

/// เมนูทั้งระบบเรียงตามที่แสดง — เพิ่มเมนูใหม่ที่นี่ (และเงื่อนไขใน [MenuAccess])
List<AppMenuGroup> buildAppMenu() {
  ApiService api() => ApiService();
  return [
    AppMenuGroup(
      id: 'download',
      title: 'ดาวน์โหลด',
      icon: Icons.download,
      items: [
        AppMenuItem(
          id: 'deceased-files',
          title: GeneralFilesScreen.deceasedTitle,
          icon: GeneralFilesScreen.deceasedIcon,
          visible: (a) => a.generalFiles,
          screen: () => GeneralFilesScreen(
            apiService: api(),
            category: FileCategory.deceased,
          ),
        ),
        AppMenuItem(
          id: 'general-files',
          title: GeneralFilesScreen.menuTitle,
          icon: GeneralFilesScreen.menuIcon,
          visible: (a) => a.generalFiles,
          screen: () => GeneralFilesScreen(apiService: api()),
        ),
        AppMenuItem(
          id: 'monthyear-files',
          title: MonthYearFilesScreen.menuTitle,
          icon: MonthYearFilesScreen.menuIcon,
          visible: (a) => a.monthYearFiles,
          screen: () => MonthYearFilesScreen(apiService: api()),
        ),
        AppMenuItem(
          id: 'receipt-period',
          title: ReceiptPeriodScreen.menuTitle,
          icon: ReceiptPeriodScreen.menuIcon,
          visible: (a) => a.periodReceipts,
          screen: () => ReceiptPeriodScreen(apiService: api()),
        ),
        AppMenuItem(
          id: 'receipt-cash',
          title: CashReceiptScreen.menuTitle,
          icon: CashReceiptScreen.menuIcon,
          visible: (a) => a.cashReceipts,
          screen: () => CashReceiptScreen(apiService: api()),
        ),
      ],
    ),
    AppMenuGroup(
      id: 'upload',
      title: 'นำไฟล์เข้า',
      icon: Icons.upload,
      items: [
        AppMenuItem(
          id: 'upload-general',
          title: UploadFilesScreen.generalTitle,
          icon: UploadFilesScreen.generalIcon,
          visible: (a) => a.upload,
          screen: () => UploadFilesScreen(
            apiService: api(),
            kind: StoredFile.kindGeneral,
          ),
        ),
        AppMenuItem(
          id: 'upload-monthyear',
          title: UploadFilesScreen.monthYearTitle,
          icon: UploadFilesScreen.monthYearIcon,
          visible: (a) => a.upload,
          screen: () => UploadFilesScreen(
            apiService: api(),
            kind: StoredFile.kindMonthYear,
          ),
        ),
        AppMenuItem(
          id: 'control-users',
          title: ControlUsersScreen.menuTitle,
          icon: ControlUsersScreen.menuIcon,
          visible: (a) => a.controlUsers,
          screen: () => ControlUsersScreen(apiService: api()),
        ),
        AppMenuItem(
          id: 'upload-home-documents',
          title: UploadHomeDocumentsScreen.menuTitle,
          icon: UploadHomeDocumentsScreen.menuIcon,
          visible: (a) => a.upload,
          screen: () => UploadHomeDocumentsScreen(apiService: api()),
        ),
      ],
    ),
    AppMenuGroup(
      id: 'report',
      title: 'รายงาน',
      icon: Icons.assessment_outlined,
      items: [
        AppMenuItem(
          id: 'report-slip',
          title: ChapanaSlipScreen.menuTitle,
          icon: ChapanaSlipScreen.menuIcon,
          visible: (a) => a.reports,
          screen: () => ChapanaSlipScreen(apiService: api()),
        ),
        AppMenuItem(
          id: 'report-retired',
          title: ChapanaRetiredScreen.menuTitle,
          icon: ChapanaRetiredScreen.menuIcon,
          visible: (a) => a.reports,
          screen: () => ChapanaRetiredScreen(apiService: api()),
        ),
      ],
    ),
    // ── งานเงินฝากฌาปนกิจล่วงหน้า (เจ้าหน้าที่รับฝากเงินล่วงหน้า / ผู้ดูแล) ──
    AppMenuGroup(
      id: 'deposit-member',
      title: depositMemberGroup,
      icon: Icons.badge_outlined,
      items: [
        AppMenuItem(
          id: 'deposit-search',
          title: DepositSearchScreen.menuTitle,
          icon: DepositSearchScreen.menuIcon,
          visible: (a) => a.depositStaff,
          screen: () => DepositSearchScreen(apiService: api()),
        ),
      ],
    ),
    AppMenuGroup(
      id: 'deposit',
      title: depositGroup,
      icon: Icons.savings,
      items: [
        AppMenuItem(
          id: 'deposit-entry',
          title: DepositEntryScreen.menuTitle,
          icon: DepositEntryScreen.menuIcon,
          visible: (a) => a.depositStaff,
          screen: () => DepositEntryScreen(apiService: api()),
        ),
        AppMenuItem(
          id: 'deposit-monthly-cost',
          title: MonthlyCostScreen.menuTitle,
          icon: MonthlyCostScreen.menuIcon,
          visible: (a) => a.depositStaff,
          screen: () => MonthlyCostScreen(apiService: api()),
        ),
        AppMenuItem(
          id: 'deposit-process',
          title: MonthlyProcessScreen.menuTitle,
          icon: MonthlyProcessScreen.menuIcon,
          visible: (a) => a.depositStaff,
          screen: () => MonthlyProcessScreen(apiService: api()),
        ),
        AppMenuItem(
          id: 'deposit-refund',
          title: DepositRefundScreen.menuTitle,
          icon: DepositRefundScreen.menuIcon,
          visible: (a) => a.depositStaff,
          screen: () => DepositRefundScreen(apiService: api()),
        ),
        AppMenuItem(
          id: 'deposit-report-monthly',
          title: 'รายงาน › ${MonthlyReportScreen.menuTitle}',
          icon: MonthlyReportScreen.menuIcon,
          visible: (a) => a.depositStaff,
          screen: () => MonthlyReportScreen(apiService: api()),
        ),
        AppMenuItem(
          id: 'deposit-report-need',
          title: 'รายงาน › ${NeedDepositScreen.menuTitle}',
          icon: NeedDepositScreen.menuIcon,
          visible: (a) => a.depositStaff,
          screen: () => NeedDepositScreen(apiService: api()),
        ),
        AppMenuItem(
          id: 'deposit-report-dunning',
          title: 'รายงาน › ${NeedDepositScreen.dunningTitle}',
          icon: NeedDepositScreen.dunningIcon,
          visible: (a) => a.depositStaff,
          screen: () => NeedDepositScreen(apiService: api(), dunning: true),
        ),
        AppMenuItem(
          id: 'deposit-report-totals',
          title: 'รายงาน › ${DepositTotalsScreen.menuTitle}',
          icon: DepositTotalsScreen.menuIcon,
          visible: (a) => a.depositStaff,
          screen: () => DepositTotalsScreen(apiService: api()),
        ),
      ],
    ),
    AppMenuGroup(
      id: 'admin',
      title: 'ผู้ดูแล',
      icon: Icons.admin_panel_settings_outlined,
      items: [
        AppMenuItem(
          id: 'admin-users',
          title: AdminUsersScreen.menuTitle,
          icon: AdminUsersScreen.menuIcon,
          visible: (a) => a.admin,
          screen: () => AdminUsersScreen(apiService: api()),
        ),
        AppMenuItem(
          id: 'admin-uploaders',
          title: AdminUploadersScreen.menuTitle,
          icon: AdminUploadersScreen.menuIcon,
          visible: (a) => a.admin,
          screen: () => AdminUploadersScreen(apiService: api()),
        ),
        AppMenuItem(
          id: 'admin-signatures',
          title: AdminSignaturesScreen.menuTitle,
          icon: AdminSignaturesScreen.menuIcon,
          visible: (a) => a.admin,
          screen: () => AdminSignaturesScreen(apiService: api()),
        ),
        AppMenuItem(
          id: 'admin-import',
          title: AdminImportScreen.menuTitle,
          icon: AdminImportScreen.menuIcon,
          visible: (a) => a.admin,
          screen: () => AdminImportScreen(apiService: api()),
        ),
      ],
    ),
    AppMenuGroup(
      id: 'account',
      title: 'บัญชี',
      icon: Icons.account_circle_outlined,
      items: [
        // ยังไม่เข้าสู่ระบบ: ทำได้เลยโดยไม่ต้องเปิดหน้าเข้าสู่ระบบก่อน
        AppMenuItem(
          id: 'register',
          title: 'ลงทะเบียน',
          icon: Icons.how_to_reg,
          visible: (a) => !a.loggedIn,
          dialog: showRegisterThenLogin,
        ),
        AppMenuItem(
          id: 'forgot-password',
          title: 'ลืมรหัสผ่าน',
          icon: Icons.password,
          visible: (a) => !a.loggedIn,
          dialog: showForgotPasswordThenLogin,
        ),
        AppMenuItem(
          id: 'change-password',
          title: 'เปลี่ยนรหัสผ่าน',
          icon: Icons.lock_reset,
          visible: (a) => a.account,
          dialog: (c, auth) => showChangePassword(c, auth),
        ),
        AppMenuItem(
          id: 'two-factor',
          title: 'ยืนยันตัวตนสองขั้น',
          icon: Icons.phonelink_lock,
          visible: (a) => a.account,
          dialog: showTwoFactorDialog,
        ),
        // passkey แสดงเมื่อเบราว์เซอร์รองรับ WebAuthn เท่านั้น
        AppMenuItem(
          id: 'passkey',
          title: PasskeyDialog.title,
          icon: Icons.fingerprint,
          visible: (a) =>
              a.account && createPasskeyAuthenticator().isSupported(),
          dialog: showPasskeyDialog,
        ),
      ],
    ),
  ];
}
