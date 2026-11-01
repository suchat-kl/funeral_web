// เมนูข้าง — โครง/หน้าตายกจากระบบสลิปภาษี (HTC) รายการเมนูมาจาก app_menu.dart (กรองตามบทบาท)
import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../config/theme.dart';
import '../providers/auth_provider.dart';
import 'account_actions.dart';
import 'app_menu.dart';

class SidebarMenu extends StatefulWidget {
  final AuthProvider authProvider;

  /// ตรึงเมนูไว้ข้างซ้ายของหน้าจอ (ไม่ใช่ drawer ที่เลื่อนออกมาแล้วปิด)
  final bool docked;

  /// ตอนตรึง: true = แสดงเฉพาะไอคอน, false = ขยายเห็นทั้งไอคอนและชื่อ
  final bool collapsed;

  /// จอกว้างพอให้ตรึงเมนูได้ (แสดงปุ่มตรึง)
  final bool canPin;

  final VoidCallback? onToggleCollapsed;
  final VoidCallback? onTogglePinned;

  /// ตอนตรึง หน้าจอที่เปิดจากเมนูไปแสดงใน navigator ด้านขวาของเมนู เมนูจึงยังเห็นอยู่
  final GlobalKey<NavigatorState>? contentNavigator;

  const SidebarMenu({
    super.key,
    required this.authProvider,
    this.docked = false,
    this.collapsed = false,
    this.canPin = false,
    this.onToggleCollapsed,
    this.onTogglePinned,
    this.contentNavigator,
  });

  /// ความกว้างของเมนูตอนแสดงเฉพาะไอคอน
  static const double railWidth = 72;

  static const Key homeKey = ValueKey('menu-home');
  static const Key loginKey = ValueKey('menu-login');
  static const Key logoutKey = ValueKey('menu-logout');

  @override
  State<SidebarMenu> createState() => _SidebarMenuState();
}

class _SidebarMenuState extends State<SidebarMenu> {
  /// กลุ่มที่เปิดอยู่ (เริ่มต้นเปิดกลุ่มดาวน์โหลดไว้ ผู้ใช้ส่วนใหญ่ใช้กลุ่มนี้)
  final Set<String> _expanded = {'download'};
  final List<AppMenuGroup> _menu = buildAppMenu();

  bool get _rail => widget.docked && widget.collapsed;

  AuthProvider get _auth => widget.authProvider;

  /// ปิด drawer หลังเลือกเมนู ตอนตรึงไม่มี drawer ให้ปิด
  void _closeMenu(BuildContext context) {
    if (widget.docked) return;
    final scaffold = Scaffold.maybeOf(context);
    if (scaffold != null && scaffold.isDrawerOpen) Navigator.pop(context);
  }

  /// เปิดเมนู: หน้าจอ = ตอนตรึงเปิดในพื้นที่ด้านขวาแทนหน้าที่เปิดอยู่ ไม่ตรึงเปิดเต็มจอ
  /// หน้าต่าง = ใช้ navigator ชั้นนอก (จับไว้ก่อนปิด drawer เพราะปิดแล้ว context ของเมนูใช้ไม่ได้)
  void _openItem(BuildContext context, AppMenuItem item) {
    final root = Navigator.of(context, rootNavigator: true);
    _closeMenu(context);
    final screen = item.screen;
    if (screen != null) {
      final route = MaterialPageRoute<void>(builder: (_) => screen());
      final nav = widget.docked ? widget.contentNavigator?.currentState : null;
      if (nav != null) {
        nav.pushAndRemoveUntil(route, (r) => r.isFirst);
      } else {
        root.push(route);
      }
      return;
    }
    item.dialog?.call(root.context, _auth);
  }

  /// กลับหน้าหลัก ตอนตรึงปิดหน้าที่เปิดค้างในพื้นที่ด้านขวา
  void _goHome(BuildContext context) {
    final nav = widget.docked ? widget.contentNavigator?.currentState : null;
    if (nav != null) {
      nav.popUntil((r) => r.isFirst);
    } else {
      _closeMenu(context);
    }
  }

  double _drawerWidth(double screenWidth) {
    if (screenWidth > 1200) return 340;
    if (screenWidth > 800) return 320;
    if (screenWidth > 600) return 300;
    return screenWidth * 0.85;
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final content = _buildContent(context);
    if (widget.docked) {
      return Material(
        color: Colors.white,
        elevation: 2,
        child: SizedBox(
          width: widget.collapsed
              ? SidebarMenu.railWidth
              : _drawerWidth(screenWidth),
          child: content,
        ),
      );
    }
    return Drawer(
      width: _drawerWidth(screenWidth),
      backgroundColor: Colors.white,
      child: content,
    );
  }

  Widget _buildContent(BuildContext context) {
    final access = _auth.access;
    final groups = [
      for (final g in _menu)
        if (g.visibleItems(access).isNotEmpty) g,
    ];
    return Column(
      children: [
        _buildPinBar(context),
        if (!_rail)
          _auth.isLoggedIn
              ? _buildProfile(context)
              : _buildLoginPrompt(context),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              _item(
                context,
                key: SidebarMenu.homeKey,
                icon: Icons.home,
                title: 'หน้าแรก',
                onTap: () => _goHome(context),
              ),
              for (final g in groups) ...[
                const Divider(indent: 16, endIndent: 16),
                _group(context, g, g.visibleItems(access)),
              ],
              if (!_rail)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'เวอร์ชัน 1.0.0',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'NotoSansThai',
                      fontSize: 11,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  /// แถบบนสุดของเมนู: ปุ่มยุบ/ขยาย และปุ่มตรึง/เลิกตรึง
  Widget _buildPinBar(BuildContext context) {
    if (!widget.docked && !widget.canPin) return const SizedBox.shrink();
    final toggle = IconButton(
      tooltip: _rail ? 'ขยายเมนู' : 'ย่อเมนูเหลือแต่ไอคอน',
      icon: Icon(
        _rail ? Icons.menu : Icons.menu_open,
        color: AppTheme.primaryColor,
      ),
      onPressed: widget.onToggleCollapsed,
    );
    final pin = IconButton(
      tooltip: widget.docked ? 'เลิกตรึงเมนู' : 'ตรึงเมนูไว้ข้างจอ',
      icon: Icon(
        widget.docked ? Icons.push_pin : Icons.push_pin_outlined,
        color: AppTheme.primaryColor,
      ),
      onPressed: () {
        _closeMenu(context);
        widget.onTogglePinned?.call();
      },
    );
    if (_rail) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Center(child: toggle),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
      child: Row(children: [if (widget.docked) toggle, const Spacer(), pin]),
    );
  }

  BoxDecoration get _headerDecoration => BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        AppTheme.primaryColor,
        AppTheme.primaryColor.withValues(alpha: 0.8),
      ],
    ),
  );

  Widget _buildProfile(BuildContext context) {
    final memberNo = _auth.memberNo;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      decoration: _headerDecoration,
      child: Column(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: Colors.white,
            child: Text(
              _auth.initials,
              style: TextStyle(
                fontFamily: 'NotoSansThai',
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryColor,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            _auth.displayName,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'NotoSansThai',
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (_auth.username != null)
            Text(
              _auth.username!,
              style: TextStyle(
                fontFamily: 'NotoSansThai',
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 13,
              ),
            ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.secondaryColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _auth.highestRole,
              style: const TextStyle(
                fontFamily: 'NotoSansThai',
                color: AppTheme.onSecondaryColor,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          if (memberNo != null) ...[
            const SizedBox(height: 6),
            Text(
              'เลขสมาชิก $memberNo',
              style: TextStyle(
                fontFamily: 'NotoSansThai',
                color: Colors.white.withValues(alpha: 0.85),
                fontSize: 12,
              ),
            ),
          ],
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              key: SidebarMenu.logoutKey,
              onPressed: () async {
                _closeMenu(context);
                await _auth.logout();
              },
              icon: const Icon(Icons.logout, size: 18),
              label: const Text(
                'ออกจากระบบ',
                style: TextStyle(fontFamily: 'NotoSansThai'),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: BorderSide(color: Colors.white.withValues(alpha: 0.5)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginPrompt(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: _headerDecoration,
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              AppConfig.logoIcon,
              color: AppTheme.primaryColor,
              size: 32,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            AppConfig.systemName,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'NotoSansThai',
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Text(
            AppConfig.orgName,
            style: TextStyle(
              fontFamily: 'NotoSansThai',
              color: Colors.white70,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              key: SidebarMenu.loginKey,
              onPressed: () {
                final root = Navigator.of(context, rootNavigator: true);
                _closeMenu(context);
                showLogin(root.context, _auth);
              },
              icon: const Icon(Icons.login, size: 20),
              label: const Text(
                'เข้าสู่ระบบ',
                style: TextStyle(fontFamily: 'NotoSansThai', fontSize: 15),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.secondaryColor,
                foregroundColor: AppTheme.onSecondaryColor,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// ไอคอนเมนูตอนยุบ ชี้แล้วขึ้นชื่อเมนู
  Widget _railIcon({
    Key? key,
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: title,
      preferBelow: false,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: key,
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Center(
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: AppTheme.primaryColor, size: 22),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _item(
    BuildContext context, {
    Key? key,
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    if (_rail) {
      return _railIcon(key: key, icon: icon, title: title, onTap: onTap);
    }
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: key,
        onTap: onTap,
        hoverColor: AppTheme.primaryColor.withValues(alpha: 0.05),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: AppTheme.primaryColor, size: 22),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'NotoSansThai',
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              Icon(Icons.chevron_right, size: 20, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }

  /// กลุ่มเมนูแบบขยายได้ (ตอนยุบ: กดไอคอนกลุ่มแล้วขยายเมนูพร้อมเปิดกลุ่มนั้น)
  Widget _group(
    BuildContext context,
    AppMenuGroup group,
    List<AppMenuItem> items,
  ) {
    final open = _expanded.contains(group.id);
    if (_rail) {
      return _railIcon(
        key: AppMenuGroup.keyOf(group.id),
        icon: group.icon,
        title: group.title,
        onTap: () {
          setState(() => _expanded.add(group.id));
          widget.onToggleCollapsed?.call();
        },
      );
    }
    return Column(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            key: AppMenuGroup.keyOf(group.id),
            onTap: () => setState(() {
              if (!_expanded.remove(group.id)) _expanded.add(group.id);
            }),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(
                        alpha: open ? 0.15 : 0.08,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      group.icon,
                      color: open
                          ? AppTheme.secondaryColor
                          : AppTheme.primaryColor,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      group.title,
                      style: TextStyle(
                        fontFamily: 'NotoSansThai',
                        fontSize: 15,
                        fontWeight: open ? FontWeight.bold : FontWeight.w500,
                        color: open
                            ? AppTheme.primaryColor
                            : AppTheme.textPrimary,
                      ),
                    ),
                  ),
                  AnimatedRotation(
                    turns: open ? 0.25 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.chevron_right,
                      size: 20,
                      color: open
                          ? AppTheme.primaryColor
                          : Colors.grey.shade400,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (open)
          Container(
            margin: const EdgeInsets.only(left: 64, right: 16),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.02),
              borderRadius: BorderRadius.circular(8),
              border: Border(
                left: BorderSide(
                  color: AppTheme.primaryColor.withValues(alpha: 0.2),
                  width: 2,
                ),
              ),
            ),
            child: Column(
              children: [
                for (final item in items)
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      key: AppMenuItem.keyOf(item.id),
                      onTap: () => _openItem(context, item),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              item.icon,
                              size: 18,
                              color: AppTheme.textSecondary,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                item.title,
                                style: const TextStyle(
                                  fontFamily: 'NotoSansThai',
                                  fontSize: 14,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
