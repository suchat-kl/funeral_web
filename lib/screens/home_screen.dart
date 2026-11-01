import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../config/theme.dart';
import '../models/home_document.dart';
import '../models/stats.dart';
import '../models/stored_file.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../utils/file_download.dart';
import '../utils/roles.dart';
import '../utils/util.dart';
import '../widgets/account_actions.dart';
import '../widgets/file_table.dart';
import '../widgets/footer.dart';
import '../widgets/screen_parts.dart';

/// หน้าแรก: แถบหัว (ชื่อระบบ + ปุ่มเข้าสู่ระบบ / ThaID / ลงทะเบียน) แถบสถิติ และรายการแบบฟอร์มทั่วไป
/// (ดาวน์โหลดได้โดยไม่ต้องเข้าสู่ระบบ)
///
/// โหลดสถิติและแบบฟอร์มใหม่ทุกครั้งที่สถานะเข้าสู่ระบบเปลี่ยน (เข้าสู่ระบบแล้วเห็นแบบฟอร์มตามประเภทบุคลากร)
class HomeScreen extends StatefulWidget {
  final AuthProvider authProvider;
  final ApiService? apiService;

  const HomeScreen({super.key, required this.authProvider, this.apiService});

  static const String systemName = AppConfig.systemName;

  static const Key statsKey = ValueKey('home-stats');
  static const Key formsKey = ValueKey('home-forms');
  static const Key loginKey = ValueKey('home-login');
  static const Key thaidKey = ValueKey('home-thaid');
  static const Key registerKey = ValueKey('home-register');
  static const Key documentsKey = ValueKey('home-documents');
  static Key documentKey(String slot) => ValueKey('home-document-$slot');

  /// ภาพพื้นหลังแถบหัว (อาคารกรมทางหลวง)
  static const String bannerImage = 'assets/images/doh.jpg';

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final ApiService _api = widget.apiService ?? ApiService();
  PublicStats? _stats;
  List<HomeDocument> _documents = const [];
  List<StoredFile>? _forms;
  String? _formsError;
  String? _downloading;
  String? _downloadError;
  bool _wasLoggedIn = false;

  @override
  void initState() {
    super.initState();
    _wasLoggedIn = widget.authProvider.isLoggedIn;
    widget.authProvider.addListener(_authChanged);
    _load();
  }

  @override
  void dispose() {
    widget.authProvider.removeListener(_authChanged);
    super.dispose();
  }

  void _authChanged() {
    final now = widget.authProvider.isLoggedIn;
    if (now == _wasLoggedIn) return;
    _wasLoggedIn = now;
    _load();
  }

  Future<void> _load() async {
    _loadStats();
    _loadDocuments();
    try {
      final forms = await _api.getGeneralFiles();
      if (!mounted) return;
      setState(() {
        _forms = forms;
        _formsError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _formsError = e.toString());
    }
  }

  /// สถิติโหลดไม่ได้ = ซ่อนแถบ (ไม่แสดงข้อผิดพลาด)
  Future<void> _loadStats() async {
    try {
      final s = await _api.getPublicStats();
      if (mounted) setState(() => _stats = s);
    } catch (_) {
      if (mounted) setState(() => _stats = null);
    }
  }

  /// เอกสารหน้าแรก โหลดไม่ได้ = ซ่อนปุ่ม (ไม่แสดงข้อผิดพลาด)
  Future<void> _loadDocuments() async {
    try {
      final docs = await _api.getHomeDocuments();
      if (mounted) setState(() => _documents = docs);
    } catch (_) {
      if (mounted) setState(() => _documents = const []);
    }
  }

  /// ปุ่ม PDF บนหน้าแรก (เฉพาะช่องที่มีไฟล์) เปิดในแท็บใหม่แบบระบบเดิม
  Widget _documentsBar(bool isDesktop) {
    final docs = [
      for (final d in _documents)
        if (d.available) d,
    ];
    if (docs.isEmpty) return const SizedBox.shrink();
    return Container(
      key: HomeScreen.documentsKey,
      width: double.infinity,
      color: AppTheme.backgroundColor,
      padding: EdgeInsets.fromLTRB(
        isDesktop ? 32 : 12,
        isDesktop ? 24 : 16,
        isDesktop ? 32 : 12,
        0,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: 12,
            runSpacing: 10,
            children: [
              for (final d in docs)
                OutlinedButton.icon(
                  key: HomeScreen.documentKey(d.slot),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppTheme.primaryDark,
                    side: BorderSide(color: AppTheme.primaryColor),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () => LinkOpener.open(d.fileUrl),
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                  label: Text(
                    d.title,
                    textAlign: TextAlign.center,
                    style: screenText(size: 15, weight: FontWeight.w600),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _download(StoredFile f) async {
    if (_downloading != null) return;
    setState(() {
      _downloading = f.id;
      _downloadError = null;
    });
    try {
      final file = await _api.downloadGeneralFile(f);
      if (!mounted) return;
      FileSaver.instance.save(file);
      setState(() => _downloading = null);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _downloading = null;
        _downloadError = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 900;
    return SingleChildScrollView(
      child: Column(
        children: [
          _banner(context, isDesktop),
          if (_stats != null) _statsBar(isDesktop),
          _documentsBar(isDesktop),
          // ── ที่ว่างไว้สำหรับการ์ด "ยอดเงินฝากล่วงหน้า" ของสมาชิก (ส่วนเพิ่มในอนาคต: ฝากเงินฌาปนกิจล่วงหน้า)
          // ยังไม่มีเส้น API — ห้ามใส่ข้อมูลสมมุติ เมื่อ backend มีเส้นแล้วให้แสดงการ์ดตรงนี้เฉพาะ
          // `widget.authProvider.isMember` (ยอดของตัวเองเท่านั้น เลขสมาชิกจากบัญชี)
          const _AdvanceDepositSlot(),
          _formsSection(isDesktop),
          const CustomFooter(),
        ],
      ),
    );
  }

  List<Shadow> get _glow => [
    Shadow(blurRadius: 10, color: AppTheme.primaryDark.withValues(alpha: 0.85)),
    const Shadow(blurRadius: 3, offset: Offset(0, 1), color: Colors.black54),
  ];

  /// ตัวหนังสือบนภาพ: ขอบสีเข้มของธีม + ตัวหนังสือสีขาว (ชั้นขอบซ่อนจากโปรแกรมอ่านหน้าจอ)
  Widget _bannerText(
    String text,
    double size,
    FontWeight weight,
    double stroke,
  ) {
    final base = TextStyle(
      fontFamily: 'NotoSansThai',
      fontSize: size,
      fontWeight: weight,
      height: 1.3,
    );
    return Stack(
      alignment: Alignment.center,
      children: [
        ExcludeSemantics(
          child: RichText(
            textAlign: TextAlign.center,
            textScaler: MediaQuery.textScalerOf(context),
            text: TextSpan(
              text: text,
              style: base.copyWith(
                foreground: Paint()
                  ..style = PaintingStyle.stroke
                  ..strokeWidth = stroke
                  ..strokeJoin = StrokeJoin.round
                  ..color = AppTheme.primaryDark,
                shadows: _glow,
              ),
            ),
          ),
        ),
        Text(
          text,
          textAlign: TextAlign.center,
          style: base.copyWith(color: Colors.white),
        ),
      ],
    );
  }

  Widget _banner(BuildContext context, bool isDesktop) {
    final auth = widget.authProvider;
    final loggedIn = auth.isLoggedIn;
    final busy = auth.thaidBusy || auth.passkeyBusy;
    final buttonStyle = ElevatedButton.styleFrom(
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 22 : 16,
        vertical: 14,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
    const buttonText = TextStyle(
      fontFamily: 'NotoSansThai',
      fontSize: 15,
      fontWeight: FontWeight.w600,
    );
    return Container(
      width: double.infinity,
      constraints: BoxConstraints(minHeight: isDesktop ? 320 : 260),
      decoration: BoxDecoration(
        color: AppTheme.primaryDark,
        image: const DecorationImage(
          image: AssetImage(HomeScreen.bannerImage),
          fit: BoxFit.cover,
        ),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 32 : 16,
        vertical: isDesktop ? 44 : 28,
      ),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            AppConfig.logoIcon,
            size: isDesktop ? 48 : 34,
            color: Colors.white,
            shadows: _glow,
          ),
          SizedBox(height: isDesktop ? 12 : 8),
          _bannerText(
            AppConfig.systemName,
            isDesktop ? 34 : 22,
            FontWeight.bold,
            isDesktop ? 6 : 4.5,
          ),
          const SizedBox(height: 8),
          _bannerText(
            AppConfig.orgName,
            isDesktop ? 19 : 15,
            FontWeight.w600,
            4,
          ),
          const SizedBox(height: 12),
          _bannerText(
            loggedIn
                ? 'ยินดีต้อนรับ ${auth.displayName}'
                : 'ดาวน์โหลดแบบฟอร์มได้ทันที เข้าสู่ระบบเพื่อดาวน์โหลดทะเบียนคุมรายชื่อและใบเสร็จรับเงิน',
            isDesktop ? 16 : 13,
            FontWeight.w600,
            3.5,
          ),
          if (loggedIn) ...[
            const SizedBox(height: 8),
            _bannerText(
              [
                auth.highestRole,
                if (auth.memberNo != null) 'เลขสมาชิก ${auth.memberNo}',
                if (auth.personType != null) PersonType.nameOf(auth.personType),
              ].join(' · '),
              isDesktop ? 14 : 12,
              FontWeight.w600,
              3.5,
            ),
          ],
          if (!loggedIn) ...[
            const SizedBox(height: 20),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 12,
              runSpacing: 10,
              children: [
                ElevatedButton.icon(
                  key: HomeScreen.loginKey,
                  style: buttonStyle.copyWith(
                    backgroundColor: const WidgetStatePropertyAll(
                      AppTheme.secondaryColor,
                    ),
                    foregroundColor: const WidgetStatePropertyAll(
                      AppTheme.onSecondaryColor,
                    ),
                  ),
                  onPressed: busy ? null : () => showLogin(context, auth),
                  icon: const Icon(Icons.login),
                  label: const Text('เข้าสู่ระบบ', style: buttonText),
                ),
                ElevatedButton.icon(
                  key: HomeScreen.thaidKey,
                  style: buttonStyle.copyWith(
                    backgroundColor: const WidgetStatePropertyAll(
                      Color(0xFF06115A),
                    ),
                    foregroundColor: const WidgetStatePropertyAll(Colors.white),
                  ),
                  onPressed: busy ? null : () => _thaid(context),
                  icon: const Icon(Icons.verified_user_outlined),
                  label: const Text('เข้าสู่ระบบด้วย ThaID', style: buttonText),
                ),
                ElevatedButton.icon(
                  key: HomeScreen.registerKey,
                  style: buttonStyle.copyWith(
                    backgroundColor: const WidgetStatePropertyAll(Colors.white),
                    foregroundColor: WidgetStatePropertyAll(
                      AppTheme.primaryColor,
                    ),
                  ),
                  onPressed: busy
                      ? null
                      : () => showRegisterThenLogin(context, auth),
                  icon: const Icon(Icons.how_to_reg),
                  label: const Text('ลงทะเบียน', style: buttonText),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// เข้าสู่ระบบด้วย ThaID จากหน้าแรก (ข้อผิดพลาดแสดงในแถบแจ้ง)
  Future<void> _thaid(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context, rootNavigator: true);
    try {
      await widget.authProvider.loginWithThaid();
    } catch (e) {
      final notRegistered =
          e is ApiException && e.code == ErrorCodes.notRegistered;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.dangerColor,
            duration: Duration(seconds: notRegistered ? 15 : 8),
            content: Text(
              'เข้าสู่ระบบด้วย ThaID ไม่สำเร็จ: $e',
              style: const TextStyle(fontFamily: 'NotoSansThai'),
            ),
            action: notRegistered
                ? SnackBarAction(
                    label: 'ลงทะเบียน',
                    textColor: Colors.white,
                    onPressed: () {
                      if (navigator.mounted) {
                        showRegisterThenLogin(
                          navigator.context,
                          widget.authProvider,
                        );
                      }
                    },
                  )
                : null,
          ),
        );
    }
  }

  Widget _stat(IconData icon, String label, int value) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: AppTheme.primaryColor, size: 26),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              Util.formatCount(value),
              style: screenText(
                size: 20,
                weight: FontWeight.w700,
                color: AppTheme.primaryDark,
              ),
            ),
            Text(
              label,
              style: screenText(size: 12.5, color: AppTheme.textSecondary),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _statsBar(bool isDesktop) {
    final s = _stats!;
    return Container(
      key: HomeScreen.statsKey,
      width: double.infinity,
      color: Colors.white,
      padding: EdgeInsets.symmetric(
        vertical: isDesktop ? 16 : 10,
        horizontal: 8,
      ),
      child: Wrap(
        alignment: WrapAlignment.center,
        runSpacing: 4,
        children: [
          _stat(Icons.how_to_reg, 'ผู้ลงทะเบียน', s.registered),
          _stat(Icons.card_membership, 'สมาชิกฌาปนกิจ', s.members),
          _stat(Icons.person_outline, 'ไม่ใช่สมาชิก', s.nonMembers),
          _stat(Icons.description_outlined, 'แบบฟอร์ม', s.generalFiles),
          _stat(Icons.download_done, 'ดาวน์โหลดแล้ว (ครั้ง)', s.downloads),
        ],
      ),
    );
  }

  Widget _formsSection(bool isDesktop) {
    final forms = _forms;
    return Container(
      key: HomeScreen.formsKey,
      width: double.infinity,
      color: AppTheme.backgroundColor,
      padding: EdgeInsets.fromLTRB(
        isDesktop ? 32 : 12,
        isDesktop ? 32 : 20,
        isDesktop ? 32 : 12,
        isDesktop ? 40 : 24,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: StepCard(
            icon: Icons.description_outlined,
            title: 'แบบฟอร์มทั่วไป',
            subtitle: widget.authProvider.isLoggedIn
                ? 'แบบฟอร์มที่ตรงกับประเภทบุคลากรของท่าน'
                : 'ดาวน์โหลดได้โดยไม่ต้องเข้าสู่ระบบ',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_downloadError != null) ...[
                  NoticeBar(type: NoticeType.error, text: _downloadError!),
                  const SizedBox(height: 10),
                ],
                if (_formsError != null)
                  NoticeBar(
                    type: NoticeType.error,
                    text: _formsError!,
                    action: TextButton.icon(
                      onPressed: _load,
                      icon: const Icon(Icons.refresh, size: 18),
                      label: Text('ลองใหม่', style: screenText(size: 14)),
                    ),
                  )
                else if (forms == null)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else
                  FileTable(
                    files: forms,
                    initialPageSize: 5,
                    showFileFor: widget.authProvider.isLoggedIn,
                    emptyText: 'ยังไม่มีแบบฟอร์ม',
                    actions: (f) => [
                      RowDownloadButton(
                        key: ValueKey('home-download-${f.id}'),
                        busy: _downloading == f.id,
                        enabled: _downloading == null,
                        onPressed: () => _download(f),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// ที่ว่างของการ์ด "ยอดเงินฝากล่วงหน้า" (ส่วนเพิ่มในอนาคต) — ตอนนี้ไม่แสดงอะไร
///
/// เมื่อ backend มีเส้นยอดเงินฝากของสมาชิกแล้ว ให้แสดงการ์ดในนี้เฉพาะสมาชิก (ยอดของตัวเองเท่านั้น)
/// ห้ามใส่ตัวเลขสมมุติ
class _AdvanceDepositSlot extends StatelessWidget {
  const _AdvanceDepositSlot();

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
