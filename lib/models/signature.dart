import '../utils/util.dart';

/// ลายเซ็นบนใบเสร็จหนึ่งรายการ (`GET /api/admin/signatures`)
///
/// ใช้กับใบเสร็จตั้งแต่เดือน [effectiveFrom] (ปี พ.ศ.-เดือน) จนกว่าจะมีรายการใหม่ของชนิดเดียวกัน
class SignatureItem {
  /// ผู้รับเงิน
  static const String kindReceiver = 'RECEIVER';

  /// ผู้อำนวยการกองการเงินฯ / เหรัญญิก
  static const String kindDirector = 'DIRECTOR';

  static const Map<String, String> kindNames = {
    kindReceiver: 'ผู้รับเงิน',
    kindDirector: 'ผอ.กองการเงินฯ / เหรัญญิก',
  };

  final String id;
  final String kind;
  final String name;
  final List<String> positionLines;

  /// "2569-10"
  final String effectiveFrom;
  final bool hasImage;
  final String? uploadedBy;
  final String? uploadedAt;

  const SignatureItem({
    required this.id,
    required this.kind,
    required this.name,
    this.positionLines = const [],
    required this.effectiveFrom,
    this.hasImage = false,
    this.uploadedBy,
    this.uploadedAt,
  });

  factory SignatureItem.fromJson(Map<String, dynamic> j) => SignatureItem(
    id: '${j['id'] ?? ''}',
    kind: '${j['kind'] ?? ''}'.toUpperCase(),
    name: '${j['name'] ?? ''}'.trim(),
    positionLines: [
      for (final l in j['positionLines'] as List? ?? const [])
        if ('${l ?? ''}'.trim().isNotEmpty) '$l'.trim(),
    ],
    effectiveFrom: '${j['effectiveFrom'] ?? ''}',
    hasImage: j['hasImage'] == true,
    uploadedBy: j['uploadedBy'] == null ? null : '${j['uploadedBy']}',
    uploadedAt: j['uploadedAt'] == null ? null : '${j['uploadedAt']}',
  );

  String get kindName => kindNames[kind] ?? kind;

  /// "ตุลาคม 2569"
  String get effectiveText => Util.yearMonthName(effectiveFrom);
}
