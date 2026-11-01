// ระบบดาวน์โหลดไฟล์และใบเสร็จฌาปนกิจ — โครงแอป (แถบบน เมนูข้าง ธีม ป้ายช่วงทดสอบ) ยกจากระบบสลิปภาษี
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:universal_html/html.dart' as html;

import 'config/app_config.dart';
import 'config/theme.dart';
import 'providers/auth_provider.dart';
import 'screens/home_screen.dart';
import 'services/api_service.dart';
import 'widgets/change_password_dialog.dart';
import 'widgets/header.dart';
import 'widgets/sidebar_menu.dart';
import 'widgets/test_phase_banner.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ===== กันข้อมูลรั่วลง browser console ตอน production =====
  // AppLogger ถูก tree-shake ออกไปแล้วตั้งแต่ตอน compile (ดู lib/utils/logger.dart)
  // สองบล็อกนี้เป็นตาข่ายชั้นสุดท้าย เผื่อมี debugPrint หลุดเข้ามาใหม่
  // หรือมาจาก package ภายนอกที่เราคุมไม่ได้
  if (kReleaseMode) {
    // ปิด debugPrint ทุกจุด รวมถึงของ framework และ package อื่น
    debugPrint = (String? message, {int? wrapWidth}) {};

    // Flutter จะ dump stack trace ลง console เองเมื่อเกิด error แม้ใน release
    // อันนี้เป็นคนละกลไกกับ AppLogger จึงต้องดักแยก
    FlutterError.onError = (FlutterErrorDetails details) {};
  }

  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  // ธีมที่ผู้ใช้เลือกไว้ครั้งก่อน (ไม่มี = ธีมที่ 1) ต้องตั้งก่อนวาดหน้าจอแรก
  try {
    AppTheme.select(html.window.localStorage[AppTheme.storageKey]);
  } catch (_) {}

  // Initialize auth and load session
  final authProvider = AuthProvider();
  await authProvider.loadSession();
  runApp(FuneralApp(authProvider: authProvider));
}

class FuneralApp extends StatefulWidget {
  final AuthProvider authProvider;

  const FuneralApp({super.key, required this.authProvider});

  @override
  State<FuneralApp> createState() => _FuneralAppState();
}

class _FuneralAppState extends State<FuneralApp> {
  @override
  void initState() {
    super.initState();
    // Listen for auth state changes
    widget.authProvider.addListener(_onAuthChanged);
    AppTheme.themeId.addListener(_onThemeChanged);
  }

  @override
  void dispose() {
    // ต้องถอด listener ออก ไม่งั้น AuthProvider (มีอายุยืนกว่า State นี้)
    // จะยังถือ closure ที่อ้างถึง State ที่ถูก dispose ไปแล้วอยู่
    widget.authProvider.removeListener(_onAuthChanged);
    AppTheme.themeId.removeListener(_onThemeChanged);
    super.dispose();
  }

  /// ผู้ใช้เลือกธีมใหม่: จำไว้ในเบราว์เซอร์ แล้ววาดทุกหน้าจอที่เปิดอยู่ใหม่
  /// สีของ AppTheme เป็นค่า static ไม่ได้ผูกกับ Theme.of(context) widget ที่เป็น const
  /// หรือหน้าจอที่ซ้อนอยู่ใน Navigator จึงไม่วาดใหม่เอง ต้องไล่สั่งทีละตัว (state ของหน้าจอไม่หาย)
  void _onThemeChanged() {
    try {
      html.window.localStorage[AppTheme.storageKey] = AppTheme.themeId.value;
    } catch (_) {}
    if (!mounted) return;
    setState(() {});
    void rebuild(Element el) {
      el.markNeedsBuild();
      el.visitChildren(rebuild);
    }

    context.visitChildElements(rebuild);
  }

  void _onAuthChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConfig.systemName,
      debugShowCheckedModeBanner: false,
      // 1. Enable Thai locale globally or per widget
      locale: const Locale('th', 'TH'),
      supportedLocales: const [Locale('en', 'US'), Locale('th', 'TH')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: AppTheme.lightTheme,
      // ป้าย "ระบบงานอยู่ในช่วงทดสอบ" เหนือทุกหน้า — เปิดใช้จริงแล้วให้เอา builder นี้ออก
      builder: (context, child) => Column(
        children: [
          const TestPhaseBanner(),
          Expanded(child: child ?? const SizedBox.shrink()),
        ],
      ),
      home: MainNavigation(authProvider: widget.authProvider),
    );
  }
}

class MainNavigation extends StatefulWidget {
  final AuthProvider authProvider;

  const MainNavigation({super.key, required this.authProvider});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  /// ตรึงเมนูไว้ข้างซ้าย จำไว้ในเบราว์เซอร์ (localStorage ไม่หายตอนออกจากระบบ
  /// ต่างจาก secure storage ที่ถูกล้างทุกครั้งที่ออกจากระบบ)
  static const String _pinnedKey = AppConfig.menuPinnedKey;
  bool _menuPinned = _readPinned();

  /// ตอนตรึง: true = แสดงเฉพาะไอคอน กดปุ่มหรือไอคอนกลุ่มเมนูแล้วขยายเห็นชื่อ
  bool _menuCollapsed = true;

  /// ตรึงเมนูได้เฉพาะจอกว้าง จอแคบ (มือถือ/แท็บเล็ตแนวตั้ง) ใช้เมนูเลื่อนออกแบบเดิม
  static const double _pinMinWidth = 900;

  /// ตอนตรึง หน้าจอที่เปิดจากเมนูไปอยู่ใน navigator นี้ (ด้านขวาของเมนู) เมนูจึงยังเห็นอยู่
  final GlobalKey<NavigatorState> _contentNav = GlobalKey<NavigatorState>();

  static bool _readPinned() {
    try {
      return html.window.localStorage[_pinnedKey] == '1';
    } catch (_) {
      return false;
    }
  }

  void _togglePinned() {
    setState(() {
      _menuPinned = !_menuPinned;
      _menuCollapsed = true;
    });
    try {
      html.window.localStorage[_pinnedKey] = _menuPinned ? '1' : '0';
    } catch (_) {}
  }

  /// กำลังเปิดหน้าบังคับเปลี่ยนรหัสผ่านอยู่ กันเปิดซ้อน
  bool _forcingPasswordChange = false;

  @override
  void initState() {
    super.initState();
    // ตรวจทุกครั้งที่สถานะเข้าสู่ระบบเปลี่ยน ครอบคลุมทั้งปุ่มเข้าสู่ระบบที่แถบบน เมนูข้าง
    // และการกู้ session ตอนเปิดหน้าเว็บใหม่
    widget.authProvider.addListener(_checkMustChangePassword);
    _wasLoggedIn = widget.authProvider.isLoggedIn;
    widget.authProvider.addListener(_goHomeOnLogout);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _checkMustChangePassword(),
    );
  }

  @override
  void dispose() {
    widget.authProvider.removeListener(_checkMustChangePassword);
    widget.authProvider.removeListener(_goHomeOnLogout);
    super.dispose();
  }

  /// สถานะเข้าสู่ระบบครั้งก่อน ใช้จับจังหวะ "เพิ่งออกจากระบบ"
  bool _wasLoggedIn = false;

  /// ออกจากระบบเมื่อใด (ปุ่มที่แถบบน เมนูข้าง หน้าบังคับเปลี่ยนรหัสผ่าน หรือ session หมดอายุ) กลับไปหน้าแรกเสมอ
  /// ปิดหน้าจอที่เปิดค้างทั้งในพื้นที่เนื้อหา (ตอนตรึงเมนู) และที่เปิดทับทั้งจอ
  /// ทำทันทีในจังหวะที่ได้รับแจ้ง ไม่รอเฟรมถัดไป — ผู้เรียกบางจุดเปิดหน้าต่างใหม่ต่อจากการออกจากระบบ
  /// (เช่น ลงทะเบียน / กำหนดรหัสผ่านใหม่) หน้าต่างนั้นต้องไม่ถูกปิดไปด้วย
  void _goHomeOnLogout() {
    final loggedIn = widget.authProvider.isLoggedIn;
    final justLoggedOut = _wasLoggedIn && !loggedIn;
    _wasLoggedIn = loggedIn;
    if (!justLoggedOut || !mounted) return;
    _contentNav.currentState?.popUntil((r) => r.isFirst);
    Navigator.of(context, rootNavigator: true).popUntil((r) => r.isFirst);
  }

  /// ยังใช้รหัสผ่านตั้งต้น: เปิดหน้าเปลี่ยนรหัสผ่านที่ปิดไม่ได้ เลือกได้แค่เปลี่ยนหรือออกจากระบบ
  void _checkMustChangePassword() {
    if (_forcingPasswordChange || !widget.authProvider.mustChangePassword) {
      return;
    }
    _forcingPasswordChange = true;
    // รอให้หน้าต่างเข้าสู่ระบบปิดก่อน แล้วค่อยเปิดหน้าเปลี่ยนรหัสผ่าน
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || !widget.authProvider.mustChangePassword) {
        _forcingPasswordChange = false;
        return;
      }
      // ยังมีหน้าต่างอื่นเปิดทับอยู่ (เช่นหน้าต่างเข้าสู่ระบบที่ยังโหลดสิทธิ์ไม่เสร็จ) รอให้ปิดก่อน
      // ถ้าเปิดซ้อนไป หน้าต่างเข้าสู่ระบบจะ pop ตัวบนสุด = หน้าเปลี่ยนรหัสผ่านทิ้งแทนตัวเอง
      // แล้วค้างหมุนอยู่ (เจอจริง 28 ก.ย. 2569)
      if (!(ModalRoute.of(context)?.isCurrent ?? true)) {
        _forcingPasswordChange = false;
        Future.delayed(
          const Duration(milliseconds: 300),
          _checkMustChangePassword,
        );
        return;
      }
      // ผู้ดูแลตั้งรหัสผ่านให้: ต้องเปลี่ยนรหัสผ่านก่อนใช้งาน (เปลี่ยนด้วยรหัสที่ได้รับ) เลือกได้แค่เปลี่ยนหรือออกจากระบบ
      final changed =
          await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (_) => ChangePasswordDialog(
              username: widget.authProvider.username ?? '',
              apiService: ApiService(),
              forced: true,
            ),
          ) ==
          true;
      _forcingPasswordChange = false;
      if (!changed) {
        await widget.authProvider.logout();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final canPin = MediaQuery.of(context).size.width >= _pinMinWidth;
    final docked = _menuPinned && canPin;

    return Scaffold(
      appBar: CustomHeader(authProvider: widget.authProvider),
      // ตรึงอยู่ไม่มี drawer ปุ่มเมนูที่แถบบนจึงหายไป ใช้ปุ่มบนแถบเมนูข้างแทน
      drawer: docked
          ? null
          : SidebarMenu(
              authProvider: widget.authProvider,
              canPin: canPin,
              onTogglePinned: _togglePinned,
            ),

      body: docked
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SidebarMenu(
                  authProvider: widget.authProvider,
                  docked: true,
                  collapsed: _menuCollapsed,
                  canPin: true,
                  contentNavigator: _contentNav,
                  onToggleCollapsed: () =>
                      setState(() => _menuCollapsed = !_menuCollapsed),
                  onTogglePinned: _togglePinned,
                ),
                // หน้าจอจากเมนูเปิดซ้อนอยู่ในนี้ ชั้นล่างสุดคือหน้าแรก
                Expanded(
                  child: Navigator(
                    key: _contentNav,
                    pages: [
                      MaterialPage(
                        key: const ValueKey('main-tab'),
                        child: _buildBody(),
                      ),
                    ],
                    onDidRemovePage: (_) {},
                  ),
                ),
              ],
            )
          : _buildBody(),
    );
  }

  /// เนื้อหาหลักของแอป: หน้าแรก (หน้าจอจากเมนูเปิดซ้อนบนหน้านี้)
  Widget _buildBody() => HomeScreen(authProvider: widget.authProvider);
}
