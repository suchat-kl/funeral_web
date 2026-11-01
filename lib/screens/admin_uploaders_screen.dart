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
  static Key deleteKey(String id) => ValueKey('uploader-delete-$id');

  @override
  State<AdminUploadersScreen> createState() => _AdminUploadersScreenState();
}

class _AdminUploadersScreenState extends State<AdminUploadersScreen> {
  final _formKey = GlobalKey<FormState>();
  final _idcard = TextEditingController();
  List<Uploader> _list = [];
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

  Future<void> _add() async {
    if (_adding || !_formKey.currentState!.validate()) return;
    setState(() {
      _adding = true;
      _addError = null;
    });
    try {
      final u = await widget.apiService.addUploader(_idcard.text.trim());
      if (!mounted) return;
      _idcard.clear();
      setState(() => _adding = false);
      context.showSuccessSnackBar(
        'เพิ่ม ${u.fullName.isEmpty ? 'ผู้มีสิทธิ์' : u.fullName} เรียบร้อย มีผลเมื่อเข้าสู่ระบบครั้งถัดไป',
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _adding = false;
        _addError = e.toString();
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
                PrimaryActionButton(
                  key: AdminUploadersScreen.addKey,
                  label: 'เพิ่ม',
                  icon: Icons.add,
                  loading: _adding,
                  onPressed: _adding ? null : _add,
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
                          child: Text(
                            u.fullName.isEmpty ? '-' : u.fullName,
                            style: screenText(
                              size: 14.5,
                              weight: FontWeight.w600,
                            ),
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
