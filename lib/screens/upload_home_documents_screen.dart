import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/theme.dart';
import '../models/home_document.dart';
import '../services/api_service.dart';
import '../utils/dialog.dart';
import '../utils/file_download.dart';
import '../utils/file_pick.dart';
import '../utils/snackbar_helper.dart';
import '../utils/util.dart';
import '../widgets/screen_parts.dart';
import '../widgets/work_parts.dart';

/// นำไฟล์เข้า › เอกสารหน้าแรก — PDF สองไฟล์ที่แสดงเป็นปุ่มบนหน้าแรก
/// (ประชาสัมพันธ์และเชิญชวนสมัครสมาชิก / ข้อบังคับ ฌ.ส.ทล) แทนไฟล์ตายตัวของระบบเดิม
///
/// ต่อช่อง: แก้ข้อความบนปุ่ม, เลือก PDF ใหม่แทนไฟล์เดิม, เปิดดูไฟล์ปัจจุบัน, เอาออก (ปุ่มหายจากหน้าแรก)
class UploadHomeDocumentsScreen extends StatefulWidget {
  final ApiService apiService;

  /// ตัวเลือกไฟล์ (เทสต์ส่งตัวปลอม)
  final FilePicker? picker;

  const UploadHomeDocumentsScreen({
    super.key,
    required this.apiService,
    this.picker,
  });

  static const String menuTitle = 'เอกสารหน้าแรก';
  static const IconData menuIcon = Icons.picture_as_pdf_outlined;
  static const String groupTitle = 'นำไฟล์เข้า';

  static Key titleKey(String slot) => ValueKey('home-doc-title-$slot');
  static Key pickKey(String slot) => ValueKey('home-doc-pick-$slot');
  static Key saveKey(String slot) => ValueKey('home-doc-save-$slot');
  static Key openKey(String slot) => ValueKey('home-doc-open-$slot');
  static Key removeKey(String slot) => ValueKey('home-doc-remove-$slot');

  @override
  State<UploadHomeDocumentsScreen> createState() =>
      _UploadHomeDocumentsScreenState();
}

class _UploadHomeDocumentsScreenState extends State<UploadHomeDocumentsScreen> {
  List<HomeDocument> _docs = [];
  bool _loading = true;
  String? _error;

  /// แยกตามช่อง
  final Map<String, TextEditingController> _titles = {};
  final Map<String, PickedFile> _picked = {};
  final Map<String, String> _fileErrors = {};
  final Map<String, String> _saveErrors = {};
  String? _busy;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in _titles.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final docs = await widget.apiService.getHomeDocuments();
      if (!mounted) return;
      for (final d in docs) {
        (_titles[d.slot] ??= TextEditingController()).text = d.title;
      }
      setState(() {
        _docs = docs;
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

  Future<void> _pick(String slot) async {
    final picked =
        await (widget.picker ??
            () => pickFile(
              accept: '.pdf,application/pdf',
              maxBytes: ApiService.maxUploadBytes,
            ))();
    if (picked == null || !mounted) return;
    setState(() {
      _saveErrors.remove(slot);
      if (!picked.name.toLowerCase().endsWith('.pdf')) {
        _picked.remove(slot);
        _fileErrors[slot] = 'รับเฉพาะไฟล์ PDF';
      } else if (picked.size > ApiService.maxUploadBytes) {
        _picked.remove(slot);
        _fileErrors[slot] =
            'ไฟล์ใหญ่เกิน 20 MB (${Util.formatFileSize(picked.size)})';
      } else {
        _fileErrors.remove(slot);
        _picked[slot] = picked;
      }
    });
  }

  Future<void> _save(HomeDocument d) async {
    if (_busy != null) return;
    final title = _titles[d.slot]!.text.trim();
    final file = _picked[d.slot];
    if (title.isEmpty) {
      setState(() => _saveErrors[d.slot] = 'กรุณากรอกข้อความบนปุ่ม');
      return;
    }
    if (file == null && !d.available) {
      setState(() => _fileErrors[d.slot] = 'กรุณาเลือกไฟล์ PDF');
      return;
    }
    setState(() {
      _busy = d.slot;
      _saveErrors.remove(d.slot);
    });
    try {
      await widget.apiService.saveHomeDocument(
        d.slot,
        title: title,
        bytes: file?.bytes,
        fileName: file?.name,
      );
      if (!mounted) return;
      setState(() {
        _busy = null;
        _picked.remove(d.slot);
      });
      context.showSuccessSnackBar('บันทึก "${d.slotName}" เรียบร้อย');
      await _load();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = null;
        _saveErrors[d.slot] = e.toString();
      });
    }
  }

  Future<void> _remove(HomeDocument d) async {
    final ok = await AppDialog.showConfirm(
      context,
      'เอาไฟล์ "${d.slotName}" ออก? ปุ่มนี้จะหายจากหน้าแรกจนกว่าจะอัปโหลดไฟล์ใหม่',
      confirmText: 'เอาออก',
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = d.slot);
    try {
      final message = await widget.apiService.removeHomeDocument(d.slot);
      if (!mounted) return;
      setState(() => _busy = null);
      context.showSuccessSnackBar(message);
      await _load();
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = null);
      context.showErrorSnackBar(e.toString());
    }
  }

  Widget _card(HomeDocument d) {
    final busy = _busy == d.slot;
    final disabled = _busy != null;
    final picked = _picked[d.slot];
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: StepCard(
        icon: Icons.picture_as_pdf_outlined,
        title: d.slotName,
        trailing: d.available
            ? const StatusChip('แสดงบนหน้าแรก', AppTheme.successColor)
            : const StatusChip('ยังไม่มีไฟล์', AppTheme.warningColor),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              key: UploadHomeDocumentsScreen.titleKey(d.slot),
              controller: _titles[d.slot],
              enabled: !disabled,
              style: screenText(),
              inputFormatters: [LengthLimitingTextInputFormatter(200)],
              decoration: InputDecoration(
                labelText: 'ข้อความบนปุ่มหน้าแรก',
                labelStyle: screenText(color: AppTheme.textSecondary),
                prefixIcon: const Icon(Icons.smart_button_outlined),
                isDense: true,
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 10),
            if (d.available)
              Text(
                'ไฟล์ปัจจุบัน: ${d.fileName ?? '-'}'
                '${d.size == null ? '' : ' (${Util.formatFileSize(d.size!)})'}'
                ' · บันทึกโดย ${d.uploadedBy ?? '-'} ${Util.thaiDateOf(d.uploadedAt)}',
                style: screenText(size: 13, color: AppTheme.textSecondary),
              ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                OutlinedButton.icon(
                  key: UploadHomeDocumentsScreen.pickKey(d.slot),
                  onPressed: disabled ? null : () => _pick(d.slot),
                  icon: const Icon(Icons.attach_file),
                  label: Text(
                    d.available ? 'เลือกไฟล์ PDF ใหม่' : 'เลือกไฟล์ PDF',
                    style: screenText(size: 14),
                  ),
                ),
                if (picked != null)
                  Text(
                    '${picked.name} (${Util.formatFileSize(picked.size)})',
                    style: screenText(size: 13),
                  ),
              ],
            ),
            if (_fileErrors[d.slot] != null) ...[
              const SizedBox(height: 6),
              Text(
                _fileErrors[d.slot]!,
                style: screenText(size: 13, color: AppTheme.dangerColor),
              ),
            ],
            if (_saveErrors[d.slot] != null) ...[
              const SizedBox(height: 10),
              NoticeBar(type: NoticeType.error, text: _saveErrors[d.slot]!),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                PrimaryActionButton(
                  key: UploadHomeDocumentsScreen.saveKey(d.slot),
                  label: picked != null ? 'อัปโหลดและบันทึก' : 'บันทึก',
                  icon: Icons.save,
                  loading: busy,
                  onPressed: disabled ? null : () => _save(d),
                ),
                if (d.available) ...[
                  OutlinedButton.icon(
                    key: UploadHomeDocumentsScreen.openKey(d.slot),
                    onPressed: () => LinkOpener.open(d.fileUrl),
                    icon: const Icon(Icons.open_in_new),
                    label: Text('เปิดดู', style: screenText(size: 14)),
                  ),
                  TextButton.icon(
                    key: UploadHomeDocumentsScreen.removeKey(d.slot),
                    onPressed: disabled ? null : () => _remove(d),
                    icon: const Icon(
                      Icons.delete_outline,
                      color: AppTheme.deleteColor,
                    ),
                    label: Text(
                      'เอาออก',
                      style: screenText(size: 14, color: AppTheme.deleteColor),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WorkPage(
      group: UploadHomeDocumentsScreen.groupTitle,
      children: [
        const ScreenHeader(
          icon: UploadHomeDocumentsScreen.menuIcon,
          title: UploadHomeDocumentsScreen.menuTitle,
          subtitle:
              'ไฟล์ PDF ที่แสดงเป็นปุ่มบนหน้าแรก ทุกคนเปิดได้โดยไม่ต้องเข้าสู่ระบบ',
          bullets: [
            'เลือกไฟล์ใหม่แล้วบันทึก = แทนที่ไฟล์เดิมทันที',
            'แก้ข้อความบนปุ่มอย่างเดียวได้ ไม่ต้องเลือกไฟล์ใหม่',
            'รับเฉพาะ PDF ไม่เกิน 20 MB',
          ],
        ),
        const SizedBox(height: 14),
        if (_loading || _error != null)
          LoadState(loading: _loading, error: _error, onRetry: _load)
        else
          for (final d in _docs) _card(d),
      ],
    );
  }
}
