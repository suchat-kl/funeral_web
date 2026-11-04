import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/theme.dart';
import '../models/uploader.dart';
import '../services/api_service.dart';
import '../utils/dialog.dart';
import '../utils/snackbar_helper.dart';
import '../utils/util.dart';
import '../widgets/screen_parts.dart';
import '../widgets/sheet_table.dart';
import '../widgets/work_parts.dart';

/// ผู้ดูแล › ผู้มีสิทธิ์นำไฟล์เข้า — เพิ่มด้วยเลขบัตร (ชื่อจาก DPIS) / ลบ
///
/// ไม่พบเลขบัตรใน DPIS (เช่นเจ้าหน้าที่ฌาปนกิจที่ไม่มีในทะเบียนบุคลากร) = เปิดช่องชื่อ-สกุลให้ผู้ดูแลกรอกเองแล้วกดเพิ่มอีกครั้ง
/// แก้เลขบัตรเมื่อไหร่ ช่องชื่อ-สกุลปิดไป (เลขใหม่ต้องตรวจกับ DPIS ก่อน)
///
/// สิทธิ์มีผลตั้งแต่ผู้นั้นเข้าสู่ระบบครั้งถัดไป (backend ตรวจรายชื่อทุกครั้งที่เข้าสู่ระบบ)
/// เลขบัตรแสดงแบบปิดบางส่วน ไม่ log
class AdminUploadersScreen extends StatefulWidget {
  final ApiService apiService;

  const AdminUploadersScreen({super.key, required this.apiService});

  static const String menuTitle = 'ผู้มีสิทธิ์นำไฟล์เข้า';
  static const IconData menuIcon = Icons.badge_outlined;
  static const String groupTitle = 'ผู้ดูแล';

  static const Key idcardKey = ValueKey('uploader-idcard');
  static const Key addKey = ValueKey('uploader-add');
  static const Key fullNameKey = ValueKey('uploader-fullname');
  static const Key notInDpisKey = ValueKey('uploader-not-in-dpis');
  static Key manualTagKey(String id) => ValueKey('uploader-manual-$id');
  static Key deleteKey(String id) => ValueKey('uploader-delete-$id');

  @override
  State<AdminUploadersScreen> createState() => _AdminUploadersScreenState();
}

class _AdminUploadersScreenState extends State<AdminUploadersScreen> {
  final _formKey = GlobalKey<FormState>();
  final _idcard = TextEditingController();
  final _fullName = TextEditingController();
  List<Uploader> _list = [];

  /// เลขบัตรที่ backend ตอบว่าไม่พบใน DPIS (null = ยังไม่ต้องกรอกชื่อเอง)
  String? _notInDpisFor;
  bool _loading = true;
  bool _adding = false;
  String? _error;
  String? _addError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _idcard.dispose();
    _fullName.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await widget.apiService.getUploaders();
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

  bool get _needName =>
      _notInDpisFor != null && _notInDpisFor == _idcard.text.trim();

  /// แก้เลขบัตร = ปิดช่องชื่อ-สกุล (เลขใหม่ต้องตรวจกับ DPIS ก่อน)
  void _idcardChanged(String v) {
    if (_notInDpisFor != null && v.trim() != _notInDpisFor) {
      setState(() {
        _notInDpisFor = null;
        _addError = null;
        _fullName.clear();
      });
    }
  }

  Future<void> _add() async {
    if (_adding || !_formKey.currentState!.validate()) return;
    final idcard = _idcard.text.trim();
    final needName = _needName;
    setState(() {
      _adding = true;
      _addError = null;
    });
    try {
      final u = await widget.apiService.addUploader(
        idcard,
        fullName: needName ? _fullName.text.trim() : null,
      );
      if (!mounted) return;
      _idcard.clear();
      _fullName.clear();
      setState(() {
        _adding = false;
        _notInDpisFor = null;
      });
      context.showSuccessSnackBar(
        'เพิ่ม ${u.fullName.isEmpty ? 'ผู้มีสิทธิ์' : u.fullName} เรียบร้อย มีผลเมื่อเข้าสู่ระบบครั้งถัดไป',
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      final notInDpis = e is ApiException && e.code == ErrorCodes.notInDpis;
      setState(() {
        _adding = false;
        if (notInDpis) {
          _notInDpisFor = idcard;
          _addError = null;
        } else {
          _addError = e.toString();
        }
      });
    }
  }

  Future<void> _delete(Uploader u) async {
    final ok = await AppDialog.showConfirm(
      context,
      'ลบสิทธิ์นำไฟล์เข้าของ "${u.fullName.isEmpty ? Util.maskIdcard(u.idcard) : u.fullName}"?\n'
      'มีผลเมื่อผู้นั้นเข้าสู่ระบบครั้งถัดไป',
      confirmText: 'ลบ',
    );
    if (ok != true || !mounted) return;
    try {
      final message = await widget.apiService.deleteUploader(u.id);
      if (!mounted) return;
      context.showSuccessSnackBar(message);
      await _load();
    } catch (e) {
      if (mounted) context.showErrorSnackBar(e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return WorkPage(
      group: AdminUploadersScreen.groupTitle,
      children: [
        const ScreenHeader(
          icon: AdminUploadersScreen.menuIcon,
          title: AdminUploadersScreen.menuTitle,
          subtitle:
              'ผู้ที่นำแบบฟอร์มและทะเบียนคุมรายชื่อเข้าระบบได้ และดูรายงานฌาปนกิจได้',
          bullets: [
            'เพิ่มด้วยเลขบัตรประชาชน ระบบอ่านชื่อจากข้อมูลบุคลากร (DPIS)',
            'ไม่พบใน DPIS (เช่นเจ้าหน้าที่ฌาปนกิจ) กรอกชื่อ-สกุลเองแล้วเพิ่มได้',
            'เพิ่ม/ลบแล้วมีผลเมื่อผู้นั้นเข้าสู่ระบบครั้งถัดไป',
          ],
        ),
        const SizedBox(height: 14),
        StepCard(
          icon: Icons.person_add_alt,
          title: 'เพิ่มผู้มีสิทธิ์นำไฟล์เข้า',
          child: Form(
            key: _formKey,
            child: Wrap(
              spacing: 12,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.start,
              children: [
                SizedBox(
                  width: 320,
                  child: TextFormField(
                    key: AdminUploadersScreen.idcardKey,
                    controller: _idcard,
                    enabled: !_adding,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(13),
                    ],
                    style: screenText(),
                    onChanged: _idcardChanged,
                    validator: (v) {
                      final s = (v ?? '').trim();
                      if (s.isEmpty) return 'กรุณากรอกเลขบัตรประชาชน';
                      if (!Util.isValidThaiId(s)) {
                        return 'เลขบัตรประชาชนไม่ถูกต้อง';
                      }
                      return null;
                    },
                    onFieldSubmitted: (_) => _add(),
                    decoration: InputDecoration(
                      labelText: 'เลขบัตรประชาชน 13 หลัก',
                      labelStyle: screenText(color: AppTheme.textSecondary),
                      errorStyle: screenText(
                        size: 12.5,
                        color: AppTheme.dangerColor,
                      ),
                      prefixIcon: const Icon(Icons.credit_card),
                      isDense: true,
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                if (_needName)
                  SizedBox(
                    width: 320,
                    child: TextFormField(
                      key: AdminUploadersScreen.fullNameKey,
                      controller: _fullName,
                      enabled: !_adding,
                      autofocus: true,
                      inputFormatters: [LengthLimitingTextInputFormatter(150)],
                      style: screenText(),
                      validator: (v) => (v ?? '').trim().isEmpty
                          ? 'กรุณากรอกชื่อ-สกุล'
                          : null,
                      onFieldSubmitted: (_) => _add(),
                      decoration: InputDecoration(
                        labelText: 'ชื่อ-สกุล (กรอกเอง)',
                        hintText: 'เช่น นางสาวสมใจ ใจดี',
                        labelStyle: screenText(color: AppTheme.textSecondary),
                        errorStyle: screenText(
                          size: 12.5,
                          color: AppTheme.dangerColor,
                        ),
                        prefixIcon: const Icon(Icons.person_outline),
                        isDense: true,
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                PrimaryActionButton(
                  key: AdminUploadersScreen.addKey,
                  label: 'เพิ่ม',
                  icon: Icons.add,
                  loading: _adding,
                  onPressed: _adding ? null : _add,
                ),
                if (_needName)
                  const NoticeBar(
                    key: AdminUploadersScreen.notInDpisKey,
                    type: NoticeType.warning,
                    text:
                        'ไม่พบเลขบัตรนี้ในทะเบียนบุคลากร (DPIS) — ถ้าเป็นเจ้าหน้าที่ที่ไม่มีใน DPIS '
                        'ให้กรอกชื่อ-สกุลแล้วกด "เพิ่ม" อีกครั้ง',
                  ),
                if (_addError != null)
                  NoticeBar(type: NoticeType.error, text: _addError!),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        if (_loading || _error != null)
          LoadState(loading: _loading, error: _error, onRetry: _load)
        else
          SheetScroll(
            minWidth: 680,
            child: SheetCard(
              emptyText: 'ยังไม่มีผู้มีสิทธิ์นำไฟล์เข้า',
              header: const Row(
                children: [
                  Expanded(flex: 5, child: SheetHead('ชื่อ-สกุล')),
                  Expanded(flex: 3, child: SheetHead('เลขบัตรประชาชน')),
                  Expanded(flex: 4, child: SheetHead('เพิ่มโดย / เมื่อ')),
                  Expanded(flex: 1, child: SizedBox.shrink()),
                ],
              ),
              rows: [
                for (final u in _list)
                  Row(
                    key: ValueKey('uploader-${u.id}'),
                    children: [
                      Expanded(
                        flex: 5,
                        child: Padding(
                          padding: const EdgeInsets.all(6),
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                u.fullName.isEmpty ? '-' : u.fullName,
                                style: screenText(
                                  size: 14.5,
                                  weight: FontWeight.w600,
                                ),
                              ),
                              if (u.manualName)
                                StatusChip(
                                  'ไม่พบใน DPIS',
                                  AppTheme.warningColor,
                                  icon: Icons.edit_note,
                                  key: AdminUploadersScreen.manualTagKey(u.id),
                                ),
                            ],
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Text(
                          Util.maskIdcard(u.idcard),
                          style: screenText(size: 14),
                        ),
                      ),
                      Expanded(
                        flex: 4,
                        child: Text(
                          '${u.addedBy ?? '-'} · ${Util.thaiDateOf(u.addedAt)}',
                          style: screenText(
                            size: 13,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 1,
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: IconButton(
                            key: AdminUploadersScreen.deleteKey(u.id),
                            tooltip: 'ลบ',
                            icon: const Icon(
                              Icons.delete_outline,
                              color: AppTheme.deleteColor,
                            ),
                            onPressed: () => _delete(u),
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
