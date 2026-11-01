// แถบบนของแอป — โครงยกจากระบบสลิปภาษี (HTC): ชื่อระบบ ปุ่มธีม ปุ่มเข้าสู่ระบบสามแบบ และเมนูผู้ใช้
import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../config/theme.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../utils/logger.dart';
import '../utils/passkey.dart';
import '../utils/roles.dart';
import '../utils/thaid.dart';
import 'account_actions.dart';
import 'app_menu.dart';
import 'passkey_unavailable_dialog.dart';

class CustomHeader extends StatelessWidget implements PreferredSizeWidget {
  final AuthProvider authProvider;

  const CustomHeader({super.key, required this.authProvider});

  static const Key passkeyKey = ValueKey('header-passkey-login');
  static const Key thaidKey = ValueKey('header-thaid-login');
  static const Key loginKey = ValueKey('header-login');
  static const Key guestMenuKey = ValueKey('header-guest-menu');
  static const Key userMenuKey = ValueKey('header-user-menu');

  static const String passkeyButtonTooltip =
      'เข้าสู่ระบบด้วยลายนิ้วมือ / Windows Hello';
  static const String guestAccountMenuTooltip =
      'บัญชีผู้ใช้: ลงทะเบียน / ลืมรหัสผ่าน';

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  bool get _loginBusy => authProvider.thaidBusy || authProvider.passkeyBusy;

  static const TextStyle _menuText = TextStyle(
    fontFamily: 'NotoSansThai',
    fontSize: 14,
    color: AppTheme.textPrimary,
  );

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isNarrow = width < 600;
    final loggedIn = authProvider.isLoggedIn;
    return AppBar(
      backgroundColor: AppTheme.primaryColor,
      foregroundColor: Colors.white,
      elevation: 4,
      title: Row(
        children: [
          if (!isNarrow || loggedIn) ...[
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                AppConfig.logoIcon,
                color: AppTheme.primaryColor,
                size: 28,
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  width < 900 ? AppConfig.shortName : AppConfig.systemName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'NotoSansThai',
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: isNarrow ? 15 : 17,
                  ),
                ),
                Text(
                  AppConfig.orgName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'NotoSansThai',
                    color: Colors.white70,
                    fontSize: isNarrow ? 11 : 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        if (loggedIn && width > 900)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Center(
              child: Text(
                'ยินดีต้อนรับ ${authProvider.displayName}',
                style: const TextStyle(
                  fontFamily: 'NotoSansThai',
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        _themeButton(),
        if (!loggedIn && createPasskeyAuthenticator().isSupported())
          IconButton(
            key: passkeyKey,
            tooltip: passkeyButtonTooltip,
            color: Colors.white,
            disabledColor: Colors.white38,
            iconSize: 28,
            icon: const Icon(Icons.fingerprint),
            onPressed: _loginBusy ? null : () => _loginWithPasskey(context),
          ),
        if (!loggedIn) _thaidButton(context),
        if (!loggedIn) _guestMenu(context),
        Container(
          margin: EdgeInsets.only(right: isNarrow ? 8 : 16),
          child: loggedIn
              ? _userMenu(context)
              : _loginButton(context, isNarrow),
        ),
      ],
    );
  }

  /// ปุ่มจานสี เลือกธีมของทั้งระบบ (จำไว้ใน localStorage `funeral_theme` ดู main.dart)
  Widget _themeButton() => PopupMenuButton<String>(
    tooltip: 'เปลี่ยนธีม',
    icon: const Icon(Icons.palette_outlined, color: Colors.white),
    initialValue: AppTheme.current.id,
    onSelected: AppTheme.select,
    itemBuilder: (context) => [
      for (final palette in AppTheme.palettes)
        PopupMenuItem<String>(
          value: palette.id,
          child: Row(
            children: [
              Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: palette.primary,
                  shape: BoxShape.circle,
                  border: Border.all(color: palette.primaryPale, width: 2),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(palette.name, style: _menuText)),
              if (palette.id == AppTheme.current.id)
                Icon(Icons.check, size: 18, color: palette.primary),
            ],
          ),
        ),
    ],
  );

  static void _notify(
    ScaffoldMessengerState messenger,
    String message,
    Color color,
    IconData icon, {
    int seconds = 5,
    SnackBarAction? action,
  }) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(fontFamily: 'NotoSansThai'),
                ),
              ),
            ],
          ),
          backgroundColor: color,
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: seconds),
          action: action,
        ),
      );
  }

  Future<void> _loginWithPasskey(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final authenticator = createPasskeyAuthenticator();
    if (!await ensurePasskeyAvailable(context, authenticator)) return;
    try {
      final ok = await authProvider.loginWithPasskey(authenticator);
      if (ok) {
        _notify(
          messenger,
          'เข้าสู่ระบบสำเร็จ ยินดีต้อนรับ ${authProvider.displayName}',
          AppTheme.successColor,
          Icons.check_circle,
        );
      }
    } catch (e) {
      if (AppLogger.on) AppLogger.w('เข้าสู่ระบบด้วย passkey ไม่สำเร็จ');
      _notify(
        messenger,
        e.toString(),
        AppTheme.dangerColor,
        Icons.error_outline,
      );
    }
  }

  Widget _thaidButton(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: 6),
    child: Center(
      child: Tooltip(
        message: 'เข้าสู่ระบบด้วย ThaID',
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            key: thaidKey,
            borderRadius: BorderRadius.circular(8),
            onTap: _loginBusy ? null : () => _loginWithThaid(context),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset(
                'assets/images/thaid.png',
                height: 34,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => Container(
                  height: 34,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  alignment: Alignment.center,
                  color: const Color(0xFF06115A),
                  child: const Text(
                    'ThaID',
                    style: TextStyle(
                      fontFamily: 'NotoSansThai',
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );

  /// เข้าสู่ระบบด้วย ThaID จากแถบบน — ยังไม่ลงทะเบียน (NOT_REGISTERED) มีปุ่มไปลงทะเบียนบนแถบแจ้ง
  Future<void> _loginWithThaid(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context, rootNavigator: true);
    try {
      final ok = await authProvider.loginWithThaid();
      if (ok) {
        _notify(
          messenger,
          'เข้าสู่ระบบด้วย ThaID สำเร็จ ยินดีต้อนรับ ${authProvider.displayName}',
          AppTheme.successColor,
          Icons.check_circle,
        );
      } else if (!authProvider.isLoggedIn) {
        _notify(
          messenger,
          thaidCancelledMessage,
          AppTheme.infoColor,
          Icons.info_outline,
        );
      }
    } catch (e) {
      if (AppLogger.on) AppLogger.w('เข้าสู่ระบบด้วย ThaID ไม่สำเร็จ');
      final notRegistered =
          e is ApiException && e.code == ErrorCodes.notRegistered;
      _notify(
        messenger,
        'เข้าสู่ระบบด้วย ThaID ไม่สำเร็จ: $e',
        AppTheme.dangerColor,
        Icons.error_outline,
        seconds: notRegistered ? 15 : 8,
        action: notRegistered
            ? SnackBarAction(
                label: 'ลงทะเบียน',
                textColor: Colors.white,
                onPressed: () {
                  if (navigator.mounted) {
                    showRegisterThenLogin(navigator.context, authProvider);
                  }
                },
              )
            : null,
      );
    }
  }

  Widget _guestMenu(BuildContext context) => PopupMenuButton<String>(
    key: guestMenuKey,
    tooltip: guestAccountMenuTooltip,
    enabled: !_loginBusy,
    icon: const Icon(Icons.manage_accounts_outlined, color: Colors.white),
    onSelected: (v) {
      if (v == 'register') showRegisterThenLogin(context, authProvider);
      if (v == 'forgot') showForgotPasswordThenLogin(context, authProvider);
    },
    itemBuilder: (_) => const [
      PopupMenuItem(
        value: 'register',
        child: Row(
          children: [
            Icon(Icons.how_to_reg, size: 20),
            SizedBox(width: 12),
            Text('ลงทะเบียน', style: _menuText),
          ],
        ),
      ),
      PopupMenuItem(
        value: 'forgot',
        child: Row(
          children: [
            Icon(Icons.password, size: 20),
            SizedBox(width: 12),
            Text('ลืมรหัสผ่าน', style: _menuText),
          ],
        ),
      ),
    ],
  );

  Widget _loginButton(BuildContext context, bool isNarrow) {
    if (isNarrow) {
      return Container(
        decoration: const BoxDecoration(
          color: AppTheme.secondaryColor,
          shape: BoxShape.circle,
        ),
        child: IconButton(
          key: loginKey,
          tooltip: 'เข้าสู่ระบบ',
          color: AppTheme.onSecondaryColor,
          icon: const Icon(Icons.person, size: 20),
          onPressed: _loginBusy ? null : () => showLogin(context, authProvider),
        ),
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.secondaryColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: TextButton.icon(
        key: loginKey,
        onPressed: _loginBusy ? null : () => showLogin(context, authProvider),
        icon: const Icon(
          Icons.person,
          color: AppTheme.onSecondaryColor,
          size: 20,
        ),
        label: const Text(
          'เข้าสู่ระบบ',
          style: TextStyle(
            fontFamily: 'NotoSansThai',
            color: AppTheme.onSecondaryColor,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  /// เมนูผู้ใช้: ข้อมูลบัญชี (อ่านอย่างเดียว) + รายการบัญชีชุดเดียวกับเมนูข้าง + ออกจากระบบ
  Widget _userMenu(BuildContext context) {
    final account = buildAppMenu().firstWhere((g) => g.id == 'account');
    final items = account.visibleItems(authProvider.access);
    return PopupMenuButton<String>(
      key: userMenuKey,
      tooltip: 'บัญชีผู้ใช้',
      offset: const Offset(0, kToolbarHeight),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: (id) async {
        if (id == 'logout') {
          await authProvider.logout();
          return;
        }
        final item = items.firstWhere((i) => i.id == id);
        final root = Navigator.of(context, rootNavigator: true);
        await item.dialog?.call(root.context, authProvider);
      },
      itemBuilder: (_) => [
        PopupMenuItem<String>(
          enabled: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                authProvider.displayName,
                style: _menuText.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              Text(
                '${authProvider.username ?? ''} · ${authProvider.highestRole}',
                style: _menuText.copyWith(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                ),
              ),
              if (authProvider.memberNo != null)
                Text(
                  'เลขสมาชิก ${authProvider.memberNo}',
                  style: _menuText.copyWith(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
              if (authProvider.personType != null)
                Text(
                  'ประเภทบุคลากร: ${PersonType.nameOf(authProvider.personType)}',
                  style: _menuText.copyWith(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
            ],
          ),
        ),
        const PopupMenuDivider(),
        for (final i in items)
          PopupMenuItem<String>(
            key: ValueKey('user-menu-${i.id}'),
            value: i.id,
            child: Row(
              children: [
                Icon(i.icon, size: 20, color: AppTheme.primaryColor),
                const SizedBox(width: 12),
                Text(i.title, style: _menuText),
              ],
            ),
          ),
        const PopupMenuDivider(),
        const PopupMenuItem<String>(
          key: ValueKey('user-menu-logout'),
          value: 'logout',
          child: Row(
            children: [
              Icon(Icons.logout, size: 20, color: AppTheme.dangerColor),
              SizedBox(width: 12),
              Text('ออกจากระบบ', style: _menuText),
            ],
          ),
        ),
      ],
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 17,
            backgroundColor: AppTheme.secondaryColor,
            child: Text(
              authProvider.initials,
              style: const TextStyle(
                fontFamily: 'NotoSansThai',
                color: AppTheme.onSecondaryColor,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
          const Icon(Icons.arrow_drop_down, color: Colors.white),
        ],
      ),
    );
  }
}
