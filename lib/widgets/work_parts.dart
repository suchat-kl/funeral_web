// ชิ้นส่วนร่วมของหน้าจอที่เปิดจากเมนู (ยกจากระบบหักหนี้): โครงหน้า แถวข้อมูล ตัวเลือกงวด และตัวช่วยดาวน์โหลดไฟล์
import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../services/api_service.dart';
import '../utils/file_download.dart';
import '../utils/util.dart';
import 'screen_parts.dart';

int intOf(Object? v) => v is num ? v.toInt() : int.tryParse('${v ?? ''}') ?? 0;

/// จำนวนนับมีจุลภาค (null = "-")
String countText(Object? v) => v == null ? '-' : Util.formatCount(intOf(v));

/// จำนวนเงินมีจุลภาค ทศนิยม 2 ตำแหน่ง (null / อ่านไม่ได้ = "-")
/// backend ส่งเงินเป็นข้อความหรือตัวเลข — ไม่แปลงผ่าน double เพื่อไม่ให้เพี้ยน
String moneyText(Object? v) {
  if (v == null) return '-';
  final raw = '$v'.trim().replaceAll(',', '');
  final m = RegExp(r'^(-?)(\d+)(?:\.(\d+))?$').firstMatch(raw);
  if (m == null) return raw.isEmpty ? '-' : raw;
  final whole = Util.formatCount(int.parse(m.group(2)!));
  var frac = (m.group(3) ?? '').padRight(2, '0');
  if (frac.length > 2) {
    // ปัดทศนิยมตำแหน่งที่ 3 ขึ้นไปแบบง่าย (backend ส่งมาสองตำแหน่งอยู่แล้ว)
    frac = frac.substring(0, 2);
  }
  return '${m.group(1)}$whole.$frac';
}

/// โครงหน้าของหน้าจอที่เปิดจากเมนู: แถบบนชื่อกลุ่มเมนู + เนื้อหากว้างไม่เกิน [maxWidth]
class WorkPage extends StatelessWidget {
  final String group;
  final double maxWidth;
  final List<Widget> children;

  const WorkPage({
    super.key,
    required this.group,
    required this.children,
    this.maxWidth = 980,
  });

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 1024;
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: screenAppBar(context, group),
      body: ListView(
        padding: EdgeInsets.all(isDesktop ? 24 : 12),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: children,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// แถว "ป้าย ........ ค่า" ของการ์ดสรุป
class FactRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;

  const FactRow(this.label, this.value, {super.key, this.color});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 5,
          child: Text(label, style: screenText(color: AppTheme.textSecondary)),
        ),
        Expanded(
          flex: 4,
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: screenText(
              weight: FontWeight.w600,
              color: color ?? AppTheme.textPrimary,
            ),
          ),
        ),
      ],
    ),
  );
}

/// ตัวเลือกงวด (ปี พ.ศ. + เดือน) — เลือกเกินเดือนปัจจุบันไม่ได้
///
/// ผู้เรียกเก็บค่าเอง ([year] พ.ศ., [month] 1-12) แจ้งค่าใหม่ทาง [onChanged]
class MonthYearPicker extends StatelessWidget {
  final int year;
  final int month;
  final void Function(int year, int month) onChanged;
  final bool enabled;

  /// วันนี้ (เทสต์ส่งวันตายตัว) ไม่ส่ง = วันที่จริง
  final DateTime? today;

  /// ปีแรกสุดที่ย้อนดูได้ (พ.ศ.)
  final int minYear;

  const MonthYearPicker({
    super.key,
    required this.year,
    required this.month,
    required this.onChanged,
    this.enabled = true,
    this.today,
    this.minYear = 2550,
  });

  static const Key labelKey = ValueKey('period-label');

  @override
  Widget build(BuildContext context) {
    final now = today ?? DateTime.now();
    final cy = now.year + 543;
    final cm = now.month;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'งวด ${Util.thaiMonthName(month)} $year',
                key: labelKey,
                style: screenText(size: 15, weight: FontWeight.w700),
              ),
              YearStepper(
                year: year,
                min: minYear < cy ? minYear : cy,
                max: cy,
                enabled: enabled,
                onChanged: (y) => onChanged(y, y == cy && month > cm ? cm : month),
              ),
            ],
          ),
          const SizedBox(height: 10),
          MonthPicker(
            selected: month,
            enabled: enabled,
            onSelected: (m) {
              if (year == cy && m > cm) return;
              onChanged(year, m);
            },
          ),
        ],
      ),
    );
  }
}

/// ตัวช่วยดาวน์โหลดไฟล์ของหน้าจอ: กันกดซ้ำ ส่งไฟล์ให้เบราว์เซอร์ผ่าน [FileSaver] และเก็บตัวจับไว้ให้ "เปิดดู"
///
/// ไฟล์อาจมีข้อมูลบุคคล — อยู่ในหน่วยความจำของแท็บจนปิดหน้าจอ ([dispose] คืนหน่วยความจำ) ไม่เก็บลง storage
mixin FileDownloads<T extends StatefulWidget> on State<T> {
  final Map<String, SavedFile> _saved = {};

  /// คีย์ของไฟล์ที่กำลังสร้าง/ดาวน์โหลด (null = ว่าง) ระหว่างนี้ปุ่มดาวน์โหลดทุกปุ่มกดไม่ได้
  String? downloading;

  /// ข้อความผิดพลาดของการดาวน์โหลดล่าสุด
  String? downloadError;

  SavedFile? savedOf(String key) => _saved[key];

  /// ทิ้งไฟล์ที่ดาวน์โหลดไว้ทั้งหมด (เช่น เปลี่ยนตัวเลือกแล้วไฟล์เดิมไม่ตรง)
  void clearSaved() {
    for (final f in _saved.values) {
      f.dispose();
    }
    _saved.clear();
  }

  /// ดาวน์โหลดไฟล์ของ [key] — คืนจริงเมื่อสำเร็จ
  /// [onError] คืนจริง = ผู้เรียกจัดการข้อผิดพลาดเองแล้ว (ไม่ตั้ง [downloadError])
  Future<bool> runDownload(
    String key,
    Future<DownloadedFile> Function() fetch, {
    bool Function(ApiException e)? onError,
  }) async {
    if (downloading != null) return false;
    setState(() {
      downloading = key;
      downloadError = null;
    });
    try {
      final file = await fetch();
      if (!mounted) return false;
      _saved.remove(key)?.dispose();
      final saved = FileSaver.instance.save(file);
      setState(() {
        _saved[key] = saved;
        downloading = null;
      });
      return true;
    } on ApiException catch (e) {
      if (!mounted) return false;
      final handled = onError?.call(e) ?? false;
      setState(() {
        downloading = null;
        if (!handled) downloadError = e.message;
      });
    } catch (e) {
      if (!mounted) return false;
      setState(() {
        downloading = null;
        downloadError = e.toString();
      });
    }
    return false;
  }

  @override
  void dispose() {
    clearSaved();
    super.dispose();
  }
}

/// ปุ่มดาวน์โหลดของ [FileDownloads]: ระหว่างสร้างไฟล์แสดงวงหมุน เสร็จแล้วมีปุ่ม "เปิดดู" (ไฟล์ที่เปิดในเบราว์เซอร์ได้)
class DownloadButtons extends StatelessWidget {
  final String label;
  final IconData icon;

  /// กำลังสร้างไฟล์นี้อยู่
  final bool busy;

  /// มีไฟล์อื่นกำลังสร้างอยู่ (กดไม่ได้)
  final bool blocked;
  final VoidCallback onDownload;

  /// ไฟล์ที่ดาวน์โหลดแล้ว (มี = แสดงปุ่มเปิดดูเมื่อ [canOpen])
  final SavedFile? saved;
  final bool canOpen;
  final Color? color;

  const DownloadButtons({
    super.key,
    required this.label,
    required this.onDownload,
    this.icon = Icons.download,
    this.busy = false,
    this.blocked = false,
    this.saved,
    this.canOpen = false,
    this.color,
  });

  static const String openLabel = 'เปิดดู';
  static const String busyLabel = 'กำลังสร้างไฟล์...';

  @override
  Widget build(BuildContext context) {
    final bg = color ?? AppTheme.primaryColor;
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        ElevatedButton.icon(
          onPressed: busy || blocked ? null : onDownload,
          style: ElevatedButton.styleFrom(
            backgroundColor: bg,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            minimumSize: const Size(0, 38),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          icon: busy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(icon, size: 18),
          label: Text(
            busy ? busyLabel : label,
            style: screenText(size: 14, color: Colors.white),
          ),
        ),
        if (saved != null && canOpen)
          OutlinedButton.icon(
            onPressed: saved!.open,
            icon: const Icon(Icons.open_in_new, size: 16),
            label: Text(openLabel, style: screenText(size: 14)),
          ),
        if (saved != null)
          Text(
            'ดาวน์โหลดแล้ว: ${saved!.fileName}',
            style: screenText(size: 12.5, color: AppTheme.successColor),
          ),
      ],
    );
  }
}

/// แถบข้อความว่าง/กำลังโหลด/ผิดพลาด ของรายการที่โหลดจาก backend (ใช้ซ้ำหลายหน้าจอ)
class LoadState extends StatelessWidget {
  final bool loading;
  final String? error;
  final VoidCallback? onRetry;

  const LoadState({super.key, this.loading = false, this.error, this.onRetry});

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (error == null) return const SizedBox.shrink();
    return NoticeBar(
      type: NoticeType.error,
      text: error!,
      action: onRetry == null
          ? null
          : TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 18),
              label: Text('ลองใหม่', style: screenText(size: 14)),
            ),
    );
  }
}
