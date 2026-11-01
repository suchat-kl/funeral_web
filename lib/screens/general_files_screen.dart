import 'package:flutter/material.dart';

import '../models/stored_file.dart';
import '../services/api_service.dart';
import '../widgets/file_table.dart';
import '../widgets/screen_parts.dart';
import '../widgets/work_parts.dart';

/// ดาวน์โหลด › แบบฟอร์มทั่วไป — ดูและดาวน์โหลดได้โดยไม่ต้องเข้าสู่ระบบ
///
/// ไม่เข้าสู่ระบบ = เห็นเฉพาะแบบฟอร์ม "ทั้งหมด"; เข้าสู่ระบบ = backend กรองตามประเภทบุคลากร
/// (ผู้นำไฟล์เข้า/ผู้ดูแลเห็นทุกไฟล์)
class GeneralFilesScreen extends StatefulWidget {
  final ApiService apiService;

  const GeneralFilesScreen({super.key, required this.apiService});

  static const String menuTitle = 'แบบฟอร์มทั่วไป';
  static const IconData menuIcon = Icons.description_outlined;
  static const String groupTitle = 'ดาวน์โหลด';

  @override
  State<GeneralFilesScreen> createState() => _GeneralFilesScreenState();
}

class _GeneralFilesScreenState extends State<GeneralFilesScreen>
    with FileDownloads<GeneralFilesScreen> {
  List<StoredFile> _files = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final files = await widget.apiService.getGeneralFiles();
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

  @override
  Widget build(BuildContext context) {
    final loggedIn = widget.apiService.isLoggedIn;
    return WorkPage(
      group: GeneralFilesScreen.groupTitle,
      maxWidth: 1200,
      children: [
        ScreenHeader(
          icon: GeneralFilesScreen.menuIcon,
          title: GeneralFilesScreen.menuTitle,
          subtitle: 'แบบฟอร์มและเอกสารของฌาปนกิจ ดาวน์โหลดได้ทันที',
          bullets: [
            loggedIn
                ? 'แสดงแบบฟอร์มที่ตรงกับประเภทบุคลากรของท่าน'
                : 'ยังไม่ได้เข้าสู่ระบบ: แสดงเฉพาะแบบฟอร์มสำหรับทุกคน เข้าสู่ระบบเพื่อดูแบบฟอร์มเฉพาะข้าราชการ/ลูกจ้างประจำ',
          ],
        ),
        const SizedBox(height: 14),
        if (downloadError != null) ...[
          NoticeBar(type: NoticeType.error, text: downloadError!),
          const SizedBox(height: 10),
        ],
        if (_loading || _error != null)
          LoadState(loading: _loading, error: _error, onRetry: _load)
        else
          FileTable(
            files: _files,
            emptyText: 'ยังไม่มีแบบฟอร์ม',
            actions: (f) => [
              RowDownloadButton(
                key: ValueKey('download-${f.id}'),
                busy: downloading == f.id,
                enabled: downloading == null,
                onPressed: () => runDownload(
                  f.id,
                  () => widget.apiService.downloadGeneralFile(f),
                ),
              ),
            ],
          ),
      ],
    );
  }
}
