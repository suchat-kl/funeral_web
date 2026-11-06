// ข้อมูลของงานเงินฝากฌาปนกิจล่วงหน้า (เมนูข้อมูลสมาชิก / ฝากเงินชำระล่วงหน้า)
//
// **มีชื่อ เลขสมาชิก และยอดเงินรายคน**: อยู่ในหน่วยความจำของหน้าจอเท่านั้น ห้ามเก็บลง localStorage และห้ามลง log
// จำนวนเงินเก็บเป็นข้อความตามที่ backend ส่ง แสดงด้วย moneyText (ไม่คำนวณเงินที่หน้าเว็บ)

String? _s(Object? v) => v == null ? null : '$v';
String _str(Object? v) => v == null ? '' : '$v';
int? _i(Object? v) => v is num ? v.toInt() : int.tryParse('${v ?? ''}');
bool _b(Object? v) => v == true;
List<Map<String, dynamic>> _list(Object? v) => v is List
    ? [
        for (final x in v)
          if (x is Map) Map<String, dynamic>.from(x),
      ]
    : const [];
Map<String, dynamic>? _map(Object? v) =>
    v is Map ? Map<String, dynamic>.from(v) : null;

/// เดือนของงานเงินฝาก: เลข พ.ศ. ปปปปดด (256905 = พฤษภาคม 2569)
class DepositPeriod {
  DepositPeriod._();

  static const List<String> months = [
    'มกราคม',
    'กุมภาพันธ์',
    'มีนาคม',
    'เมษายน',
    'พฤษภาคม',
    'มิถุนายน',
    'กรกฎาคม',
    'สิงหาคม',
    'กันยายน',
    'ตุลาคม',
    'พฤศจิกายน',
    'ธันวาคม',
  ];

  static int of(int buddhistYear, int month) => buddhistYear * 100 + month;
  static int year(int p) => p ~/ 100;
  static int month(int p) => p % 100;

  /// "พฤษภาคม 2569"
  static String label(int? p) => p == null || month(p) < 1 || month(p) > 12
      ? '-'
      : '${months[month(p) - 1]} ${year(p)}';

  /// "6905" แบบระบบเดิม
  static String legacy(int p) =>
      '${(year(p) % 100).toString().padLeft(2, '0')}${month(p).toString().padLeft(2, '0')}';
}

/// สภาพสมาชิก/บัญชี (รหัสเดียวกับ backend ChapanaMember.STATUS_*)
class DepositStatus {
  DepositStatus._();

  static const int normal = 0;
  static const int removed = 5;

  static const List<String> names = [
    'ปกติ',
    'ลาออก',
    'บำนาญ',
    'ศพ',
    'อื่นๆ',
    'ตัดออกจากสมาชิก',
  ];

  static String nameOf(int? s) =>
      s != null && s >= 0 && s < names.length ? names[s] : '-';
}

/// แท็บของหน้าค้นหา
enum DepositTab { all, deposit, special }

/// ตัวกรองสถานะบัญชีในแท็บฝากล่วงหน้า (null = ทุกสถานะ)
enum DepositState { active, dunning, inactive, closed, removed }

extension DepositStateName on DepositState {
  String get label => switch (this) {
    DepositState.active => 'หักรายเดือนปกติ',
    DepositState.dunning => 'ระหว่างทวงถามหนี้',
    DepositState.inactive => 'พ้นสภาพ/ไม่หักแล้ว',
    DepositState.closed => 'จ่ายคืน ปิดบัญชีแล้ว',
    DepositState.removed => 'นำออกจากสมาชิกแล้ว',
  };

  String get code => name.toUpperCase();
}

/// แถวของหน้าค้นหาสมาชิก
class DepositMemberRow {
  final String memberNo;
  final String title;
  final String firstName;
  final String lastName;
  final String? divCode;
  final String? divName;
  final int? status;
  final bool registered;
  final bool hasAccount;
  final int? accountStatus;
  final String? accountStatusText;
  final String? balance;
  final String? debt;
  final String? remark;
  final bool special;
  final bool dunning;
  final int? closedPeriod;

  const DepositMemberRow({
    required this.memberNo,
    this.title = '',
    this.firstName = '',
    this.lastName = '',
    this.divCode,
    this.divName,
    this.status,
    this.registered = true,
    this.hasAccount = false,
    this.accountStatus,
    this.accountStatusText,
    this.balance,
    this.debt,
    this.remark,
    this.special = false,
    this.dunning = false,
    this.closedPeriod,
  });

  String get fullName =>
      '$title$firstName${lastName.isEmpty ? '' : ' $lastName'}'.trim();

  factory DepositMemberRow.fromJson(Map<String, dynamic> j) => DepositMemberRow(
    memberNo: _str(j['memberNo']),
    title: _str(j['title']),
    firstName: _str(j['firstName']),
    lastName: _str(j['lastName']),
    divCode: _s(j['divCode']),
    divName: _s(j['divName']),
    status: _i(j['status']),
    registered: j['registered'] != false,
    hasAccount: _b(j['hasAccount']),
    accountStatus: _i(j['accountStatus']),
    accountStatusText: _s(j['accountStatusText']),
    balance: _s(j['balance']),
    debt: _s(j['debt']),
    remark: _s(j['remark']),
    special: _b(j['special']),
    dunning: _b(j['dunning']),
    closedPeriod: _i(j['closedPeriod']),
  );
}

class DepositSearchResult {
  final List<DepositMemberRow> rows;
  final bool truncated;

  const DepositSearchResult(this.rows, this.truncated);

  factory DepositSearchResult.fromJson(Map<String, dynamic> j) =>
      DepositSearchResult([
        for (final r in _list(j['rows'])) DepositMemberRow.fromJson(r),
      ], _b(j['truncated']));
}

class DepositAccountInfo {
  final String balance;
  final String debt;
  final String? remark;
  final int status;
  final String? statusText;
  final bool dunning;
  final String? dunningSince;
  final int? closedPeriod;
  final int? version;
  final String? openedAt;

  const DepositAccountInfo({
    this.balance = '0',
    this.debt = '0',
    this.remark,
    this.status = 0,
    this.statusText,
    this.dunning = false,
    this.dunningSince,
    this.closedPeriod,
    this.version,
    this.openedAt,
  });

  factory DepositAccountInfo.fromJson(Map<String, dynamic> j) =>
      DepositAccountInfo(
        balance: _str(j['balance']),
        debt: _str(j['debt']),
        remark: _s(j['remark']),
        status: _i(j['status']) ?? 0,
        statusText: _s(j['statusText']),
        dunning: _b(j['dunning']),
        dunningSince: _s(j['dunningSince']),
        closedPeriod: _i(j['closedPeriod']),
        version: _i(j['version']),
        openedAt: _s(j['openedAt']),
      );
}

class SpecialMemberInfo {
  final String amount;
  final String? approvalRef;

  const SpecialMemberInfo(this.amount, this.approvalRef);

  factory SpecialMemberInfo.fromJson(Map<String, dynamic> j) =>
      SpecialMemberInfo(_str(j['amount']), _s(j['approvalRef']));
}

/// หน้า 2 รายละเอียดสมาชิก
class DepositDetail {
  final DepositMemberRow member;
  final String? memo;
  final DepositAccountInfo? account;
  final SpecialMemberInfo? special;

  /// ชื่อตามทะเบียนของระบบเดิม (ผู้ดูแลระบบแก้ได้) — member แสดงชื่อจาก Oracle ก่อน
  final String? legacyTitle;
  final String? legacyFirstName;
  final String? legacyLastName;

  const DepositDetail(
    this.member,
    this.memo,
    this.account,
    this.special, {
    this.legacyTitle,
    this.legacyFirstName,
    this.legacyLastName,
  });

  factory DepositDetail.fromJson(Map<String, dynamic> j) => DepositDetail(
    DepositMemberRow.fromJson(_map(j['member']) ?? const {}),
    _s(j['memo']),
    _map(j['account']) == null
        ? null
        : DepositAccountInfo.fromJson(_map(j['account'])!),
    _map(j['special']) == null
        ? null
        : SpecialMemberInfo.fromJson(_map(j['special'])!),
    legacyTitle: _s(j['legacyTitle']),
    legacyFirstName: _s(j['legacyFirstName']),
    legacyLastName: _s(j['legacyLastName']),
  );
}

/// ประวัติชำระ / ค้างชำระ (Payment_History / Debt_History)
class DepositMonthItem {
  final String? id;
  final int? period;
  final int? bodyBegin;
  final int? bodyEnd;
  final String amount;
  final String? remark;
  final int? paidPeriod;
  final bool cleared;

  /// คืนกรณีเก็บซ้ำซ้อนแล้ว (เดือนในรายงานที่คืน) null = ยังไม่คืน
  final int? reversedPeriod;

  /// ค้างชำระ: เดือนในรายงานที่ปลดหนี้
  final int? clearedPeriod;

  const DepositMonthItem({
    this.id,
    this.period,
    this.bodyBegin,
    this.bodyEnd,
    this.amount = '0',
    this.remark,
    this.paidPeriod,
    this.cleared = false,
    this.reversedPeriod,
    this.clearedPeriod,
  });

  String get bodies => bodyBegin == null ? '-' : '$bodyBegin-${bodyEnd ?? ''}';

  factory DepositMonthItem.fromJson(Map<String, dynamic> j) => DepositMonthItem(
    id: _s(j['id']),
    period: _i(j['period']),
    bodyBegin: _i(j['bodyBegin']),
    bodyEnd: _i(j['bodyEnd']),
    amount: _str(j['amount']),
    remark: _s(j['remark']),
    paidPeriod: _i(j['paidPeriod']),
    cleared: _b(j['cleared']),
    reversedPeriod: _i(j['reversedPeriod']),
    clearedPeriod: _i(j['clearedPeriod']),
  );
}

/// รับเงินฝากแต่ละครั้ง
class DepositReceiptItem {
  final String? id;
  final String? date;
  final String? legacyDate;
  final String amount;
  final String? docNo;
  final String? memberNo;
  final String? name;

  /// เดือนในรายงานประจำเดือนที่นับรายการนี้
  final int? reportPeriod;

  /// DEPOSIT / REFUND / ADJUST (ปรับยอดโดยผู้ดูแลระบบ)
  final String? kind;
  final String? note;

  const DepositReceiptItem({
    this.id,
    this.reportPeriod,
    this.kind,
    this.note,
    this.date,
    this.legacyDate,
    this.amount = '0',
    this.docNo,
    this.memberNo,
    this.name,
  });

  factory DepositReceiptItem.fromJson(Map<String, dynamic> j) =>
      DepositReceiptItem(
        id: _s(j['id']),
        reportPeriod: _i(j['reportPeriod']),
        kind: _s(j['kind']),
        note: _s(j['note']),
        date: _s(j['date']),
        legacyDate: _s(j['legacyDate']),
        amount: _str(j['amount']),
        docNo: _s(j['docNo']),
        memberNo: _s(j['memberNo']),
        name: _s(j['name']),
      );
}

/// ทะเบียนรายตัว (สมุดบัญชี)
class LedgerItem {
  final String? id;
  final int? seq;
  final String? date;
  final String? legacyDate;
  final String text;
  final String? docNo;
  final String? received;
  final String? bodyPay;
  final String? paid;
  final String? balance;

  const LedgerItem({
    this.id,
    this.seq,
    this.date,
    this.legacyDate,
    this.text = '',
    this.docNo,
    this.received,
    this.bodyPay,
    this.paid,
    this.balance,
  });

  factory LedgerItem.fromJson(Map<String, dynamic> j) => LedgerItem(
    id: _s(j['id']),
    seq: _i(j['seq']),
    date: _s(j['date']),
    legacyDate: _s(j['legacyDate']),
    text: _str(j['text']),
    docNo: _s(j['docNo']),
    received: _s(j['received']),
    bodyPay: _s(j['bodyPay']),
    paid: _s(j['paid']),
    balance: _s(j['balance']),
  );
}

/// ค่าฌาปนกิจประจำเดือน (ffd_monthly_cost ใน DPIS) + สถานะประมวลผลในระบบนี้ — อ่านอย่างเดียว
class MonthlyCostItem {
  final int period;
  final int? bodyBegin;
  final int? bodyEnd;
  final int? bodyCount;
  final String? perBody;
  final String? amount;

  /// วันที่ประกาศค่าฌาปนกิจ (ค.ศ. yyyy-MM-dd)
  final String? costDate;
  final int? totalMembers;
  final int? totalBodies;
  final int? totalResigned;
  final int? totalCut;
  final bool inDpis;
  final bool processed;
  final String? processedAt;
  final String? processedBy;

  /// ข้อมูลไม่สอดคล้อง / DPIS แก้หลังประมวลผล (null = ปกติ)
  final String? warning;

  const MonthlyCostItem({
    required this.period,
    this.bodyBegin,
    this.bodyEnd,
    this.bodyCount,
    this.perBody,
    this.amount,
    this.costDate,
    this.totalMembers,
    this.totalBodies,
    this.totalResigned,
    this.totalCut,
    this.inDpis = true,
    this.processed = false,
    this.processedAt,
    this.processedBy,
    this.warning,
  });

  factory MonthlyCostItem.fromJson(Map<String, dynamic> j) => MonthlyCostItem(
    period: _i(j['period']) ?? 0,
    bodyBegin: _i(j['bodyBegin']),
    bodyEnd: _i(j['bodyEnd']),
    bodyCount: _i(j['bodyCount']),
    perBody: _s(j['perBody']),
    amount: _s(j['amount']),
    costDate: _s(j['costDate']),
    totalMembers: _i(j['totalMembers']),
    totalBodies: _i(j['totalBodies']),
    totalResigned: _i(j['totalResigned']),
    totalCut: _i(j['totalCut']),
    inDpis: _b(j['inDpis']),
    processed: _b(j['processed']),
    processedAt: _s(j['processedAt']),
    processedBy: _s(j['processedBy']),
    warning: _s(j['warning']),
  );
}

/// ค่าฌาปนกิจประจำเดือนของหนึ่งปี พ.ศ.
class MonthlyCostYearData {
  final int year;
  final List<int> years;
  final List<MonthlyCostItem> rows;

  /// ต่อ DPIS ไม่ได้ (แสดงเฉพาะเดือนที่ประมวลผลในระบบนี้แล้ว)
  final String? dpisError;

  const MonthlyCostYearData({
    required this.year,
    this.years = const [],
    this.rows = const [],
    this.dpisError,
  });

  factory MonthlyCostYearData.fromJson(Map<String, dynamic> j) =>
      MonthlyCostYearData(
        year: _i(j['year']) ?? 0,
        years: [
          for (final y in (j['years'] is List ? j['years'] as List : const []))
            if (_i(y) != null) _i(y)!,
        ],
        rows: [for (final r in _list(j['rows'])) MonthlyCostItem.fromJson(r)],
        dpisError: _s(j['dpisError']),
      );
}

/// แถวรายงานประจำเดือน (Monthly_Rep)
class MonthlyReportItem {
  /// เดือนของแถว (มีเฉพาะในหน้าบัญชีของฉัน ที่แสดงหลายเดือน)
  final int? period;
  final String memberNo;
  final String name;
  final String? carried;
  final String? received;
  final String? bodyPay;
  final String? status;
  final String? bodyDebt;
  final String? paid;
  final String? balance;

  const MonthlyReportItem({
    this.period,
    required this.memberNo,
    this.name = '',
    this.carried,
    this.received,
    this.bodyPay,
    this.status,
    this.bodyDebt,
    this.paid,
    this.balance,
  });

  factory MonthlyReportItem.fromJson(Map<String, dynamic> j) =>
      MonthlyReportItem(
        period: _i(j['period']),
        memberNo: _str(j['memberNo']),
        name: _str(j['name']),
        carried: _s(j['carried']),
        received: _s(j['received']),
        bodyPay: _s(j['bodyPay']),
        status: _s(j['status']),
        bodyDebt: _s(j['bodyDebt']),
        paid: _s(j['paid']),
        balance: _s(j['balance']),
      );
}

class MonthlyReportData {
  final int period;
  final List<MonthlyReportItem> rows;
  final int count;
  final String? carried;
  final String? received;
  final String? paid;
  final String? balance;

  const MonthlyReportData({
    required this.period,
    required this.rows,
    this.count = 0,
    this.carried,
    this.received,
    this.paid,
    this.balance,
  });

  factory MonthlyReportData.fromJson(Map<String, dynamic> j) {
    final t = _map(j['totals']) ?? const {};
    return MonthlyReportData(
      period: _i(j['period']) ?? 0,
      rows: [for (final r in _list(j['rows'])) MonthlyReportItem.fromJson(r)],
      count: _i(t['count']) ?? 0,
      carried: _s(t['carried']),
      received: _s(t['received']),
      paid: _s(t['paid']),
      balance: _s(t['balance']),
    );
  }
}

/// รายงานสมาชิกที่ต้องฝากเงินเพิ่ม / ระหว่างทวงถามหนี้
class NeedDepositItem {
  final String? divName;
  final String memberNo;
  final String name;
  final String? balance;
  final String? debt;
  final String? remark;

  const NeedDepositItem({
    this.divName,
    required this.memberNo,
    this.name = '',
    this.balance,
    this.debt,
    this.remark,
  });

  factory NeedDepositItem.fromJson(Map<String, dynamic> j) => NeedDepositItem(
    divName: _s(j['divName']),
    memberNo: _str(j['memberNo']),
    name: _str(j['name']),
    balance: _s(j['balance']),
    debt: _s(j['debt']),
    remark: _s(j['remark']),
  );
}

class NeedDepositData {
  final String? asOf;
  final String? threshold;
  final List<NeedDepositItem> rows;
  final int count;
  final String? totalDebt;

  const NeedDepositData({
    this.asOf,
    this.threshold,
    this.rows = const [],
    this.count = 0,
    this.totalDebt,
  });

  factory NeedDepositData.fromJson(Map<String, dynamic> j) => NeedDepositData(
    asOf: _s(j['asOf']),
    threshold: _s(j['threshold']),
    rows: [for (final r in _list(j['rows'])) NeedDepositItem.fromJson(r)],
    count: _i(j['count']) ?? 0,
    totalDebt: _s(j['totalDebt']),
  );
}

/// ยอดเงินฝากรายเดือน
class DepositTotalsData {
  final int period;
  final List<DepositReceiptItem> rows;
  final int count;
  final String? total;

  const DepositTotalsData({
    required this.period,
    this.rows = const [],
    this.count = 0,
    this.total,
  });

  factory DepositTotalsData.fromJson(Map<String, dynamic> j) =>
      DepositTotalsData(
        period: _i(j['period']) ?? 0,
        rows: [
          for (final r in _list(j['rows'])) DepositReceiptItem.fromJson(r),
        ],
        count: _i(j['count']) ?? 0,
        total: _s(j['total']),
      );
}

/// สมาชิกใน Oracle (เลือกเพื่อเปิดบัญชี)
class OracleMemberItem {
  final String memberNo;
  final String title;
  final String firstName;
  final String lastName;
  final String? orgName;
  final String? membership;
  final bool hasAccount;
  final bool special;

  const OracleMemberItem({
    required this.memberNo,
    this.title = '',
    this.firstName = '',
    this.lastName = '',
    this.orgName,
    this.membership,
    this.hasAccount = false,
    this.special = false,
  });

  String get fullName =>
      '$title$firstName${lastName.isEmpty ? '' : ' $lastName'}'.trim();

  /// ยังเป็นสมาชิกอยู่ (membership = N)
  bool get active => membership == null || membership == 'N';

  factory OracleMemberItem.fromJson(Map<String, dynamic> j) => OracleMemberItem(
    memberNo: _str(j['memberNo']),
    title: _str(j['title']),
    firstName: _str(j['firstName']),
    lastName: _str(j['lastName']),
    orgName: _s(j['orgName']),
    membership: _s(j['membership']),
    hasAccount: _b(j['hasAccount']),
    special: _b(j['special']),
  );
}

class DivisionItem {
  final String code;
  final String name;

  const DivisionItem(this.code, this.name);

  factory DivisionItem.fromJson(Map<String, dynamic> j) =>
      DivisionItem(_str(j['code']), _str(j['name']));
}

/// ผลบันทึกเงินฝากต่อแถว
class DepositSaveResult {
  final String memberNo;
  final String name;
  final String amount;
  final int reportPeriod;
  final List<int> clearedPeriods;
  final String clearedAmount;
  final String balance;
  final String debt;

  const DepositSaveResult({
    required this.memberNo,
    this.name = '',
    this.amount = '0',
    this.reportPeriod = 0,
    this.clearedPeriods = const [],
    this.clearedAmount = '0',
    this.balance = '0',
    this.debt = '0',
  });

  factory DepositSaveResult.fromJson(Map<String, dynamic> j) =>
      DepositSaveResult(
        memberNo: _str(j['memberNo']),
        name: _str(j['name']),
        amount: _str(j['amount']),
        reportPeriod: _i(j['reportPeriod']) ?? 0,
        clearedPeriods: [
          for (final x
              in (j['clearedPeriods'] is List
                  ? j['clearedPeriods'] as List
                  : const []))
            if (_i(x) != null) _i(x)!,
        ],
        clearedAmount: _str(j['clearedAmount']),
        balance: _str(j['balance']),
        debt: _str(j['debt']),
      );
}

/// สถานะการประมวลผล: เดือนที่เปิดอยู่ เดือนที่ยังไม่ประมวลผล และยกเลิกเดือนล่าสุดได้หรือไม่
class ProcessStatusData {
  final int openPeriod;
  final List<int> pending;
  final int? lastProcessed;
  final bool canUndo;
  final String? undoBlockedReason;

  const ProcessStatusData({
    required this.openPeriod,
    this.pending = const [],
    this.lastProcessed,
    this.canUndo = false,
    this.undoBlockedReason,
  });

  factory ProcessStatusData.fromJson(Map<String, dynamic> j) =>
      ProcessStatusData(
        openPeriod: _i(j['openPeriod']) ?? 0,
        pending: [
          for (final x
              in (j['pending'] is List ? j['pending'] as List : const []))
            if (_i(x) != null) _i(x)!,
        ],
        lastProcessed: _i(j['lastProcessed']),
        canUndo: _b(j['canUndo']),
        undoBlockedReason: _s(j['undoBlockedReason']),
      );
}

/// ตัวอย่างผลก่อนประมวลผล
class ProcessPreviewData {
  final int period;
  final bool ready;
  final String? reason;
  final String amount;
  final int? bodyBegin;
  final int? bodyEnd;
  final int accounts;
  final int canPay;
  final String payTotal;
  final int willOwe;
  final String oweTotal;

  const ProcessPreviewData({
    required this.period,
    this.ready = false,
    this.reason,
    this.amount = '0',
    this.bodyBegin,
    this.bodyEnd,
    this.accounts = 0,
    this.canPay = 0,
    this.payTotal = '0',
    this.willOwe = 0,
    this.oweTotal = '0',
  });

  factory ProcessPreviewData.fromJson(Map<String, dynamic> j) =>
      ProcessPreviewData(
        period: _i(j['period']) ?? 0,
        ready: _b(j['ready']),
        reason: _s(j['reason']),
        amount: _str(j['amount']),
        bodyBegin: _i(j['bodyBegin']),
        bodyEnd: _i(j['bodyEnd']),
        accounts: _i(j['accounts']) ?? 0,
        canPay: _i(j['canPay']) ?? 0,
        payTotal: _str(j['payTotal']),
        willOwe: _i(j['willOwe']) ?? 0,
        oweTotal: _str(j['oweTotal']),
      );
}

/// ผลจ่ายคืน
class RefundResultData {
  final String type;
  final String amount;
  final String balanceBefore;
  final String balance;
  final String debt;

  const RefundResultData({
    this.type = '',
    this.amount = '0',
    this.balanceBefore = '0',
    this.balance = '0',
    this.debt = '0',
  });

  factory RefundResultData.fromJson(Map<String, dynamic> j) => RefundResultData(
    type: _str(j['type']),
    amount: _str(j['amount']),
    balanceBefore: _str(j['balanceBefore']),
    balance: _str(j['balance']),
    debt: _str(j['debt']),
  );
}

/// บัญชีฝากล่วงหน้าของฉัน (`GET /api/deposit/me`) — ของบัญชีที่เข้าสู่ระบบเท่านั้น
class MyDepositSummary {
  final bool hasAccount;
  final String? memberNo;
  final String? balance;
  final String? debt;
  final int openDebts;
  final int? status;
  final String? statusName;
  final bool dunning;
  final int? closedPeriod;
  final bool special;
  final String? specialAmount;

  /// เดือนล่าสุดที่ประมวลผลหักเงินแล้ว (ยอดเป็นของ ณ หลังเดือนนี้)
  final int? lastProcessed;

  const MyDepositSummary({
    this.hasAccount = false,
    this.memberNo,
    this.balance,
    this.debt,
    this.openDebts = 0,
    this.status,
    this.statusName,
    this.dunning = false,
    this.closedPeriod,
    this.special = false,
    this.specialAmount,
    this.lastProcessed,
  });

  bool get closed => closedPeriod != null;

  factory MyDepositSummary.fromJson(Map<String, dynamic> j) => MyDepositSummary(
    hasAccount: _b(j['hasAccount']),
    memberNo: _s(j['memberNo']),
    balance: _s(j['balance']),
    debt: _s(j['debt']),
    openDebts: _i(j['openDebts']) ?? 0,
    status: _i(j['status']),
    statusName: _s(j['statusName']),
    dunning: _b(j['dunning']),
    closedPeriod: _i(j['closedPeriod']),
    special: _b(j['special']),
    specialAmount: _s(j['specialAmount']),
    lastProcessed: _i(j['lastProcessed']),
  );
}

/// ผลการแก้ไขโดยผู้ดูแลระบบ: ยอดหลังแก้ และจำนวนแถวรายงานประจำเดือนที่คำนวณใหม่
class AdminEditResult {
  final String? balance;
  final String? debt;
  final int? version;
  final int reportRows;

  const AdminEditResult({
    this.balance,
    this.debt,
    this.version,
    this.reportRows = 0,
  });

  factory AdminEditResult.fromJson(Map<String, dynamic> j) => AdminEditResult(
    balance: _s(j['balance']),
    debt: _s(j['debt']),
    version: _i(j['version']),
    reportRows: _i(j['reportRows']) ?? 0,
  );
}
