/// สถิติหน้าแรก (`GET /api/public/stats`) — จำนวนรวมเท่านั้น ไม่มีข้อมูลรายคน
class PublicStats {
  final int registered;
  final int members;
  final int nonMembers;
  final int downloads;
  final int generalFiles;

  const PublicStats({
    this.registered = 0,
    this.members = 0,
    this.nonMembers = 0,
    this.downloads = 0,
    this.generalFiles = 0,
  });

  factory PublicStats.fromJson(Map<String, dynamic> j) {
    int n(Object? v) => v is num ? v.toInt() : int.tryParse('${v ?? ''}') ?? 0;
    return PublicStats(
      registered: n(j['registered']),
      members: n(j['members']),
      nonMembers: n(j['nonMembers']),
      downloads: n(j['downloads']),
      generalFiles: n(j['generalFiles']),
    );
  }
}
