/// ผลนำเข้าข้อมูลเดิม (`POST /api/admin/import/{general|monthyear}`)
///
/// `{rows, imported, duplicates, missingFiles[], invalidRows[], filesWithoutRow[]}` — รายการเป็นข้อความตามที่ backend ส่ง
class LegacyImportResult {
  final int rows;
  final int imported;
  final int duplicates;
  final List<String> missingFiles;
  final List<String> invalidRows;
  final List<String> filesWithoutRow;

  const LegacyImportResult({
    this.rows = 0,
    this.imported = 0,
    this.duplicates = 0,
    this.missingFiles = const [],
    this.invalidRows = const [],
    this.filesWithoutRow = const [],
  });

  factory LegacyImportResult.fromJson(Map<String, dynamic> j) {
    int n(Object? v) => v is num ? v.toInt() : int.tryParse('${v ?? ''}') ?? 0;
    List<String> l(Object? v) => [
      for (final e in v is List ? v : const [])
        if (e != null) e is Map ? e.values.join(' · ') : '$e',
    ];
    return LegacyImportResult(
      rows: n(j['rows']),
      imported: n(j['imported']),
      duplicates: n(j['duplicates']),
      missingFiles: l(j['missingFiles']),
      invalidRows: l(j['invalidRows']),
      filesWithoutRow: l(j['filesWithoutRow']),
    );
  }

  /// มีปัญหาที่ผู้ดูแลต้องตรวจ
  bool get hasProblems =>
      missingFiles.isNotEmpty ||
      invalidRows.isNotEmpty ||
      filesWithoutRow.isNotEmpty;
}
