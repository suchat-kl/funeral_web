part of 'api_service.dart';

/// เส้นของเจ้าหน้าที่รับฝากเงินล่วงหน้า `/api/deposit/staff/**` (DEPOSIT_STAFF / ADMIN) และของสมาชิก `/api/deposit/me/**`
///
/// ผลมีชื่อ เลขสมาชิก ยอดเงินรายคน — ห้าม log คำค้นและผลลัพธ์
extension DepositApi on ApiService {
  static const String _base = '/api/deposit/staff';

  Map<String, dynamic> _mapOf(Response<dynamic> r, String fail) {
    if (r.statusCode == 200 && r.data is Map) {
      return Map<String, dynamic>.from(r.data);
    }
    throw ApiService._apiError(r.statusCode, r.data, fail);
  }

  List<Map<String, dynamic>> _listOf(Response<dynamic> r, String fail) {
    if (r.statusCode == 200 && r.data is List) {
      return [
        for (final x in r.data as List)
          if (x is Map) Map<String, dynamic>.from(x),
      ];
    }
    throw ApiService._apiError(r.statusCode, r.data, fail);
  }

  // ---------------- สมาชิก ----------------

  Future<DepositSearchResult> depositSearch({
    String? q,
    DepositTab tab = DepositTab.all,
    DepositState? state,
  }) async {
    final k = (q ?? '').trim();
    final r = await _authedRequest(
      'GET',
      '$_base/members',
      query: {
        if (k.isNotEmpty) 'q': k,
        'tab': tab.name.toUpperCase(),
        if (state != null) 'state': state.code,
      },
    );
    return DepositSearchResult.fromJson(_mapOf(r, 'ค้นหาสมาชิกไม่สำเร็จ'));
  }

  Future<DepositDetail> depositDetail(String memberNo) async {
    final r = await _authedRequest('GET', '$_base/members/$memberNo');
    return DepositDetail.fromJson(_mapOf(r, 'โหลดข้อมูลสมาชิกไม่สำเร็จ'));
  }

  Future<List<DepositMonthItem>> depositPayments(String memberNo) async {
    final r = await _authedRequest('GET', '$_base/members/$memberNo/payments');
    return [
      for (final j in _listOf(r, 'โหลดประวัติชำระไม่สำเร็จ'))
        DepositMonthItem.fromJson(j),
    ];
  }

  Future<List<DepositMonthItem>> depositDebts(String memberNo) async {
    final r = await _authedRequest('GET', '$_base/members/$memberNo/debts');
    return [
      for (final j in _listOf(r, 'โหลดประวัติค้างชำระไม่สำเร็จ'))
        DepositMonthItem.fromJson(j),
    ];
  }

  Future<List<DepositReceiptItem>> depositReceipts(String memberNo) async {
    final r = await _authedRequest('GET', '$_base/members/$memberNo/receipts');
    return [
      for (final j in _listOf(r, 'โหลดประวัติฝากไม่สำเร็จ'))
        DepositReceiptItem.fromJson(j),
    ];
  }

  Future<List<LedgerItem>> depositLedger(String memberNo) async {
    final r = await _authedRequest('GET', '$_base/members/$memberNo/ledger');
    return [
      for (final j in _listOf(r, 'โหลดทะเบียนรายตัวไม่สำเร็จ'))
        LedgerItem.fromJson(j),
    ];
  }

  Future<void> depositUpdateMember(
    String memberNo, {
    String? memo,
    String? divCode,
    int? status,
  }) async {
    final r = await _authedRequest(
      'PUT',
      '$_base/members/$memberNo',
      data: {'memo': memo, 'divCode': divCode, 'status': status},
    );
    _mapOf(r, 'บันทึกข้อมูลสมาชิกไม่สำเร็จ');
  }

  Future<DepositAccountInfo> depositOpenAccount(String memberNo) async {
    final r = await _authedRequest('POST', '$_base/members/$memberNo/account');
    return DepositAccountInfo.fromJson(_mapOf(r, 'เปิดบัญชีไม่สำเร็จ'));
  }

  /// หมายเหตุ/สภาพบัญชี — ส่ง [version] ที่ได้ตอนโหลด (ไม่ตรง = มีคนแก้ก่อน 409 STALE_VERSION)
  Future<DepositAccountInfo> depositUpdateAccount(
    String memberNo, {
    String? remark,
    required int status,
    String? statusText,
    required bool dunning,
    required int? version,
  }) async {
    final r = await _authedRequest(
      'PUT',
      '$_base/members/$memberNo/account',
      data: {
        'remark': remark,
        'status': status,
        'statusText': statusText,
        'dunning': dunning,
        'version': version,
      },
    );
    return DepositAccountInfo.fromJson(_mapOf(r, 'บันทึกบัญชีไม่สำเร็จ'));
  }

  Future<SpecialMemberInfo> depositSaveSpecial(
    String memberNo, {
    required String amount,
    String? approvalRef,
  }) async {
    final r = await _authedRequest(
      'PUT',
      '$_base/members/$memberNo/special',
      data: {'amount': amount, 'approvalRef': approvalRef},
    );
    return SpecialMemberInfo.fromJson(_mapOf(r, 'บันทึกสมาชิกพิเศษไม่สำเร็จ'));
  }

  Future<List<OracleMemberItem>> depositOracleMembers(String q) async {
    final r = await _authedRequest(
      'GET',
      '$_base/oracle-members',
      query: {'q': q.trim()},
    );
    return [
      for (final j in _listOf(r, 'ค้นหาสมาชิกในทะเบียนไม่สำเร็จ'))
        OracleMemberItem.fromJson(j),
    ];
  }

  Future<List<DivisionItem>> depositDivisions() async {
    final r = await _authedRequest('GET', '$_base/divisions');
    return [
      for (final j in _listOf(r, 'โหลดรายการสังกัดไม่สำเร็จ'))
        DivisionItem.fromJson(j),
    ];
  }

  // ---------------- ค่าฌาปนกิจประจำเดือน ----------------

  Future<List<MonthlyCostItem>> depositMonthlyCosts() async {
    final r = await _authedRequest('GET', '$_base/monthly-costs');
    return [
      for (final j in _listOf(r, 'โหลดค่าฌาปนกิจประจำเดือนไม่สำเร็จ'))
        MonthlyCostItem.fromJson(j),
    ];
  }

  /// ค่าตั้งต้นของเดือนถัดไป (period, bodyBegin, perBody, announcementRef)
  Future<Map<String, dynamic>> depositMonthlyCostDraft() async {
    final r = await _authedRequest('GET', '$_base/monthly-costs/draft');
    return _mapOf(r, 'โหลดค่าตั้งต้นไม่สำเร็จ');
  }

  Future<MonthlyCostItem> depositSaveMonthlyCost({
    required int period,
    required int bodyBegin,
    required int bodyEnd,
    required String perBody,
    String? announcementRef,
    bool create = true,
  }) async {
    final body = {
      'period': period,
      'bodyBegin': bodyBegin,
      'bodyEnd': bodyEnd,
      'perBody': perBody,
      'announcementRef': announcementRef,
    };
    final r = create
        ? await _authedRequest('POST', '$_base/monthly-costs', data: body)
        : await _authedRequest(
            'PUT',
            '$_base/monthly-costs/$period',
            data: body,
          );
    return MonthlyCostItem.fromJson(
      _mapOf(r, 'บันทึกค่าฌาปนกิจประจำเดือนไม่สำเร็จ'),
    );
  }

  // ---------------- รายงาน ----------------

  Future<List<int>> depositReportPeriods() async {
    final r = await _authedRequest('GET', '$_base/reports/monthly');
    if (r.statusCode == 200 && r.data is List) {
      return [
        for (final x in r.data as List)
          if ((x is num ? x.toInt() : int.tryParse('$x') ?? 0) > 0)
            x is num ? x.toInt() : int.parse('$x'),
      ];
    }
    throw ApiService._apiError(
      r.statusCode,
      r.data,
      'โหลดรายการเดือนไม่สำเร็จ',
    );
  }

  Future<MonthlyReportData> depositMonthlyReport(int period) async {
    final r = await _authedRequest('GET', '$_base/reports/monthly/$period');
    return MonthlyReportData.fromJson(
      _mapOf(r, 'โหลดรายงานประจำเดือนไม่สำเร็จ'),
    );
  }

  Future<DownloadedFile> depositMonthlyReportExcel(int period) => _download(
    'GET',
    '$_base/reports/monthly/$period/xlsx',
    fallbackName: 'monthly-$period.xlsx',
    failMessage: 'ส่งออก Excel ไม่สำเร็จ',
  );

  Future<NeedDepositData> depositNeedReport({String? threshold}) async {
    final t = (threshold ?? '').trim();
    final r = await _authedRequest(
      'GET',
      '$_base/reports/need-deposit',
      query: {if (t.isNotEmpty) 'threshold': t},
    );
    return NeedDepositData.fromJson(_mapOf(r, 'โหลดรายงานไม่สำเร็จ'));
  }

  Future<DownloadedFile> depositNeedReportExcel({String? threshold}) {
    final t = (threshold ?? '').trim();
    return _download(
      'GET',
      '$_base/reports/need-deposit/xlsx',
      query: {if (t.isNotEmpty) 'threshold': t},
      fallbackName: 'need-deposit.xlsx',
      failMessage: 'ส่งออก Excel ไม่สำเร็จ',
    );
  }

  Future<NeedDepositData> depositDunningReport() async {
    final r = await _authedRequest('GET', '$_base/reports/dunning');
    return NeedDepositData.fromJson(_mapOf(r, 'โหลดรายงานไม่สำเร็จ'));
  }

  Future<DownloadedFile> depositDunningReportExcel() => _download(
    'GET',
    '$_base/reports/dunning/xlsx',
    fallbackName: 'dunning.xlsx',
    failMessage: 'ส่งออก Excel ไม่สำเร็จ',
  );

  Future<DepositTotalsData> depositTotals(int period) async {
    final r = await _authedRequest(
      'GET',
      '$_base/reports/deposit-totals/$period',
    );
    return DepositTotalsData.fromJson(_mapOf(r, 'โหลดยอดเงินฝากไม่สำเร็จ'));
  }

  Future<DownloadedFile> depositTotalsExcel(int period) => _download(
    'GET',
    '$_base/reports/deposit-totals/$period/xlsx',
    fallbackName: 'deposit-$period.xlsx',
    failMessage: 'ส่งออก Excel ไม่สำเร็จ',
  );

  // ---------------- งานเงิน ----------------

  static String _isoDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// บันทึกเงินฝากหลายแถวในครั้งเดียว (ทั้งชุดหรือไม่บันทึกเลย) — แถวผิด backend แจ้ง "แถวที่ n: ..."
  Future<List<DepositSaveResult>> depositSave(
    List<({String memberNo, DateTime date, String amount, String? docNo})> rows,
  ) async {
    final r = await _authedRequest(
      'POST',
      '$_base/deposits',
      data: {
        'rows': [
          for (final x in rows)
            {
              'memberNo': x.memberNo,
              'date': _isoDate(x.date),
              'amount': x.amount,
              'docNo': x.docNo,
            },
        ],
      },
    );
    return [
      for (final j in _listOf(r, 'บันทึกเงินฝากไม่สำเร็จ'))
        DepositSaveResult.fromJson(j),
    ];
  }

  Future<DepositSaveResult> depositClearDebts(
    String memberNo,
    int? version,
  ) async {
    final r = await _authedRequest(
      'POST',
      '$_base/members/$memberNo/clear-debts',
      data: {'version': version},
    );
    return DepositSaveResult.fromJson(_mapOf(r, 'ปลดหนี้ไม่สำเร็จ'));
  }

  /// [type] CLOSE = จ่ายคืนเงินคงเหลือปิดบัญชี / DUPLICATE = คืนกรณีเก็บซ้ำซ้อน ([periods] เดือนที่คืน)
  Future<RefundResultData> depositRefund(
    String memberNo, {
    required String type,
    required int? version,
    String? docNo,
    String? reason,
    DateTime? date,
    int? status,
    String? statusText,
    List<int>? periods,
  }) async {
    final r = await _authedRequest(
      'POST',
      '$_base/members/$memberNo/refund',
      data: {
        'type': type,
        'version': version,
        'docNo': docNo,
        'reason': reason,
        if (date != null) 'date': _isoDate(date),
        'status': status,
        'statusText': statusText,
        'periods': periods,
      },
    );
    return RefundResultData.fromJson(_mapOf(r, 'จ่ายคืนไม่สำเร็จ'));
  }

  Future<ProcessStatusData> depositProcessStatus() async {
    final r = await _authedRequest('GET', '$_base/process');
    return ProcessStatusData.fromJson(
      _mapOf(r, 'โหลดสถานะการประมวลผลไม่สำเร็จ'),
    );
  }

  Future<ProcessPreviewData> depositProcessPreview(int period) async {
    final r = await _authedRequest('GET', '$_base/process/$period/preview');
    return ProcessPreviewData.fromJson(_mapOf(r, 'โหลดตัวอย่างผลไม่สำเร็จ'));
  }

  /// ประมวลผลหักเงิน + สร้างรายงานประจำเดือน (อาจใช้เวลานาน)
  Future<Map<String, dynamic>> depositProcess(int period) async {
    final r = await _authedRequest(
      'POST',
      '$_base/process/$period',
      receiveTimeout: const Duration(minutes: 5),
    );
    return _mapOf(r, 'ประมวลผลไม่สำเร็จ');
  }

  Future<Map<String, dynamic>> depositUndoProcess(int period) async {
    final r = await _authedRequest(
      'POST',
      '$_base/process/$period/undo',
      receiveTimeout: const Duration(minutes: 5),
    );
    return _mapOf(r, 'ยกเลิกการประมวลผลไม่สำเร็จ');
  }

  // ---- บัญชีฝากล่วงหน้าของฉัน /api/deposit/me — backend ใช้เลขสมาชิกของบัญชีที่เข้าสู่ระบบ หน้าเว็บไม่ส่งเลขไป ----

  static const String _me = '/api/deposit/me';

  Future<MyDepositSummary> depositMySummary() async {
    final r = await _authedRequest('GET', _me);
    return MyDepositSummary.fromJson(
      _mapOf(r, 'โหลดบัญชีฝากล่วงหน้าไม่สำเร็จ'),
    );
  }

  Future<List<DepositMonthItem>> depositMyPayments() async {
    final r = await _authedRequest('GET', '$_me/payments');
    return [
      for (final j in _listOf(r, 'โหลดประวัติชำระไม่สำเร็จ'))
        DepositMonthItem.fromJson(j),
    ];
  }

  Future<List<DepositMonthItem>> depositMyDebts() async {
    final r = await _authedRequest('GET', '$_me/debts');
    return [
      for (final j in _listOf(r, 'โหลดประวัติค้างชำระไม่สำเร็จ'))
        DepositMonthItem.fromJson(j),
    ];
  }

  Future<List<DepositReceiptItem>> depositMyReceipts() async {
    final r = await _authedRequest('GET', '$_me/receipts');
    return [
      for (final j in _listOf(r, 'โหลดประวัติฝากไม่สำเร็จ'))
        DepositReceiptItem.fromJson(j),
    ];
  }

  Future<List<LedgerItem>> depositMyLedger() async {
    final r = await _authedRequest('GET', '$_me/ledger');
    return [
      for (final j in _listOf(r, 'โหลดทะเบียนรายตัวไม่สำเร็จ'))
        LedgerItem.fromJson(j),
    ];
  }

  Future<List<MonthlyReportItem>> depositMyMonthly() async {
    final r = await _authedRequest('GET', '$_me/monthly');
    return [
      for (final j in _listOf(r, 'โหลดรายงานประจำเดือนไม่สำเร็จ'))
        MonthlyReportItem.fromJson(j),
    ];
  }
}
