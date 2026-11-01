import '../services/api_service.dart';

/// เอกสาร PDF หนึ่งช่องบนหน้าแรก (`GET /api/public/home-documents`) มีสองช่องตายตัว
/// [slotInvite] ประชาสัมพันธ์และเชิญชวนสมัครสมาชิก, [slotRegulation] ข้อบังคับ ฌ.ส.ทล
class HomeDocument {
  static const String slotInvite = 'INVITE';
  static const String slotRegulation = 'REGULATION';

  /// ชื่อช่องในหน้านำไฟล์เข้า
  static const Map<String, String> slotNames = {
    slotInvite: 'ประชาสัมพันธ์และเชิญชวนสมัครสมาชิก',
    slotRegulation: 'ข้อบังคับ ฌ.ส.ทล',
  };

  final String slot;

  /// ข้อความบนปุ่มหน้าแรก
  final String title;

  /// มีไฟล์ให้เปิด (ไม่มี = ซ่อนปุ่มบนหน้าแรก)
  final bool available;
  final String? fileName;
  final int? size;
  final String? uploadedBy;
  final String? uploadedAt;

  const HomeDocument({
    required this.slot,
    required this.title,
    this.available = false,
    this.fileName,
    this.size,
    this.uploadedBy,
    this.uploadedAt,
  });

  factory HomeDocument.fromJson(Map<String, dynamic> j) => HomeDocument(
    slot: '${j['slot'] ?? ''}',
    title: '${j['title'] ?? ''}'.trim(),
    available: j['available'] == true,
    fileName: j['fileName'] == null ? null : '${j['fileName']}',
    size: j['size'] is num ? (j['size'] as num).toInt() : null,
    uploadedBy: j['uploadedBy'] == null ? null : '${j['uploadedBy']}',
    uploadedAt: j['uploadedAt'] == null ? null : '${j['uploadedAt']}',
  );

  String get slotName => slotNames[slot] ?? slot;

  /// URL เปิด PDF ในแท็บใหม่ (เส้นสาธารณะ ไม่ต้องใช้ token)
  String get fileUrl =>
      '${ApiService.baseUrl}/api/public/home-documents/$slot/file';
}
