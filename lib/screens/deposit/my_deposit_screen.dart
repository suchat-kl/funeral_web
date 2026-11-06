import 'package:flutter/material.dart';

import '../../config/theme.dart';
import '../../models/deposit.dart';
import '../../services/api_service.dart';
import '../../utils/util.dart';
import '../../widgets/screen_parts.dart';
import '../../widgets/work_parts.dart';
import 'deposit_parts.dart';

/// ข้อมูลสมาชิก › บัญชีฝากล่วงหน้าของฉัน (หน้า 2 ของแบบ 13.1 แบบอ่านอย่างเดียว สำหรับสมาชิก)
///
/// ข้อมูลทั้งหมดเป็นของเลขสมาชิกในบัญชีที่เข้าสู่ระบบ — backend เลือกเลขเอง หน้าเว็บไม่ส่งเลขสมาชิก
/// ไม่มีปุ่มแก้ไขใด ๆ ฝาก/คืนเงินติดต่อเจ้าหน้าที่
class MyDepositScreen extends StatefulWidget {
  final ApiService apiService;

  const MyDepositScreen({super.key, required this.apiService});

  static const String menuTitle = 'บัญชีฝากล่วงหน้าของฉัน';
  static const IconData menuIcon = Icons.savings_outlined;

  static const List<String> tabs = [
    'ประวัติชำระ',
    'ประวัติค้างชำระ',
    'ประวัติฝาก',
    'ทะเบียนรายตัว',
    'รายงานประจำเดือน',
  ];

  static Key tabKey(int i) => ValueKey('my-deposit-tab-$i');

  @override
  State<MyDepositScreen> createState() => _MyDepositScreenState();
}

class _MyDepositScreenState extends State<MyDepositScreen> {
  MyDepositSummary? _summary;
  String? _error;
  String? _tabError;
  int _tab = 0;
  List<DepositMonthItem>? _payments;
  List<DepositMonthItem>? _debts;
  List<DepositReceiptItem>? _receipts;
  List<LedgerItem>? _ledger;
  List<MonthlyReportItem>? _monthly;

  ApiService get _api => widget.apiService;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final s = await _api.depositMySummary();
      if (!mounted) return;
      setState(() => _summary = s);
      if (s.hasAccount) await _loadTab(_tab);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _loadTab(int i) async {
    setState(() {
      _tab = i;
      _tabError = null;
    });
    try {
      switch (i) {
        case 0:
          _payments ??= await _api.depositMyPayments();
        case 1:
          _debts ??= await _api.depositMyDebts();
        case 2:
          _receipts ??= await _api.depositMyReceipts();
        case 3:
          _ledger ??= await _api.depositMyLedger();
        default:
          _monthly ??= await _api.depositMyMonthly();
      }
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) setState(() => _tabError = e.toString());
    }
  }

  static String _dateOf(String? iso, String? legacy) =>
      iso == null ? (legacy ?? '-') : Util.thaiDateOf(iso);

  Widget _monthTab(List<DepositMonthItem>? items, {required bool debt}) {
    if (items == null) return const LoadState(loading: true);
    return PagedSheet<DepositMonthItem>(
      minWidth: 720,
      unit: 'เดือน',
      items: items,
      columns: [
        const SheetColumn('ลำดับ', flex: 1),
        const SheetColumn('เดือน', flex: 3),
        const SheetColumn('ศพที่', flex: 3),
        const SheetColumn('จำนวนเงิน', flex: 2, right: true),
        SheetColumn(debt ? 'สถานะ' : 'หมายเหตุ', flex: 3),
      ],
      cells: (m, no) => [
        cellText('$no'),
        cellText(DepositPeriod.label(m.period)),
        cellText(m.bodies),
        cellMoney(m.amount),
        debt
            ? StatusChip(
                m.cleared ? 'ชำระแล้ว' : 'ค้างชำระ',
                m.cleared ? AppTheme.successColor : AppTheme.dangerColor,
              )
            : cellText(
                m.reversedPeriod != null
                    ? 'คืนเงิน (เก็บซ้ำ) ${DepositPeriod.label(m.reversedPeriod)}'
                    : m.paidPeriod != null && m.paidPeriod != m.period
                    ? 'ชำระเมื่อ ${DepositPeriod.label(m.paidPeriod)}'
                    : '-',
                size: 13,
              ),
      ],
    );
  }

  Widget _receiptTab() {
    final items = _receipts;
    if (items == null) return const LoadState(loading: true);
    return PagedSheet<DepositReceiptItem>(
      minWidth: 600,
      items: items,
      columns: const [
        SheetColumn('ลำดับ', flex: 1),
        SheetColumn('วันที่', flex: 3),
        SheetColumn('เลขที่เอกสาร', flex: 3),
        SheetColumn('จำนวนเงิน', flex: 2, right: true),
      ],
      cells: (r, no) => [
        cellText('$no'),
        cellText(_dateOf(r.date, r.legacyDate)),
        cellText(r.docNo),
        cellMoney(r.amount),
      ],
    );
  }

  Widget _ledgerTab() {
    final items = _ledger;
    if (items == null) return const LoadState(loading: true);
    return PagedSheet<LedgerItem>(
      minWidth: 1000,
      items: items,
      initialPageSize: 20,
      columns: const [
        SheetColumn('ลำดับ', flex: 1),
        SheetColumn('วันที่', flex: 3),
        SheetColumn('รายการ', flex: 5),
        SheetColumn('เลขที่เอกสาร', flex: 2),
        SheetColumn('รับ', flex: 2, right: true),
        SheetColumn('จ่ายศพที่', flex: 3),
        SheetColumn('จ่าย', flex: 2, right: true),
        SheetColumn('คงเหลือ', flex: 2, right: true),
      ],
      cells: (l, no) => [
        cellText('$no'),
        cellText(_dateOf(l.date, l.legacyDate), size: 13),
        cellText(l.text, size: 13),
        cellText(l.docNo, size: 13),
        cellMoney(l.received),
        cellText(l.bodyPay, size: 13),
        cellMoney(l.paid),
        cellMoney(l.balance),
      ],
    );
  }

  Widget _monthlyTab() {
    final items = _monthly;
    if (items == null) return const LoadState(loading: true);
    return PagedSheet<MonthlyReportItem>(
      minWidth: 1000,
      unit: 'เดือน',
      items: items,
      columns: const [
        SheetColumn('เดือน', flex: 3),
        SheetColumn('ยอดยกมา', flex: 2, right: true),
        SheetColumn('รับ', flex: 2, right: true),
        SheetColumn('จ่ายศพที่', flex: 3),
        SheetColumn('สถานะ', flex: 2),
        SheetColumn('ค้างศพที่', flex: 3),
        SheetColumn('จ่าย', flex: 2, right: true),
        SheetColumn('คงเหลือ', flex: 2, right: true),
      ],
      cells: (r, no) => [
        cellText(DepositPeriod.label(r.period)),
        cellMoney(r.carried),
        cellMoney(r.received),
        cellText(r.bodyPay, size: 13),
        cellText(r.status, size: 13),
        cellText(r.bodyDebt, size: 13),
        cellMoney(r.paid),
        cellMoney(r.balance),
      ],
    );
  }

  Widget _tabBody() {
    if (_tabError != null) {
      return LoadState(error: _tabError, onRetry: () => _loadTab(_tab));
    }
    return switch (_tab) {
      0 => _monthTab(_payments, debt: false),
      1 => _monthTab(_debts, debt: true),
      2 => _receiptTab(),
      3 => _ledgerTab(),
      _ => _monthlyTab(),
    };
  }

  @override
  Widget build(BuildContext context) {
    final s = _summary;
    return WorkPage(
      group: depositMemberGroup,
      maxWidth: 1240,
      children: [
        const ScreenHeader(
          icon: MyDepositScreen.menuIcon,
          title: MyDepositScreen.menuTitle,
          subtitle:
              'ยอดเงินฝากฌาปนกิจล่วงหน้าและประวัติของบัญชีคุณ (ดูได้อย่างเดียว)',
          bullets: [
            'ยอดคงเหลือเป็นยอด ณ หลังประมวลผลหักเงินเดือนล่าสุด รวมเงินที่ฝากหลังจากนั้น',
            'ฝากเงินเพิ่มหรือขอคืนเงิน ติดต่อเจ้าหน้าที่รับฝากเงินล่วงหน้า',
          ],
        ),
        const SizedBox(height: 14),
        if (_error != null) LoadState(error: _error, onRetry: _load),
        if (s == null && _error == null) const LoadState(loading: true),
        if (s != null && !s.hasAccount)
          const NoticeBar(
            type: NoticeType.info,
            text: 'บัญชีของคุณยังไม่มีบัญชีฝากเงินฌาปนกิจล่วงหน้า',
          ),
        if (s != null && s.hasAccount) ...[
          MyDepositCard(summary: s),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < MyDepositScreen.tabs.length; i++)
                ChoiceChip(
                  key: MyDepositScreen.tabKey(i),
                  label: Text(
                    MyDepositScreen.tabs[i],
                    style: screenText(size: 14),
                  ),
                  selected: _tab == i,
                  onSelected: (_) => _loadTab(i),
                ),
            ],
          ),
          const SizedBox(height: 14),
          _tabBody(),
        ],
      ],
    );
  }
}

/// การ์ด "ยอดเงินฝากล่วงหน้า" (ใช้ทั้งหน้าแรกและหน้าบัญชีของฉัน)
class MyDepositCard extends StatelessWidget {
  final MyDepositSummary summary;
  final String? hint;

  const MyDepositCard({super.key, required this.summary, this.hint});

  static const Key cardKey = ValueKey('my-deposit-card');

  @override
  Widget build(BuildContext context) {
    final s = summary;
    final owing = (double.tryParse(s.debt ?? '') ?? 0) > 0;
    return Card(
      key: cardKey,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppTheme.dividerColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(MyDepositScreen.menuIcon, color: AppTheme.primaryColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'ยอดเงินฝากล่วงหน้า',
                    style: screenText(size: 17, weight: FontWeight.w700),
                  ),
                ),
                if (s.memberNo != null)
                  Text(
                    'เลขสมาชิก ${s.memberNo}',
                    style: screenText(
                      size: 13.5,
                      color: AppTheme.textSecondary,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                TotalChip(
                  'คงเหลือ',
                  '${moneyText(s.balance)} บาท',
                  color: AppTheme.successColor,
                ),
                TotalChip(
                  'ค้างชำระ',
                  owing
                      ? '${moneyText(s.debt)} บาท (${countText(s.openDebts)} เดือน)'
                      : 'ไม่มี',
                  color: owing ? AppTheme.dangerColor : null,
                ),
                TotalChip('สภาพบัญชี', s.statusName ?? '-'),
                if (s.special)
                  TotalChip(
                    'สมาชิกพิเศษ',
                    '${moneyText(s.specialAmount)} บาท/เดือน',
                  ),
              ],
            ),
            if (s.closed) ...[
              const SizedBox(height: 10),
              NoticeBar(
                type: NoticeType.info,
                text:
                    'บัญชีปิดแล้วเมื่อ ${DepositPeriod.label(s.closedPeriod)} (จ่ายคืนเงินคงเหลือแล้ว)',
              ),
            ] else if (s.dunning) ...[
              const SizedBox(height: 10),
              const NoticeBar(
                type: NoticeType.warning,
                text:
                    'บัญชีอยู่ระหว่างทวงถามหนี้ กรุณาติดต่อเจ้าหน้าที่รับฝากเงินล่วงหน้าเพื่อชำระหนี้ค้าง',
              ),
            ],
            const SizedBox(height: 8),
            Text(
              s.lastProcessed == null
                  ? 'ยังไม่มีการประมวลผลหักเงินในระบบนี้'
                  : 'ประมวลผลหักเงินล่าสุด: ${DepositPeriod.label(s.lastProcessed)}',
              style: screenText(size: 13, color: AppTheme.textSecondary),
            ),
            if (hint != null) ...[
              const SizedBox(height: 4),
              Text(
                hint!,
                style: screenText(size: 13, color: AppTheme.textSecondary),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
