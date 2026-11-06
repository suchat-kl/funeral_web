import 'package:flutter/material.dart';

import '../../config/theme.dart';
import '../../models/deposit.dart';
import '../../services/api_service.dart';
import '../../utils/util.dart';
import '../../widgets/screen_parts.dart';
import '../../widgets/work_parts.dart';
import 'deposit_parts.dart';

/// ฝากเงินชำระล่วงหน้า › ค่าฌาปนกิจประจำเดือน (หน้า 4 ของแบบ 13.1) — อ่านอย่างเดียว
///
/// ค่ามาจากตาราง ffd_monthly_cost ของระบบฌาปนกิจหลักใน DPIS (ผู้ใช้สั่ง 6 พ.ย. 2569) ไม่บันทึกซ้ำในระบบนี้
/// ตอนประมวลผลหักเงิน ระบบดึงค่าของเดือนนั้นจาก DPIS และเก็บสำเนาไว้ เดือนที่ประมวลผลแล้วแสดงค่าตามสำเนา
class MonthlyCostScreen extends StatefulWidget {
  final ApiService apiService;

  const MonthlyCostScreen({super.key, required this.apiService});

  static const String menuTitle = 'ค่าฌาปนกิจประจำเดือน';
  static const IconData menuIcon = Icons.event_note;

  static const Key yearKey = ValueKey('cost-year');
  static Key rowKey(int period) => ValueKey('cost-row-$period');

  @override
  State<MonthlyCostScreen> createState() => _MonthlyCostScreenState();
}

class _MonthlyCostScreenState extends State<MonthlyCostScreen> {
  MonthlyCostYearData? _data;
  String? _error;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load([int? year]) async {
    setState(() {
      _error = null;
      _loading = true;
    });
    try {
      final d = await widget.apiService.depositMonthlyCosts(year: year);
      if (!mounted) return;
      setState(() {
        _data = d;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = _data;
    return WorkPage(
      group: depositGroup,
      maxWidth: 1240,
      children: [
        const ScreenHeader(
          icon: MonthlyCostScreen.menuIcon,
          title: MonthlyCostScreen.menuTitle,
          subtitle:
              'ช่วงศพและอัตราศพละของแต่ละเดือน จากระบบฌาปนกิจใน DPIS (ffd_monthly_cost) — ดูได้อย่างเดียว',
          bullets: [
            'แก้ไขค่าฌาปนกิจได้ที่ระบบฌาปนกิจหลักเท่านั้น หน้านี้อ่านค่ามาแสดง',
            'ประมวลผลหักเงินใช้ค่าของเดือนนั้นจาก DPIS และเก็บสำเนาไว้ เดือนที่ประมวลผลแล้วไม่เปลี่ยนตาม DPIS',
            'ถ้าข้อมูลใน DPIS ไม่สอดคล้องกัน (จำนวนศพ/ยอดรวม) ระบบไม่ให้ประมวลผลเดือนนั้น',
          ],
        ),
        const SizedBox(height: 14),
        if (_error != null) LoadState(error: _error, onRetry: _load),
        if (d == null && _error == null) const LoadState(loading: true),
        if (d != null) ...[
          Row(
            children: [
              SizedBox(
                width: 180,
                child: DropdownButtonFormField<int>(
                  key: MonthlyCostScreen.yearKey,
                  initialValue: d.year,
                  decoration: depositInput('ปี พ.ศ.'),
                  items: [
                    for (final y in d.years)
                      DropdownMenuItem(
                        value: y,
                        child: Text('$y', style: screenText(size: 14)),
                      ),
                  ],
                  onChanged: _loading
                      ? null
                      : (y) {
                          if (y != null && y != d.year) _load(y);
                        },
                ),
              ),
              const SizedBox(width: 12),
              if (_loading)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (d.dpisError != null) ...[
            NoticeBar(type: NoticeType.warning, text: d.dpisError!),
            const SizedBox(height: 10),
          ],
          PagedSheet<MonthlyCostItem>(
            minWidth: 1150,
            unit: 'เดือน',
            items: d.rows,
            initialPageSize: 15,
            emptyText: 'ไม่มีค่าฌาปนกิจของปี ${d.year} ใน DPIS',
            rowKey: (c) => MonthlyCostScreen.rowKey(c.period),
            columns: const [
              SheetColumn('เดือน ปี', flex: 3),
              SheetColumn('ศพที่', flex: 3),
              SheetColumn('จำนวนศพ', flex: 2, right: true),
              SheetColumn('ศพละ', flex: 2, right: true),
              SheetColumn('ยอดต่อคน', flex: 2, right: true),
              SheetColumn('วันที่ประกาศ', flex: 3),
              SheetColumn('สมาชิกทั้งหมด', flex: 2, right: true),
              SheetColumn('สถานะในระบบนี้', flex: 4),
            ],
            cells: (c, _) => [
              cellText(DepositPeriod.label(c.period), weight: FontWeight.w600),
              cellText(
                c.bodyBegin == null ? '-' : '${c.bodyBegin}-${c.bodyEnd ?? ''}',
              ),
              cellText(countText(c.bodyCount)),
              cellMoney(c.perBody),
              cellMoney(c.amount, bold: true),
              cellText(
                c.costDate == null ? '-' : Util.thaiDateOf(c.costDate),
                size: 13,
              ),
              cellText(
                c.totalMembers == null ? '-' : countText(c.totalMembers),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  c.processed
                      ? const StatusChip('ประมวลผลแล้ว', AppTheme.successColor)
                      : const StatusChip(
                          'ยังไม่ประมวลผล',
                          AppTheme.neutralColor,
                        ),
                  if (c.warning != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        c.warning!,
                        style: screenText(
                          size: 12.5,
                          color: AppTheme.dangerColor,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ],
      ],
    );
  }
}
