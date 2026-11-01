import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/theme.dart';
import '../models/signature.dart';
import '../services/api_service.dart';
import '../utils/dialog.dart';
import '../utils/file_pick.dart';
import '../utils/snackbar_helper.dart';
import '../utils/util.dart';
import '../widgets/screen_parts.dart';
import '../widgets/work_parts.dart';

/// ผู้ดูแล › ลายเซ็นใบเสร็จ — รูปลายเซ็น + ชื่อ + ตำแหน่ง (หลายบรรทัด) ของผู้รับเงิน / ผอ.กองการเงินฯ-เหรัญญิก
///
/// แต่ละรายการมีผลกับใบเสร็จตั้งแต่เดือนที่กำหนดจนกว่าจะมีรายการใหม่ของชนิดเดียวกัน
/// รูป JPEG/PNG ไม่เกิน 2 MB
class AdminSignaturesScreen extends StatefulWidget {
  final ApiService apiService;

  /// ตัวเลือกรูป (เทสต์ส่งตัวปลอม)
  final FilePicker? picker;
  final DateTime? today;

  const AdminSignaturesScreen({
    super.key,
    required this.apiService,
    this.picker,
    this.today,
  });

  static const String menuTitle = 'ลายเซ็นใบเสร็จ';
  static const IconData menuIcon = Icons.draw_outlined;
  static const String groupTitle = 'ผู้ดูแล';

  /// ขนาดรูปสูงสุด
  static const int maxImageBytes = 2 * 1024 * 1024;

  static const Key nameKey = ValueKey('sign-name');
  static const Key positionKey = ValueKey('sign-position');
  static const Key pickKey = ValueKey('sign-pick');
  static const Key saveKey = ValueKey('sign-save');
  static Key kindKey(String kind) => ValueKey('sign-kind-$kind');
  static Key deleteKey(String id) => ValueKey('sign-delete-$id');

  @override
  State<AdminSignaturesScreen> createState() => _AdminSignaturesScreenState();
}

class _AdminSignaturesScreenState extends State<AdminSignaturesScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _position = TextEditingController();
  late final DateTime _today = widget.today ?? DateTime.now();
  late int _year = _today.year + 543;
  late int _month = _today.month;
  String _kind = SignatureItem.kindReceiver;
  PickedFile? _image;
  String? _imageError;
  bool _saving = false;
  String? _saveError;

  List<SignatureItem> _list = [];
  bool _loading = true;
  String? _error;
  final Map<String, Future<Uint8List>> _images = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _name.dispose();
    _position.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await widget.apiService.getSignatures();
      if (!mounted) return;
      setState(() {
        _list = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _pick() async {
    final picked = await (widget.picker ?? pickImageFile)();
    if (picked == null || !mounted) return;
    final lower = picked.name.toLowerCase();
    setState(() {
      if (!(lower.endsWith('.png') ||
          lower.endsWith('.jpg') ||
          lower.endsWith('.jpeg'))) {
        _image = null;
        _imageError = 'รับเฉพาะรูป JPEG หรือ PNG';
      } else if (picked.size > AdminSignaturesScreen.maxImageBytes) {
        _image = null;
        _imageError = 'รูปใหญ่เกิน 2 MB (${Util.formatFileSize(picked.size)})';
      } else {
        _image = picked;
        _imageError = null;
      }
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    final image = _image;
    final ok = _formKey.currentState!.validate();
    if (image == null) {
      setState(() => _imageError ??= 'กรุณาเลือกรูปลายเซ็น');
      return;
    }
    if (!ok) return;
    setState(() {
      _saving = true;
      _saveError = null;
    });
    try {
      await widget.apiService.saveSignature(
        kind: _kind,
        name: _name.text,
        positionLines: _position.text.split('\n'),
        effectiveFrom: Util.yearMonth(_year, _month),
        bytes: image.bytes,
        fileName: image.name,
      );
      if (!mounted) return;
      setState(() {
        _saving = false;
        _image = null;
      });
      context.showSuccessSnackBar('บันทึกลายเซ็นเรียบร้อย');
      await _load();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _saveError = e.toString();
      });
    }
  }

  Future<void> _delete(SignatureItem s) async {
    final ok = await AppDialog.showConfirm(
      context,
      'ลบลายเซ็น${s.kindName} "${s.name}" ที่มีผลตั้งแต่ ${s.effectiveText}?',
      confirmText: 'ลบ',
    );
    if (ok != true || !mounted) return;
    try {
      final message = await widget.apiService.deleteSignature(s.id);
      if (!mounted) return;
      _images.remove(s.id);
      context.showSuccessSnackBar(message);
      await _load();
    } catch (e) {
      if (mounted) context.showErrorSnackBar(e.toString());
    }
  }

  InputDecoration _decoration(String label, IconData icon, {String? hint}) =>
      InputDecoration(
        labelText: label,
        labelStyle: screenText(color: AppTheme.textSecondary),
        hintText: hint,
        hintStyle: screenText(color: AppTheme.textSecondary),
        errorStyle: screenText(size: 12.5, color: AppTheme.dangerColor),
        prefixIcon: Icon(icon),
        isDense: true,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      );

  Widget _preview(SignatureItem s) {
    if (!s.hasImage) {
      return Text(
        'ไม่มีรูป',
        style: screenText(size: 13, color: AppTheme.textSecondary),
      );
    }
    final future = _images.putIfAbsent(
      s.id,
      () => widget.apiService.getSignatureImage(s.id),
    );
    return FutureBuilder<Uint8List>(
      future: future,
      builder: (context, snap) {
        if (snap.hasData) {
          return Image.memory(
            snap.data!,
            height: 60,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) =>
                Text('แสดงรูปไม่ได้', style: screenText(size: 13)),
          );
        }
        if (snap.hasError) {
          return Text(
            'โหลดรูปไม่ได้',
            style: screenText(size: 13, color: AppTheme.dangerColor),
          );
        }
        return const SizedBox(
          height: 24,
          width: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        );
      },
    );
  }

  Widget _item(SignatureItem s) => Container(
    key: ValueKey('sign-${s.id}'),
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: AppTheme.dividerColor),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 150, child: Center(child: _preview(s))),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 6,
                children: [
                  StatusChip(s.kindName, AppTheme.primaryColor),
                  StatusChip('ตั้งแต่ ${s.effectiveText}', AppTheme.infoColor),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                s.name,
                style: screenText(size: 15, weight: FontWeight.w600),
              ),
              for (final l in s.positionLines)
                Text(l, style: screenText(size: 13.5)),
              Text(
                'บันทึกโดย ${s.uploadedBy ?? '-'} · ${Util.thaiDateOf(s.uploadedAt)}',
                style: screenText(size: 12, color: AppTheme.textSecondary),
              ),
            ],
          ),
        ),
        IconButton(
          key: AdminSignaturesScreen.deleteKey(s.id),
          tooltip: 'ลบ',
          icon: const Icon(Icons.delete_outline, color: AppTheme.deleteColor),
          onPressed: () => _delete(s),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final image = _image;
    return WorkPage(
      group: AdminSignaturesScreen.groupTitle,
      children: [
        const ScreenHeader(
          icon: AdminSignaturesScreen.menuIcon,
          title: AdminSignaturesScreen.menuTitle,
          subtitle:
              'ลายเซ็นที่พิมพ์บนใบเสร็จรับเงิน แยกผู้รับเงิน และ ผอ.กองการเงินฯ / เหรัญญิก',
          bullets: [
            'ลายเซ็นมีผลกับใบเสร็จตั้งแต่เดือนที่กำหนด จนกว่าจะมีลายเซ็นใหม่ของชนิดเดียวกัน',
            'รูป JPEG หรือ PNG ไม่เกิน 2 MB พื้นหลังขาวหรือโปร่งใส',
          ],
        ),
        const SizedBox(height: 14),
        StepCard(
          icon: Icons.add_photo_alternate_outlined,
          title: 'เพิ่มลายเซ็น',
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: 8,
                  children: [
                    for (final k in SignatureItem.kindNames.entries)
                      ChoiceChip(
                        key: AdminSignaturesScreen.kindKey(k.key),
                        label: Text(k.value, style: screenText(size: 14)),
                        selected: _kind == k.key,
                        onSelected: _saving
                            ? null
                            : (_) => setState(() => _kind = k.key),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: AdminSignaturesScreen.nameKey,
                  controller: _name,
                  enabled: !_saving,
                  style: screenText(),
                  validator: (v) =>
                      (v ?? '').trim().isEmpty ? 'กรุณากรอกชื่อผู้ลงนาม' : null,
                  decoration: _decoration(
                    'ชื่อผู้ลงนาม',
                    Icons.person_outline,
                    hint: 'เช่น (นายสมมุติ ตัวอย่าง)',
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  key: AdminSignaturesScreen.positionKey,
                  controller: _position,
                  enabled: !_saving,
                  style: screenText(),
                  minLines: 2,
                  maxLines: 4,
                  keyboardType: TextInputType.multiline,
                  inputFormatters: [LengthLimitingTextInputFormatter(400)],
                  decoration: _decoration(
                    'ตำแหน่ง (บรรทัดละหนึ่งบรรทัดบนใบเสร็จ)',
                    Icons.work_outline,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'มีผลตั้งแต่เดือน',
                  style: screenText(weight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                YearStepper(
                  year: _year,
                  min: 2550,
                  max: _today.year + 544,
                  enabled: !_saving,
                  onChanged: (y) => setState(() => _year = y),
                ),
                const SizedBox(height: 8),
                MonthPicker(
                  selected: _month,
                  enabled: !_saving,
                  onSelected: (m) => setState(() => _month = m),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    OutlinedButton.icon(
                      key: AdminSignaturesScreen.pickKey,
                      onPressed: _saving ? null : _pick,
                      icon: const Icon(Icons.image_outlined),
                      label: Text(
                        'เลือกรูปลายเซ็น',
                        style: screenText(size: 14),
                      ),
                    ),
                    if (image != null)
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          border: Border.all(color: AppTheme.dividerColor),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Image.memory(
                          image.bytes,
                          height: 60,
                          errorBuilder: (_, _, _) =>
                              Text(image.name, style: screenText(size: 13)),
                        ),
                      ),
                    if (image != null)
                      Text(
                        '${image.name} (${Util.formatFileSize(image.size)})',
                        style: screenText(size: 13),
                      ),
                  ],
                ),
                if (_imageError != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    _imageError!,
                    style: screenText(size: 13, color: AppTheme.dangerColor),
                  ),
                ],
                if (_saveError != null) ...[
                  const SizedBox(height: 10),
                  NoticeBar(type: NoticeType.error, text: _saveError!),
                ],
                const SizedBox(height: 14),
                Align(
                  alignment: Alignment.centerLeft,
                  child: PrimaryActionButton(
                    key: AdminSignaturesScreen.saveKey,
                    label: 'บันทึกลายเซ็น',
                    icon: Icons.save,
                    loading: _saving,
                    onPressed: _saving ? null : _save,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'ลายเซ็นในระบบ',
          style: screenText(size: 16, weight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        if (_loading || _error != null)
          LoadState(loading: _loading, error: _error, onRetry: _load)
        else if (_list.isEmpty)
          const NoticeBar(
            type: NoticeType.info,
            text: 'ยังไม่มีลายเซ็น ใบเสร็จจะออกได้แต่ช่องลายเซ็นว่าง',
          )
        else
          for (final s in _list) _item(s),
      ],
    );
  }
}
