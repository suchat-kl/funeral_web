import 'package:flutter/material.dart';

import 'app_config.dart';

/// ชุดสีของธีมหนึ่งชุด — เฉพาะสีที่เปลี่ยนตามธีม (สีหลักกับพื้นหลัง)
/// สีปุ่มตามหน้าที่ (เพิ่ม/ลบ/ค้นหา/พิมพ์ ฯลฯ) คงเดิมทุกธีม ผู้ใช้จะได้จำสีปุ่มได้เหมือนเดิม
@immutable
class AppPalette {
  const AppPalette({
    required this.id,
    required this.name,
    required this.primary,
    required this.primaryDark,
    required this.primaryLight,
    required this.primaryPale,
    required this.background,
    required this.surfaceAlt,
    required this.fieldFill,
    required this.divider,
  });

  /// รหัสที่จำไว้ในเบราว์เซอร์ (ห้ามเปลี่ยน ไม่งั้นธีมที่ผู้ใช้เลือกไว้จะหาย)
  final String id;

  /// ชื่อที่แสดงในเมนูเลือกธีม
  final String name;
  final Color primary;
  final Color primaryDark;
  final Color primaryLight;
  final Color primaryPale;
  final Color background;
  final Color surfaceAlt;
  final Color fieldFill;
  final Color divider;
}

/// ชุดสีและธีมกลางของทั้งระบบ — เลือกธีมได้จากปุ่มจานสีที่แถบบน (ธีมที่ 1 คือสีเดิม ที่เหลือเป็นโทนอ่อน)
///
/// ทุกหน้าจอต้องอ้างสีจากคลาสนี้เท่านั้น อย่าเขียนค่าสีตรงๆ ลงในหน้าจอ
/// (ยกเว้นสีกลางอย่าง `Colors.white` / `Colors.transparent`)
///
/// สีที่เปลี่ยนตามธีมเป็น getter ไม่ใช่ค่าคงที่ จึงใช้ในนิพจน์ `const` ไม่ได้
/// เช่น `const Icon(x, color: AppTheme.primaryColor)` ต้องเอา `const` ออก
class AppTheme {
  /// ธีมทั้งหมด ตัวแรกคือค่าเริ่มต้น — สีหลักทุกชุดวางตัวอักษรขาวแล้วยังอ่านได้ (contrast ≥ 4:1)
  static const List<AppPalette> palettes = [
    // ธีมที่ 1 = ชุดสีเดิมของระบบก่อนมีตัวเลือกธีม (ค่าเริ่มต้น)
    AppPalette(
      id: 'classic',
      name: 'ธีมที่ 1 น้ำเงิน',
      primary: Color(0xFF1565C0),
      primaryDark: Color(0xFF0D3C6E),
      primaryLight: Color(0xFF42A5F5),
      primaryPale: Color(0xFFE3F0FC),
      background: Color(0xFFF4F8FC),
      surfaceAlt: Color(0xFFFAFCFE),
      fieldFill: Color(0xFFF7FAFD),
      divider: Color(0xFFD9E3EC),
    ),
    // ธีมที่ 2 เป็นต้นไป = โทนอ่อน
    AppPalette(
      id: 'sky',
      name: 'ธีมที่ 2 ฟ้าใส',
      primary: Color(0xFF2B78C8),
      primaryDark: Color(0xFF1B4F86),
      primaryLight: Color(0xFF7DB8F0),
      primaryPale: Color(0xFFE4F1FD),
      background: Color(0xFFF4F9FE),
      surfaceAlt: Color(0xFFFAFCFF),
      fieldFill: Color(0xFFF6FAFE),
      divider: Color(0xFFD6E4F1),
    ),
    AppPalette(
      id: 'mint',
      name: 'ธีมที่ 3 มิ้นต์',
      primary: Color(0xFF138575),
      primaryDark: Color(0xFF0C574D),
      primaryLight: Color(0xFF6CCBBB),
      primaryPale: Color(0xFFDDF5F0),
      background: Color(0xFFF3FBF9),
      surfaceAlt: Color(0xFFFAFEFD),
      fieldFill: Color(0xFFF5FBFA),
      divider: Color(0xFFD2E8E3),
    ),
    AppPalette(
      id: 'lavender',
      name: 'ธีมที่ 4 ลาเวนเดอร์',
      primary: Color(0xFF7663C8),
      primaryDark: Color(0xFF473A85),
      primaryLight: Color(0xFFB3A6EC),
      primaryPale: Color(0xFFECE8FB),
      background: Color(0xFFF8F6FE),
      surfaceAlt: Color(0xFFFCFBFF),
      fieldFill: Color(0xFFF9F8FE),
      divider: Color(0xFFE0DBF1),
    ),
    AppPalette(
      id: 'rose',
      name: 'ธีมที่ 5 กุหลาบ',
      primary: Color(0xFFCC4C80),
      primaryDark: Color(0xFF862B51),
      primaryLight: Color(0xFFF0A3C0),
      primaryPale: Color(0xFFFCE6EE),
      background: Color(0xFFFFF6F9),
      surfaceAlt: Color(0xFFFFFBFC),
      fieldFill: Color(0xFFFEF8FA),
      divider: Color(0xFFF1DCE4),
    ),
    AppPalette(
      id: 'peach',
      name: 'ธีมที่ 6 พีช',
      primary: Color(0xFFC2631A),
      primaryDark: Color(0xFF7C3D0D),
      primaryLight: Color(0xFFF0B07C),
      primaryPale: Color(0xFFFDEBDB),
      background: Color(0xFFFFF8F2),
      surfaceAlt: Color(0xFFFFFCF9),
      fieldFill: Color(0xFFFEF9F5),
      divider: Color(0xFFF0E0D1),
    ),
  ];

  /// จำธีมไว้ในเบราว์เซอร์ (localStorage ไม่หายตอนออกจากระบบ)
  static const String storageKey = AppConfig.themeStorageKey;

  static AppPalette _current = palettes.first;

  /// ธีมที่ใช้อยู่
  static AppPalette get current => _current;

  static AppPalette paletteFor(String? id) =>
      palettes.firstWhere((p) => p.id == id, orElse: () => palettes.first);

  /// แจ้งเมื่อธีมเปลี่ยน — main.dart ฟังอยู่ แล้วจำค่าลงเบราว์เซอร์กับวาดทุกหน้าจอใหม่
  static final ValueNotifier<String> themeId = ValueNotifier(palettes.first.id);

  /// เปลี่ยนธีมที่ใช้อยู่ (รหัสที่ไม่รู้จักกลับไปธีมที่ 1)
  static void select(String? id) {
    _current = paletteFor(id);
    themeId.value = _current.id;
  }

  // ── สีหลัก (เปลี่ยนตามธีม) ────────────────────────────────
  /// สีหลัก ใช้กับแถบบน ปุ่มหลัก และเส้นขอบตอนโฟกัส
  static Color get primaryColor => _current.primary;

  /// สีหลักเข้ม ใช้กับตัวอักษรบนพื้นสีหลักอ่อน
  static Color get primaryDark => _current.primaryDark;

  /// สีหลักอ่อน ใช้กับไอคอน/เส้นคั่นที่ต้องการให้เบาลง
  static Color get primaryLight => _current.primaryLight;

  /// สีหลักจางมาก ใช้เป็นพื้นหัวตารางและแถวที่ถูกเลือก
  static Color get primaryPale => _current.primaryPale;

  /// สีรอง (ทอง) ใช้กับปุ่มรายละเอียดและจุดที่ต้องการเน้น
  static const Color secondaryColor = Color(0xFFFFB300);

  /// สีตัวอักษรบนพื้นสีรอง — ใช้สีเข้มของตระกูลเดียวกัน ไม่ใช้สีดำล้วน
  static const Color onSecondaryColor = Color(0xFF4A3000);

  /// สีเสริม ใช้กับป้ายกำกับหรือกราฟที่ต้องการแยกจากสีหลัก
  static const Color accentColor = Color(0xFF00897B);

  // ── สีตามความหมาย ────────────────────────────────────────
  /// เขียว = สำเร็จ ใช้กับข้อความแจ้งผลและปุ่มเพิ่มรายการ
  static const Color successColor = Color(0xFF43A047);

  // ── สีปุ่มตามประเภทการทำงาน ──────────────────────────────
  // ปุ่มคนละหน้าที่ต้องคนละสี ผู้ใช้จะจำสีได้โดยไม่ต้องอ่านป้าย
  /// บันทึก — สีหลักของธีม เข้าชุดกับแถบบน
  static Color get saveColor => primaryColor;

  /// เพิ่ม / เพิ่มรายการ — เขียว
  static const Color addColor = successColor;

  /// ลบ / ลบที่เลือก — แดง
  static const Color deleteColor = dangerColor;

  /// ค้นหา — เขียวน้ำทะเล
  static const Color searchColor = Color(0xFF00897B);

  /// แก้ไข / รายละเอียด — ทอง (ตัวอักษรใช้ onSecondaryColor)
  static const Color editColor = secondaryColor;

  /// พิมพ์ / ออกรายงาน — ม่วง
  static const Color printColor = Color(0xFF6A4FBF);

  /// ปุ่มกลาง เช่น เลือกทั้งหมด ล้าง ปิด กลับ — เทาน้ำเงิน
  static const Color neutralColor = Color(0xFF546E7A);

  /// ยกเลิก — ส้ม สื่อว่าทิ้งสิ่งที่กรอกไว้ แต่ไม่ใช่การลบข้อมูล
  static const Color cancelColor = Color(0xFFEF6C00);

  /// แดง = อันตราย / ปุ่มลบ
  static const Color dangerColor = Color(0xFFE53935);

  /// ส้ม = คำเตือน เช่น ข้อความ "มีการแก้ไขที่ยังไม่ได้บันทึก"
  static const Color warningColor = Color(0xFFEF6C00);

  /// ฟ้าเขียว = ข้อมูลทั่วไป / ปุ่มกลับ
  static const Color infoColor = Color(0xFF00ACC1);

  // ── พื้นหลังและตัวอักษร ──────────────────────────────────
  /// พื้นหลังของหน้าจอ อมสีของธีมจาง ๆ ให้ดูสว่างแต่ไม่แสบตา
  static Color get backgroundColor => _current.background;

  /// พื้นการ์ด/ตาราง
  static const Color cardColor = Colors.white;

  /// พื้นแถวสลับในตาราง
  static Color get surfaceAlt => _current.surfaceAlt;

  /// พื้นช่องกรอกข้อมูลที่ต้องการให้ดูจมลงเล็กน้อย เช่น ช่องค้นหา
  static Color get fieldFillColor => _current.fieldFill;

  static const Color textPrimary = Color(0xFF1B2430);
  static const Color textSecondary = Color(0xFF5F6B7A);

  /// เส้นคั่นและขอบช่องกรอก
  static Color get dividerColor => _current.divider;

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,

      // IMPORTANT: Set font family and fallbacks
      fontFamily: 'NotoSansThai',
      fontFamilyFallback: const [
        'Sarabun',
        'NotoSansThai',
        'Kanit',
        'Tahoma',
        'sans-serif',
      ],

      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        primary: primaryColor,
        secondary: secondaryColor,
        onSecondary: onSecondaryColor,
        surface: cardColor,
        error: dangerColor,
        brightness: Brightness.light,
      ),

      // Define text theme with Sarabun
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontFamily: 'NotoSansThai',
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: textPrimary,
        ),
        headlineMedium: TextStyle(
          fontFamily: 'NotoSansThai',
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        titleLarge: TextStyle(
          fontFamily: 'NotoSansThai',
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        bodyLarge: TextStyle(
          fontFamily: 'NotoSansThai',
          fontSize: 16,
          color: textPrimary,
        ),
        bodyMedium: TextStyle(
          fontFamily: 'NotoSansThai',
          fontSize: 14,
          color: textSecondary,
        ),
        bodySmall: TextStyle(
          fontFamily: 'NotoSansThai',
          fontSize: 12,
          color: textSecondary,
        ),
        labelLarge: TextStyle(
          fontFamily: 'NotoSansThai',
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
      ),

      // AppBar theme
      appBarTheme: AppBarTheme(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 2,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: 'NotoSansThai',
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),

      // Card theme
      cardTheme: CardThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        color: cardColor,
      ),

      // Elevated button theme
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 1,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(
            fontFamily: 'NotoSansThai',
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // List tile theme
      // Fix ListTile ink splash visibility
      // ListTile theme - CORRECTED
      listTileTheme: ListTileThemeData(
        tileColor: Colors.transparent,
        selectedTileColor: primaryColor.withValues(alpha: 0.1),
        selectedColor: primaryColor,
        iconColor: primaryColor,
        textColor: textPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        enableFeedback: true,
        visualDensity: VisualDensity.standard,
      ),

      // Fix splash factory globally
      splashFactory: InkRipple.splashFactory,
      highlightColor: primaryColor.withValues(alpha: 0.1),
      splashColor: primaryColor.withValues(alpha: 0.15),

      // Input decoration theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        hintStyle: const TextStyle(
          fontFamily: 'NotoSansThai',
          fontSize: 16,
          color: textSecondary,
        ),
        labelStyle: const TextStyle(
          fontFamily: 'NotoSansThai',
          fontSize: 16,
          color: textPrimary,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: dividerColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: dividerColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: primaryColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: dangerColor),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
      ),

      // Bottom navigation bar theme
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: primaryColor,
        unselectedItemColor: textSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
        selectedLabelStyle: TextStyle(fontFamily: 'NotoSansThai', fontSize: 12),
        unselectedLabelStyle: TextStyle(
          fontFamily: 'NotoSansThai',
          fontSize: 12,
        ),
      ),

      // Drawer theme
      drawerTheme: const DrawerThemeData(
        backgroundColor: Colors.white,
        elevation: 16,
      ),

      // Snackbar theme
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        contentTextStyle: const TextStyle(
          fontFamily: 'NotoSansThai',
          fontSize: 14,
        ),
      ),

      scaffoldBackgroundColor: backgroundColor,

      dividerTheme: DividerThemeData(color: dividerColor, thickness: 1),
    );
  }
}
