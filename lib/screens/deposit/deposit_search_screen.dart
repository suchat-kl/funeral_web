import 'dart:async';

import 'package:flutter/material.dart';

import '../../config/theme.dart';
import '../../models/deposit.dart';
import '../../services/api_service.dart';
import '../../utils/snackbar_helper.dart';
import '../../widgets/screen_parts.dart';
import '../../widgets/work_parts.dart';
import 'deposit_member_screen.dart';
import 'deposit_parts.dart';

/// ข้อมูลสมาชิก › ค้นหาสมาชิก (หน้า 1 ของแบบ 13.1) — เจ้าหน้าที่รับฝากเงินล่วงหน้า / ผู้ดูแล
///
/// ค้นด้วยเลขสมาชิก ชื่อ นามสกุล + แท็บ ทั้งหมด / ฝากล่วงหน้า / สมาชิกพิเศษ
/// แท็บฝากล่วงหน้ากรองสถานะบัญชีได้ (ปกติ / ระหว่างทวงถาม / พ้นสภาพ / ปิดบัญชี / นำออกจากสมาชิก)
/// คลิกแถวเปิดหน้ารายละเอียด; ไม่มีปุ่มเพิ่มสมาชิกเอง — เปิดบัญชีให้สมาชิกที่เลือกจากทะเบียน (Oracle)
class DepositSearchScreen extends StatefulWidget {
  final ApiService apiService;

  const DepositSearchScreen({super.key, required this.apiService});

  static const String menuTitle = 'ค้นหาสมาชิก';
  static const IconData menuIcon = Icons.person_search;

  static const Key searchKey = ValueKey('deposit-search');
  static const Key openAccountKey = ValueKey('deposit-open-account');
  static Key tabKey(DepositTab t) => ValueKey('deposit-tab-${t.name}');
  static Key rowKey(String memberNo) => ValueKey('deposit-row-$memberNo');

  @override
  State<DepositSearchScreen> createState() => _DepositSearchScreenState();
}

class _DepositSearchScreenState extends State<DepositSearchScreen> {
  final _search = TextEditingController();
  Timer? _debounce;
  DepositTab _tab = DepositTab.deposit;
  DepositState? _state;
  DepositSearchResult? _data;
  bool _loading = true;
  String? _error;
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
      final data = await widget.apiService.depositSearch(
        q: _search.text,
        tab: _tab,
        state: _tab == DepositTab.deposit ? _state : null,
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
    _debounce = Timer(const Duration(milliseconds: 400), _load);
  }

  Future<void> _open(String memberNo) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DepositMemberScreen(
          apiService: widget.apiService,
          memberNo: memberNo,
        ),
      ),
    );
    if (mounted) _load();
  }

  Future<void> _openAccount() async {
    final no = await showDialog<String>(
      context: context,
      builder: (_) => OpenAccountDialog(apiService: widget.apiService),
    );
    if (no != null && mounted) await _open(no);
  }

  static const _tabNames = {
    DepositTab.deposit: 'ฝากล่วงหน้า',
    DepositTab.special: 'สมาชิกพิเศษ',
    DepositTab.all: 'ทะเบียนทั้งหมด',
  };

  List<Widget> _chips(DepositMemberRow r) => [
    if (r.special) const StatusChip('พิเศษ', AppTheme.infoColor),
    if (r.dunning) const StatusChip('ทวงถาม', AppTheme.warningColor),
    if (r.closedPeriod != null)
      const StatusChip('ปิดบัญชี', AppTheme.neutralColor),
    if (r.hasAccount && r.accountStatus != null && r.accountStatus != 0)
      StatusChip(DepositStatus.nameOf(r.accountStatus), AppTheme.dangerColor),
    if (!r.registered) const StatusChip('ไม่มีทะเบียน', AppTheme.neutralColor),
  ];

  @override
  Widget build(BuildContext context) {
    final rows = _data?.rows ?? const <DepositMemberRow>[];
    return WorkPage(
      group: depositMemberGroup,
      maxWidth: 1240,
      children: [
        const ScreenHeader(
          icon: DepositSearchScreen.menuIcon,
          title: DepositSearchScreen.menuTitle,
          subtitle:
              'ค้นด้วยเลขสมาชิก ชื่อ หรือนามสกุล แล้วคลิกแถวเพื่อดูรายละเอียด',
          bullets: [
            'ชื่อ-สกุลใช้ตามทะเบียนสมาชิกฌาปนกิจ (Oracle) ไม่มีในทะเบียนจะแสดงชื่อจากระบบเดิม',
            'ไม่มีการเพิ่มสมาชิกเอง: กด "เปิดบัญชีฝากล่วงหน้า" แล้วเลือกสมาชิกจากทะเบียน',
          ],
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (final t in _tabNames.keys)
              ChoiceChip(
                key: DepositSearchScreen.tabKey(t),
                label: Text(_tabNames[t]!, style: screenText(size: 14)),
                selected: _tab == t,
                onSelected: (_) {
                  setState(() => _tab = t);
                  _load();
                },
              ),
            if (_tab == DepositTab.deposit)
              SizedBox(
                width: 230,
                child: DropdownButtonFormField<DepositState?>(
                  initialValue: _state,
                  isDense: true,
                  decoration: depositInput('สถานะบัญชี'),
                  items: [
                    DropdownMenuItem(
                      value: null,
                      child: Text('ทุกสถานะ', style: screenText(size: 14)),
                    ),
                    for (final s in DepositState.values)
                      DropdownMenuItem(
                        value: s,
                        child: Text(s.label, style: screenText(size: 14)),
                      ),
                  ],
                  onChanged: (v) {
                    setState(() => _state = v);
                    _load();
                  },
                ),
              ),
            FilledButton.icon(
              key: DepositSearchScreen.openAccountKey,
              onPressed: _openAccount,
              icon: const Icon(Icons.add_card, size: 18),
              label: Text(
                'เปิดบัญชีฝากล่วงหน้า',
                style: screenText(size: 14, color: Colors.white),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          key: DepositSearchScreen.searchKey,
          controller: _search,
          onChanged: _onSearch,
          onSubmitted: (_) {
            _debounce?.cancel();
            _load();
          },
          style: screenText(),
          decoration: depositInput(
            'ค้นหา',
            hint:
                'เลขสมาชิก หรือ ชื่อ นามสกุล (พิมพ์หลายคำคั่นด้วยช่องว่างได้)',
            prefix: const Icon(Icons.search),
          ),
        ),
        const SizedBox(height: 12),
        if (_error != null) ...[
          LoadState(error: _error, onRetry: _load),
          const SizedBox(height: 10),
        ],
        if (_data?.truncated == true) ...[
          Text(
            'แสดง ${rows.length} รายการแรก กรุณาพิมพ์คำค้นให้แคบลง',
            style: screenText(size: 13.5, color: AppTheme.warningColor),
          ),
          const SizedBox(height: 8),
        ],
        Stack(
          children: [
            PagedSheet<DepositMemberRow>(
              minWidth: 1100,
              unit: 'คน',
              emptyText: _loading ? 'กำลังโหลด...' : 'ไม่พบสมาชิกตรงคำค้น',
              columns: const [
                SheetColumn('ลำดับ', flex: 1),
                SheetColumn('เลขสมาชิก', flex: 2),
                SheetColumn('ชื่อ - สกุล', flex: 5),
                SheetColumn('สังกัด', flex: 4),
                SheetColumn('เงินฝาก', flex: 2, right: true),
                SheetColumn('หนี้ค้าง', flex: 2, right: true),
                SheetColumn('สถานะ', flex: 4),
              ],
              items: rows,
              rowKey: (r) => DepositSearchScreen.rowKey(r.memberNo),
              onTap: (r) => _open(r.memberNo),
              cells: (r, no) => [
                cellText('$no'),
                cellText(r.memberNo, weight: FontWeight.w600),
                cellText(r.fullName),
                cellText(r.divName ?? r.divCode, size: 13),
                cellMoney(r.balance),
                cellMoney(r.debt),
                Wrap(spacing: 4, runSpacing: 4, children: _chips(r)),
              ],
            ),
            if (_loading && rows.isNotEmpty)
              const Positioned.fill(
                child: Center(child: CircularProgressIndicator()),
              ),
          ],
        ),
      ],
    );
  }
}

/// เลือกสมาชิกจากทะเบียนสมาชิกฌาปนกิจ (Oracle) แล้วเปิดบัญชีฝากล่วงหน้า — คืนเลขสมาชิกที่เปิดแล้ว
class OpenAccountDialog extends StatefulWidget {
  final ApiService apiService;

  const OpenAccountDialog({super.key, required this.apiService});

  static const Key searchKey = ValueKey('open-account-search');
  static Key openKey(String no) => ValueKey('open-account-$no');

  @override
  State<OpenAccountDialog> createState() => _OpenAccountDialogState();
}

class _OpenAccountDialogState extends State<OpenAccountDialog> {
  final _q = TextEditingController();
  List<OracleMemberItem>? _rows;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  Future<void> _find() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final rows = await widget.apiService.depositOracleMembers(_q.text);
      if (mounted) setState(() => _rows = rows);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _openFor(OracleMemberItem m) async {
    setState(() => _busy = true);
    try {
      await widget.apiService.depositOpenAccount(m.memberNo);
      if (!mounted) return;
      context.showSuccessSnackBar(
        'เปิดบัญชีฝากล่วงหน้าเลขสมาชิก ${m.memberNo} แล้ว',
      );
      Navigator.of(context).pop(m.memberNo);
      return;
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        'เปิดบัญชีฝากล่วงหน้า',
        style: screenText(size: 18, weight: FontWeight.w700),
      ),
      content: SizedBox(
        width: 640,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'ค้นหาสมาชิกจากทะเบียนสมาชิกฌาปนกิจ แล้วกด "เปิดบัญชี" (ยอดเริ่มต้น 0 บาท)',
              style: screenText(size: 13.5, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 10),
            TextField(
              key: OpenAccountDialog.searchKey,
              controller: _q,
              onSubmitted: (_) => _find(),
              style: screenText(),
              decoration:
                  depositInput(
                    'เลขสมาชิก หรือ ชื่อ',
                    prefix: const Icon(Icons.search),
                  ).copyWith(
                    suffixIcon: IconButton(
                      onPressed: _busy ? null : _find,
                      icon: const Icon(Icons.arrow_forward),
                    ),
                  ),
            ),
            const SizedBox(height: 10),
            if (_error != null)
              NoticeBar(type: NoticeType.error, text: _error!),
            if (_busy) const LinearProgressIndicator(),
            if (_rows != null && _rows!.isEmpty)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text('ไม่พบสมาชิก', style: screenText(size: 14)),
              ),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 360),
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final m in _rows ?? const <OracleMemberItem>[])
                    ListTile(
                      dense: true,
                      title: Text(
                        '${m.memberNo}  ${m.fullName}',
                        style: screenText(size: 14.5),
                      ),
                      subtitle: Text(
                        [
                          m.orgName ?? '',
                          if (!m.active) 'พ้นสมาชิกแล้ว',
                        ].where((x) => x.isNotEmpty).join(' · '),
                        style: screenText(
                          size: 12.5,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      trailing: m.hasAccount
                          ? const StatusChip(
                              'มีบัญชีแล้ว',
                              AppTheme.neutralColor,
                            )
                          : FilledButton(
                              key: OpenAccountDialog.openKey(m.memberNo),
                              onPressed: _busy || !m.active
                                  ? null
                                  : () => _openFor(m),
                              child: Text(
                                'เปิดบัญชี',
                                style: screenText(
                                  size: 13.5,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('ปิด', style: screenText(size: 14)),
        ),
      ],
    );
  }
}
