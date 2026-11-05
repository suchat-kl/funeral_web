import 'dart:async';

import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../models/control_user.dart';
import '../services/api_service.dart';
import '../utils/dialog.dart';
import '../utils/roles.dart';
import '../utils/snackbar_helper.dart';
import '../utils/util.dart';
import '../widgets/app_pagination.dart';
import '../widgets/screen_parts.dart';
import '../widgets/sheet_table.dart';
import '../widgets/work_parts.dart';

/// นำไฟล์เข้า › เพิ่มผู้ใช้งานทะเบียนคุม (ผู้ดูแล ผู้นำไฟล์เข้า) — ผู้ใช้สั่ง 5-6 พ.ย. 2569
///
/// แสดงทุกบัญชีที่ยังใช้เมนูทะเบียนคุมไม่ได้ (ไม่ใช่สมาชิก ไม่ใช่ผู้นำไฟล์เข้า/ผู้ดูแล ไม่มีบทบาท MONTHYEAR)
/// เรียงวันลงทะเบียนล่าสุดก่อน ค้นชื่อ นามสกุล เลขบัตร บางส่วนได้ แล้วให้สิทธิ์ทีละราย:
/// ประเภท U → เปลี่ยนเป็น N และให้บทบาทผู้ใช้ทะเบียนคุม; ประเภทอื่น (G/E/C/N) → ให้บทบาทอย่างเดียว
/// มีเลขบัตรและชื่อ: อยู่ในหน่วยความจำของหน้าจอเท่านั้น เลขบัตรแสดงแบบปิดบางส่วน
class ControlUsersScreen extends StatefulWidget {
  final ApiService apiService;

  const ControlUsersScreen({super.key, required this.apiService});

  static const String menuTitle = 'เพิ่มผู้ใช้งานทะเบียนคุม';
  static const IconData menuIcon = Icons.person_add_alt_1;
  static const String groupTitle = 'นำไฟล์เข้า';

  static const Key searchKey = ValueKey('control-users-search');
  static Key grantKey(String id) => ValueKey('control-user-grant-$id');
  static Key rowKey(String id) => ValueKey('control-user-row-$id');

  @override
  State<ControlUsersScreen> createState() => _ControlUsersScreenState();
}

class _ControlUsersScreenState extends State<ControlUsersScreen> {
  final _search = TextEditingController();
  Timer? _debounce;
  ControlUserList? _data;
  int _page = 0;
  int _pageSize = 10;
  bool _loading = true;
  String? _error;
  String? _busyId;
  int _serial = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final serial = ++_serial;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await widget.apiService.getControlUsers(
        keyword: _search.text,
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

  String _nameOf(ControlUser u) =>
      u.fullName.isEmpty ? u.username : '${u.fullName} (${u.username})';

  static bool _unknown(ControlUser u) => u.personType == PersonType.unknown;

  /// ข้อความปุ่ม: ประเภท U ต้องเปลี่ยนประเภทด้วย
  static String _grantLabel(ControlUser u) =>
      _unknown(u) ? 'เปลี่ยนเป็น N + ให้สิทธิ์' : 'ให้สิทธิ์ทะเบียนคุม';

  Future<void> _grant(ControlUser u) async {
    final ok = await AppDialog.showConfirm(
      context,
      _unknown(u)
          ? 'เปลี่ยน "${_nameOf(u)}" เป็น${PersonType.nameOf(PersonType.nonBudget)} '
                'และให้สิทธิ์ใช้เมนูทะเบียนคุม?\n'
                'มีผลตั้งแต่ผู้นั้นเข้าสู่ระบบครั้งถัดไป'
          : 'ให้สิทธิ์ใช้เมนูทะเบียนคุมแก่ "${_nameOf(u)}"?\n'
                'ประเภทบุคลากรคงเดิม มีผลตั้งแต่ผู้นั้นเข้าสู่ระบบครั้งถัดไป',
      confirmText: _grantLabel(u),
    );
    if (ok != true || !mounted) return;
    setState(() => _busyId = u.id);
    try {
      await widget.apiService.grantControlUser(u.id);
      if (!mounted) return;
      context.showSuccessSnackBar(
        _unknown(u)
            ? 'เปลี่ยน ${u.username} เป็น${PersonType.nameOf(PersonType.nonBudget)} และให้สิทธิ์ทะเบียนคุมเรียบร้อย'
            : 'ให้สิทธิ์ทะเบียนคุมแก่ ${u.username} เรียบร้อย',
      );
    } catch (e) {
      if (mounted) context.showErrorSnackBar(e.toString());
    }
    if (!mounted) return;
    setState(() => _busyId = null);
    await _load();
  }

  Widget _cell(Widget child, int flex) => Expanded(
    flex: flex,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      child: child,
    ),
  );

  Widget _row(int no, ControlUser u) {
    final busy = _busyId == u.id;
    return Row(
      key: ControlUsersScreen.rowKey(u.id),
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _cell(Text('$no', style: screenText(size: 14)), 1),
        _cell(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                u.fullName.isEmpty ? '-' : u.fullName,
                style: screenText(size: 14.5, weight: FontWeight.w600),
              ),
              Text(
                u.username,
                style: screenText(size: 13, color: AppTheme.textSecondary),
              ),
            ],
          ),
          5,
        ),
        _cell(
          Text(Util.maskIdcard(u.idcard), style: screenText(size: 13.5)),
          3,
        ),
        _cell(
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              StatusChip(
                '${u.personType ?? '-'} ${PersonType.nameOf(u.personType)}',
                _unknown(u) ? AppTheme.warningColor : AppTheme.infoColor,
              ),
              if (!u.active) const StatusChip('ระงับ', AppTheme.dangerColor),
            ],
          ),
          4,
        ),
        _cell(
          Text(Util.thaiDateTimeOf(u.createdAt), style: screenText(size: 13)),
          3,
        ),
        _cell(
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              key: ControlUsersScreen.grantKey(u.id),
              onPressed: busy || _busyId != null ? null : () => _grant(u),
              icon: busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.how_to_reg, size: 18),
              label: Text(
                _grantLabel(u),
                style: screenText(size: 13.5, color: Colors.white),
              ),
            ),
          ),
          3,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final users = _data?.users ?? const <ControlUser>[];
    final pages = (users.length / _pageSize).ceil();
    final page = pages == 0 ? 0 : (_page >= pages ? pages - 1 : _page);
    final start = page * _pageSize;
    final rows = users.skip(start).take(_pageSize).toList();
    return WorkPage(
      group: ControlUsersScreen.groupTitle,
      maxWidth: 1240,
      children: [
        const ScreenHeader(
          icon: ControlUsersScreen.menuIcon,
          title: ControlUsersScreen.menuTitle,
          subtitle:
              'ผู้ใช้ที่ยังใช้เมนูทะเบียนคุมไม่ได้ (ไม่ใช่สมาชิกฌาปนกิจ) เรียงตามวันลงทะเบียนล่าสุด',
          bullets: [
            'ประเภท U (ไม่พบในข้อมูลบุคลากร): ตรวจว่าเป็นลูกจ้างประจำ เงินนอกงบประมาณ แล้วกด "เปลี่ยนเป็น N + ให้สิทธิ์"',
            'ประเภท G E C N: กด "ให้สิทธิ์ทะเบียนคุม" ประเภทบุคลากรคงเดิม',
            'มีผลตั้งแต่ผู้นั้นเข้าสู่ระบบครั้งถัดไป ถอนสิทธิ์ได้ที่ ผู้ดูแล › ผู้ใช้ (บทบาทผู้ใช้ทะเบียนคุม)',
          ],
        ),
        const SizedBox(height: 14),
        TextField(
          key: ControlUsersScreen.searchKey,
          controller: _search,
          onChanged: _onSearch,
          onSubmitted: (_) {
            _debounce?.cancel();
            _page = 0;
            _load();
          },
          style: screenText(),
          decoration: InputDecoration(
            hintText: 'ค้นหาชื่อ นามสกุล หรือเลขบัตรประชาชน (พิมพ์บางส่วนได้)',
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
        if (_data?.limited == true) ...[
          Text(
            'แสดง ${users.length} รายการแรก กรุณาพิมพ์คำค้นให้แคบลง',
            style: screenText(size: 13.5, color: AppTheme.warningColor),
          ),
          const SizedBox(height: 8),
        ],
        Stack(
          children: [
            SheetScroll(
              minWidth: 980,
              child: SheetCard(
                emptyText: _loading
                    ? 'กำลังโหลด...'
                    : 'ไม่มีผู้ใช้ที่ยังไม่มีสิทธิ์ทะเบียนคุมตรงคำค้น',
                header: const Row(
                  children: [
                    Expanded(flex: 1, child: SheetHead('ลำดับ')),
                    Expanded(
                      flex: 5,
                      child: SheetHead('ชื่อ-สกุล / ชื่อผู้ใช้'),
                    ),
                    Expanded(flex: 3, child: SheetHead('เลขบัตรประชาชน')),
                    Expanded(flex: 4, child: SheetHead('ประเภทบุคลากร')),
                    Expanded(flex: 3, child: SheetHead('วันที่ลงทะเบียน')),
                    Expanded(flex: 3, child: SizedBox.shrink()),
                  ],
                ),
                rows: [
                  for (final (i, u) in rows.indexed) _row(start + i + 1, u),
                ],
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
          currentPage: page,
          totalPages: pages < 1 ? 1 : pages,
          pageSize: _pageSize,
          summary: 'ทั้งหมด ${countText(users.length)} บัญชี',
          onPageChanged: (p) => setState(() => _page = p),
          onPageSizeChanged: (s) => setState(() {
            _pageSize = s;
            _page = 0;
          }),
        ),
      ],
    );
  }
}
