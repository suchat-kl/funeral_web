import 'dart:async';

import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../models/user_admin.dart';
import '../services/api_service.dart';
import '../utils/roles.dart';
import '../utils/snackbar_helper.dart';
import '../utils/util.dart';
import '../widgets/app_pagination.dart';
import '../widgets/screen_parts.dart';
import '../widgets/sheet_table.dart';
import '../widgets/user_admin_dialog.dart';
import '../widgets/work_parts.dart';

/// ผู้ดูแล › ผู้ใช้ — ค้นหา (ชื่อผู้ใช้ / ชื่อ / เลขสมาชิก) แบ่งหน้าจาก backend แล้วเปิดหน้าต่างแก้ไข
///
/// แก้ได้: ประเภทบุคลากร บทบาทที่ผู้ดูแลกำหนด เปิด/ปิดบัญชี ปลดล็อก ตั้งรหัสผ่านใหม่ ปิด 2FA ลบ passkey
/// มีเลขบัตรและชื่อ: อยู่ในหน่วยความจำของหน้าจอเท่านั้น เลขบัตรแสดงแบบปิดบางส่วน
class AdminUsersScreen extends StatefulWidget {
  final ApiService apiService;

  const AdminUsersScreen({super.key, required this.apiService});

  static const String menuTitle = 'ผู้ใช้';
  static const IconData menuIcon = Icons.manage_accounts;
  static const String groupTitle = 'ผู้ดูแล';

  static const Key searchKey = ValueKey('users-search');
  static Key editKey(String id) => ValueKey('user-edit-$id');

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  final _search = TextEditingController();
  Timer? _debounce;
  UserPage? _data;
  List<RoleInfo> _roles = [];
  int _page = 0;
  int _pageSize = 10;
  bool _loading = true;
  String? _error;
  int _serial = 0;

  @override
  void initState() {
    super.initState();
    _load();
    _loadRoles();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _loadRoles() async {
    try {
      final roles = await widget.apiService.getRoles();
      if (mounted) setState(() => _roles = roles);
    } catch (_) {
      // ไม่มีรายการบทบาท: หน้าต่างแก้ไขยังแสดงบทบาทที่ผู้ใช้ถืออยู่ให้เอาออกได้
    }
  }

  Future<void> _load() async {
    final serial = ++_serial;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await widget.apiService.searchUsers(
        keyword: _search.text,
        page: _page,
        size: _pageSize,
      );
      if (!mounted || serial != _serial) return;
      setState(() {
        _data = data;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || serial != _serial) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  void _onSearch(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      _page = 0;
      _load();
    });
  }

  Future<void> _edit(UserAdmin u) async {
    final saved = await showDialog<UserAdmin>(
      context: context,
      barrierDismissible: false,
      builder: (_) => UserAdminDialog(
        apiService: widget.apiService,
        user: u,
        roles: _roles,
      ),
    );
    if (saved == null || !mounted) return;
    context.showSuccessSnackBar(
      'บันทึกข้อมูลผู้ใช้ ${saved.username} เรียบร้อย',
    );
    await _load();
  }

  Widget _statusChips(UserAdmin u) => Wrap(
    spacing: 4,
    runSpacing: 4,
    children: [
      if (!u.active) const StatusChip('ระงับ', AppTheme.dangerColor),
      if (u.locked) const StatusChip('ล็อก', AppTheme.warningColor),
      if (u.twoFactorEnabled) const StatusChip('2FA', AppTheme.infoColor),
      if (u.mustChangePassword)
        const StatusChip('ต้องเปลี่ยนรหัส', AppTheme.warningColor),
      if (u.active && !u.locked)
        const StatusChip('ใช้งาน', AppTheme.successColor),
    ],
  );

  Widget _row(UserAdmin u) {
    Widget cell(Widget child, int flex) => Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        child: child,
      ),
    );
    return Row(
      key: ValueKey('user-row-${u.id}'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        cell(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                u.username,
                style: screenText(size: 14.5, weight: FontWeight.w600),
              ),
              Text(
                u.fullName.isEmpty ? '-' : u.fullName,
                style: screenText(size: 13, color: AppTheme.textSecondary),
              ),
            ],
          ),
          5,
        ),
        cell(
          Text(
            [
              u.member ? 'สมาชิก ${u.memberNo ?? ''}'.trim() : 'ไม่ใช่สมาชิก',
              PersonType.nameOf(u.personType),
            ].join('\n'),
            style: screenText(size: 13.5),
          ),
          3,
        ),
        cell(
          Text(
            u.roles.isEmpty ? '-' : u.roles.map(Roles.nameOf).join(', '),
            style: screenText(size: 13.5),
          ),
          4,
        ),
        cell(_statusChips(u), 4),
        cell(
          Text(Util.thaiDateOf(u.lastLogin), style: screenText(size: 13)),
          3,
        ),
        cell(
          Align(
            alignment: Alignment.centerRight,
            child: IconButton(
              key: AdminUsersScreen.editKey(u.id),
              tooltip: 'แก้ไข',
              icon: const Icon(Icons.edit, color: AppTheme.editColor),
              onPressed: () => _edit(u),
            ),
          ),
          1,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    final users = data?.users ?? const <UserAdmin>[];
    final totalPages = data == null || data.totalPages < 1
        ? 1
        : data.totalPages;
    return WorkPage(
      group: AdminUsersScreen.groupTitle,
      maxWidth: 1240,
      children: [
        const ScreenHeader(
          icon: AdminUsersScreen.menuIcon,
          title: 'ผู้ใช้',
          subtitle: 'ค้นหาและแก้ไขบัญชีผู้ใช้ของระบบฌาปนกิจ',
          bullets: [
            'ชื่อ เลขบัตร และเลขสมาชิกมาจาก ThaID/ข้อมูลบุคลากร/ทะเบียนสมาชิก แก้ที่นี่ไม่ได้',
          ],
        ),
        const SizedBox(height: 14),
        TextField(
          key: AdminUsersScreen.searchKey,
          controller: _search,
          onChanged: _onSearch,
          onSubmitted: (_) {
            _debounce?.cancel();
            _page = 0;
            _load();
          },
          style: screenText(),
          decoration: InputDecoration(
            hintText: 'ค้นหาชื่อผู้ใช้ ชื่อ-สกุล หรือเลขสมาชิก',
            hintStyle: screenText(color: AppTheme.textSecondary),
            prefixIcon: const Icon(Icons.search),
            isDense: true,
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        const SizedBox(height: 12),
        if (_error != null) ...[
          LoadState(error: _error, onRetry: _load),
          const SizedBox(height: 10),
        ],
        Stack(
          children: [
            SheetScroll(
              minWidth: 980,
              child: SheetCard(
                emptyText: _loading ? 'กำลังโหลด...' : 'ไม่พบผู้ใช้',
                header: const Row(
                  children: [
                    Expanded(
                      flex: 5,
                      child: SheetHead('ชื่อผู้ใช้ / ชื่อ-สกุล'),
                    ),
                    Expanded(flex: 3, child: SheetHead('สมาชิก / ประเภท')),
                    Expanded(flex: 4, child: SheetHead('บทบาท')),
                    Expanded(flex: 4, child: SheetHead('สถานะ')),
                    Expanded(flex: 3, child: SheetHead('เข้าสู่ระบบล่าสุด')),
                    Expanded(flex: 1, child: SizedBox.shrink()),
                  ],
                ),
                rows: [for (final u in users) _row(u)],
              ),
            ),
            if (_loading && users.isNotEmpty)
              const Positioned.fill(
                child: Center(child: CircularProgressIndicator()),
              ),
          ],
        ),
        const SizedBox(height: 10),
        AppPagination(
          currentPage: data?.currentPage ?? _page,
          totalPages: totalPages,
          pageSize: _pageSize,
          summary: 'ทั้งหมด ${countText(data?.totalItems ?? 0)} บัญชี',
          onPageChanged: (p) {
            _page = p;
            _load();
          },
          onPageSizeChanged: (s) {
            _pageSize = s;
            _page = 0;
            _load();
          },
        ),
      ],
    );
  }
}
