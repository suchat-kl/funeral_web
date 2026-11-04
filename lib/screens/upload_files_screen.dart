import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../models/stored_file.dart';
import '../services/api_service.dart';
import '../utils/dialog.dart';
import '../utils/file_pick.dart';
import '../utils/roles.dart';
import '../utils/snackbar_helper.dart';
import '../utils/util.dart';
import '../widgets/file_table.dart';
import '../widgets/screen_parts.dart';
import '../widgets/upload_file_dialog.dart';
import '../widgets/work_parts.dart';

/// นำไฟล์เข้า › แบบฟอร์มทั่วไป / ทะเบียนคุมรายชื่อ (ผู้นำไฟล์เข้า / ผู้ดูแล)
///
/// หน้าจอเดียวรับ [kind] (`general` / `monthyear`) ใช้ทั้งสองเมนูย่อย
/// - ฟอร์มนำเข้า: ประเภทไฟล์ (ไม่บังคับ), ชื่อไฟล์ดาวน์โหลด, ไฟล์ (pdf doc docx xls xlsx zip ≤ 20 MB),
///   แบบฟอร์มสำหรับ (ข้าราชการ/ลูกจ้างประจำ/ทั้งหมด) เฉพาะแบบฟอร์มทั่วไป และปี/เดือนเฉพาะทะเบียนคุม
///   (ทะเบียนคุม: ทุกคนที่เข้าสู่ระบบเห็นทุกไฟล์ จึงไม่มีช่องแบบฟอร์มสำหรับ ส่งเป็น "ทั้งหมด" เสมอ)
/// - ตาราง: ทุกไฟล์ (ทะเบียนคุมกรองตามปี-เดือนที่เลือก) แก้รายละเอียด / ลบ (ลบไฟล์บนดิสก์ด้วย)
class UploadFilesScreen extends StatefulWidget {
  final ApiService apiService;
  final String kind;

  /// ตัวเลือกไฟล์ (เทสต์ส่งตัวปลอมแทนหน้าต่างของเบราว์เซอร์)
  final FilePicker? picker;

  final DateTime? today;

  const UploadFilesScreen({
    super.key,
    required this.apiService,
    required this.kind,
    this.picker,
    this.today,
  });

  static const String groupTitle = 'นำไฟล์เข้า';
  static const String generalTitle = 'แบบฟอร์มทั่วไป';
  static const String monthYearTitle = 'ทะเบียนคุมรายชื่อ';
  static const IconData generalIcon = Icons.upload_file;
  static const IconData monthYearIcon = Icons.drive_folder_upload_outlined;

  static const Key pickKey = ValueKey('upload-pick');
  static const Key titleKey = ValueKey('upload-title');
  static const Key typeKey = ValueKey('upload-type');
  static const Key submitKey = ValueKey('upload-submit');
  static Key editKey(String id) => ValueKey('edit-$id');
  static Key deleteKey(String id) => ValueKey('delete-$id');

  static String titleOf(String kind) =>
      kind == StoredFile.kindMonthYear ? monthYearTitle : generalTitle;

  @override
  State<UploadFilesScreen> createState() => _UploadFilesScreenState();
}

class _UploadFilesScreenState extends State<UploadFilesScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _type = TextEditingController();
  late final DateTime _today = widget.today ?? DateTime.now();
  late int _year = _today.year + 543;
  late int _month = _today.month;
  int _fileFor = FileFor.all;
  PickedFile? _file;
  String? _fileError;
  bool _uploading = false;
  String? _uploadError;

  List<StoredFile> _files = [];
  bool _loading = true;
  String? _error;
  final Set<String> _busyIds = {};

  bool get _monthYear => widget.kind == StoredFile.kindMonthYear;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _title.dispose();
    _type.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final files = await widget.apiService.getUploadFiles(
        widget.kind,
        yearMonth: _monthYear ? Util.yearMonth(_year, _month) : null,
      );
      if (!mounted) return;
      setState(() {
        _files = files;
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
    final picked =
        await (widget.picker ??
            () => pickDocumentFile(maxBytes: ApiService.maxUploadBytes))();
    if (picked == null || !mounted) return;
    final dot = picked.name.lastIndexOf('.');
    final ext = dot < 0 ? '' : picked.name.substring(dot + 1).toLowerCase();
    setState(() {
      _uploadError = null;
      if (!ApiService.uploadExtensions.contains(ext)) {
        _file = null;
        _fileError =
            'รับเฉพาะไฟล์ ${ApiService.uploadExtensions.join(' ')} (ไฟล์ที่เลือก: ${picked.name})';
      } else if (picked.size > ApiService.maxUploadBytes) {
        _file = null;
        _fileError = 'ไฟล์ใหญ่เกิน 20 MB (${Util.formatFileSize(picked.size)})';
      } else {
        _file = picked;
        _fileError = null;
        // ชื่อไฟล์ดาวน์โหลดว่างอยู่: เติมจากชื่อไฟล์ (ไม่มีนามสกุล) ให้แก้ต่อได้
        if (_title.text.trim().isEmpty) {
          _title.text = dot < 0 ? picked.name : picked.name.substring(0, dot);
        }
      }
    });
  }

  Future<void> _upload() async {
    if (_uploading) return;
    final file = _file;
    final formOk = _formKey.currentState!.validate();
    if (file == null) {
      setState(() => _fileError ??= 'กรุณาเลือกไฟล์');
      return;
    }
    if (!formOk) return;
    setState(() {
      _uploading = true;
      _uploadError = null;
    });
    try {
      await widget.apiService.uploadFile(
        widget.kind,
        bytes: file.bytes,
        fileName: file.name,
        typeFile: _type.text,
        title: _title.text,
        fileFor: _monthYear ? FileFor.all : _fileFor,
        yearMonth: _monthYear ? Util.yearMonth(_year, _month) : null,
      );
      if (!mounted) return;
      setState(() {
        _uploading = false;
        _file = null;
        _title.clear();
      });
      context.showSuccessSnackBar('นำไฟล์เข้าเรียบร้อย');
      await _load();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _uploading = false;
        _uploadError = e.toString();
      });
    }
  }

  Future<void> _edit(StoredFile f) async {
    final saved = await showDialog<StoredFile>(
      context: context,
      barrierDismissible: false,
      builder: (_) => UploadFileDialog(
        apiService: widget.apiService,
        kind: widget.kind,
        file: f,
      ),
    );
    if (saved == null || !mounted) return;
    context.showSuccessSnackBar('บันทึกรายละเอียดไฟล์เรียบร้อย');
    await _load();
  }

  Future<void> _delete(StoredFile f) async {
    final ok = await AppDialog.showConfirm(
      context,
      'ลบไฟล์ "${f.title}"?\nไฟล์จะถูกลบออกจากเครื่องแม่ข่ายด้วย กู้คืนไม่ได้',
      confirmText: 'ลบ',
    );
    if (ok != true || !mounted) return;
    setState(() => _busyIds.add(f.id));
    try {
      final message = await widget.apiService.deleteUploadFile(
        widget.kind,
        f.id,
      );
      if (!mounted) return;
      context.showSuccessSnackBar(message);
      await _load();
    } catch (e) {
      if (!mounted) return;
      context.showErrorSnackBar(e.toString());
    } finally {
      if (mounted) setState(() => _busyIds.remove(f.id));
    }
  }

  Widget _periodPicker({required bool enabled}) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          Text('ปี พ.ศ.', style: screenText(weight: FontWeight.w600)),
          const SizedBox(width: 12),
          YearStepper(
            year: _year,
            min: 2550,
            max: _today.year + 544,
            enabled: enabled,
            onChanged: (y) {
              setState(() => _year = y);
              _load();
            },
          ),
        ],
      ),
      const SizedBox(height: 8),
      MonthPicker(
        selected: _month,
        enabled: enabled,
        onSelected: (m) {
          setState(() => _month = m);
          _load();
        },
      ),
    ],
  );

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

  @override
  Widget build(BuildContext context) {
    final title = UploadFilesScreen.titleOf(widget.kind);
    final file = _file;
    return WorkPage(
      group: UploadFilesScreen.groupTitle,
      maxWidth: 1200,
      children: [
        ScreenHeader(
          icon: _monthYear
              ? UploadFilesScreen.monthYearIcon
              : UploadFilesScreen.generalIcon,
          title: 'นำไฟล์เข้า › $title',
          subtitle: _monthYear
              ? 'นำทะเบียนคุมรายชื่อประจำเดือนเข้าระบบ ผู้ใช้ที่เข้าสู่ระบบดาวน์โหลดได้'
              : 'นำแบบฟอร์มเข้าระบบ แบบฟอร์มสำหรับ "ทั้งหมด" ดาวน์โหลดได้โดยไม่ต้องเข้าสู่ระบบ',
          bullets: const [
            'รับไฟล์ pdf doc docx xls xlsx zip ขนาดไม่เกิน 20 MB',
          ],
        ),
        const SizedBox(height: 14),
        if (_monthYear) ...[
          StepCard(
            icon: Icons.event_note,
            title: 'ปีและเดือนของทะเบียนคุม',
            subtitle: 'ใช้ทั้งกับไฟล์ที่นำเข้าใหม่และรายการด้านล่าง',
            child: _periodPicker(enabled: !_uploading),
          ),
          const SizedBox(height: 12),
        ],
        StepCard(
          icon: Icons.cloud_upload_outlined,
          title: 'นำไฟล์ใหม่เข้า',
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  key: UploadFilesScreen.typeKey,
                  controller: _type,
                  enabled: !_uploading,
                  style: screenText(),
                  decoration: _decoration(
                    'ประเภทไฟล์ (ไม่บังคับ)',
                    Icons.category_outlined,
                    hint: 'เช่น แบบฟอร์ม / ประกาศ',
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  key: UploadFilesScreen.titleKey,
                  controller: _title,
                  enabled: !_uploading,
                  style: screenText(),
                  validator: (v) => (v ?? '').trim().isEmpty
                      ? 'กรุณากรอกชื่อไฟล์ดาวน์โหลด'
                      : null,
                  decoration: _decoration('ชื่อไฟล์ดาวน์โหลด', Icons.title),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    OutlinedButton.icon(
                      key: UploadFilesScreen.pickKey,
                      onPressed: _uploading ? null : _pick,
                      icon: const Icon(Icons.attach_file),
                      label: Text('เลือกไฟล์', style: screenText(size: 14)),
                    ),
                    Text(
                      file == null
                          ? 'ยังไม่ได้เลือกไฟล์'
                          : '${file.name} (${Util.formatFileSize(file.size)})',
                      style: screenText(
                        size: 13.5,
                        color: file == null
                            ? AppTheme.textSecondary
                            : AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
                if (_fileError != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    _fileError!,
                    style: screenText(size: 13, color: AppTheme.dangerColor),
                  ),
                ],
                if (!_monthYear) ...[
                  const SizedBox(height: 12),
                  Text(
                    'แบบฟอร์มสำหรับ',
                    style: screenText(weight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  FileForChips(
                    value: _fileFor,
                    enabled: !_uploading,
                    onChanged: (v) => setState(() => _fileFor = v),
                  ),
                ],
                if (_monthYear) ...[
                  const SizedBox(height: 10),
                  Text(
                    'จะนำเข้าเป็นทะเบียนคุมของ ${Util.thaiMonthName(_month)} $_year',
                    style: screenText(size: 13.5, color: AppTheme.primaryDark),
                  ),
                ],
                if (_uploadError != null) ...[
                  const SizedBox(height: 10),
                  NoticeBar(type: NoticeType.error, text: _uploadError!),
                ],
                const SizedBox(height: 14),
                Align(
                  alignment: Alignment.centerLeft,
                  child: PrimaryActionButton(
                    key: UploadFilesScreen.submitKey,
                    label: _uploading ? 'กำลังนำไฟล์เข้า...' : 'นำไฟล์เข้า',
                    icon: Icons.cloud_upload,
                    loading: _uploading,
                    onPressed: _uploading ? null : _upload,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        StepCard(
          icon: Icons.folder_open,
          title: _monthYear
              ? 'ไฟล์ของ ${Util.thaiMonthName(_month)} $_year'
              : 'แบบฟอร์มในระบบ',
          trailing: IconButton(
            tooltip: 'โหลดใหม่',
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _load,
          ),
          child: _loading || _error != null
              ? LoadState(loading: _loading, error: _error, onRetry: _load)
              : FileTable(
                  key: ValueKey('upload-${widget.kind}-$_year-$_month'),
                  files: _files,
                  showYearMonth: _monthYear,
                  showFileFor: !_monthYear,
                  emptyText: 'ยังไม่มีไฟล์',
                  actions: (f) => [
                    IconButton(
                      key: UploadFilesScreen.editKey(f.id),
                      tooltip: 'แก้ไขรายละเอียด',
                      icon: const Icon(Icons.edit, color: AppTheme.editColor),
                      onPressed: _busyIds.contains(f.id)
                          ? null
                          : () => _edit(f),
                    ),
                    IconButton(
                      key: UploadFilesScreen.deleteKey(f.id),
                      tooltip: 'ลบ',
                      icon: const Icon(
                        Icons.delete_outline,
                        color: AppTheme.deleteColor,
                      ),
                      onPressed: _busyIds.contains(f.id)
                          ? null
                          : () => _delete(f),
                    ),
                  ],
                ),
        ),
      ],
    );
  }
}
