import 'dart:typed_data';

import 'package:universal_html/html.dart' as html;

/// ไฟล์ที่ได้จาก backend (รายงาน PDF / xlsx / ไฟล์ข้อความ TIS-620 / zip) — เป็นไบต์ตามที่ส่งมา ไม่แปลงรหัสอักขระ
///
/// **ไฟล์มีข้อมูลบุคคล**: อยู่ในหน่วยความจำของแท็บเท่านั้น ห้ามเก็บลง localStorage / IndexedDB และห้ามลง log
class DownloadedFile {
  final Uint8List bytes;
  final String fileName;

  /// ชนิดของไฟล์ตาม header `Content-Type` (ไม่มี = application/octet-stream)
  final String mime;

  const DownloadedFile({
    required this.bytes,
    required this.fileName,
    this.mime = 'application/octet-stream',
  });

  bool get isPdf => mime.startsWith('application/pdf');
}

/// ไฟล์ที่ส่งให้เบราว์เซอร์แล้ว ยังเปิดดูซ้ำได้จนกว่าจะ [dispose]
abstract class SavedFile {
  String get fileName;

  /// เปิดดูในแท็บใหม่ (เรียกจากการกดปุ่มของผู้ใช้โดยตรง ตัวบล็อก popup จึงไม่กัน)
  void open();

  /// เลิกใช้: คืนหน่วยความจำของไฟล์ให้เบราว์เซอร์
  void dispose();
}

/// ตัวส่งไฟล์ให้ผู้ใช้ แยกไว้เพื่อให้เทสต์ส่งตัวจำลองแทนการแตะ DOM ของเบราว์เซอร์
///
/// หน้าจอเรียก `FileSaver.instance.save(...)` เทสต์ตั้ง [instance] เป็นตัวจำลองแล้วตั้งคืนตอนจบ
abstract class FileSaver {
  const FileSaver();

  /// ดาวน์โหลด [file] แล้วคืนตัวจับไว้เปิดดูภายหลัง
  SavedFile save(DownloadedFile file);

  static FileSaver instance = const BrowserFileSaver();
}

/// ของจริง: สร้าง Blob + object URL แล้วสั่งดาวน์โหลดผ่านลิงก์ที่มี attribute download
class BrowserFileSaver extends FileSaver {
  const BrowserFileSaver();

  @override
  SavedFile save(DownloadedFile file) {
    final blob = html.Blob([file.bytes], file.mime);
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..download = file.fileName
      ..style.display = 'none';
    html.document.body?.append(anchor);
    anchor.click();
    anchor.remove();
    return _BrowserFile(file.fileName, url);
  }
}

class _BrowserFile implements SavedFile {
  @override
  final String fileName;
  final String _url;
  bool _disposed = false;

  _BrowserFile(this.fileName, this._url);

  @override
  void open() {
    if (_disposed) return;
    html.window.open(_url, '_blank');
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    // เพิกถอน object URL ไม่งั้นไฟล์ (มีข้อมูลบุคคล) ค้างในหน่วยความจำของแท็บ
    html.Url.revokeObjectUrl(_url);
  }
}
