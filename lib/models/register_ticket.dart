/// ใบผ่านลงทะเบียน: ผลของขั้นที่ 2 (ตรวจแบบเดิม หรือยืนยัน ThaID) ใช้ตั้งชื่อผู้ใช้/รหัสผ่านในขั้นที่ 3
///
/// `{ticket, full_name, member, member_no, expires_in}` จาก
/// `POST /api/public/register/legacy-verify` และ `POST /api/auth/public-thaid/register`
///
/// มีชื่อและเลขสมาชิก: อยู่ในหน่วยความจำของหน้าต่างลงทะเบียนเท่านั้น ห้าม log ห้ามเก็บลงที่เก็บของเบราว์เซอร์
class RegisterTicket {
  final String ticket;
  final String fullName;

  /// พบในทะเบียนสมาชิกฌาปนกิจ (บัญชีจะได้บทบาทสมาชิก)
  final bool member;
  final String? memberNo;

  /// อายุของใบผ่าน (วินาที)
  final int expiresIn;

  const RegisterTicket({
    required this.ticket,
    required this.fullName,
    required this.member,
    this.memberNo,
    this.expiresIn = 0,
  });

  factory RegisterTicket.fromJson(Map<String, dynamic> j) {
    final no = '${j['member_no'] ?? ''}'.trim();
    final exp = j['expires_in'];
    return RegisterTicket(
      ticket: '${j['ticket'] ?? ''}',
      fullName: '${j['full_name'] ?? ''}'.trim(),
      member: j['member'] == true,
      memberNo: no.isEmpty ? null : no,
      expiresIn: exp is num ? exp.toInt() : int.tryParse('${exp ?? ''}') ?? 0,
    );
  }

  /// อายุปัดขึ้นเป็นนาที (ไม่ทราบ = null)
  int? get expiresInMinutes => expiresIn <= 0 ? null : (expiresIn / 60).ceil();
}
